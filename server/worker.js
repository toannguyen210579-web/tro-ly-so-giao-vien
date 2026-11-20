import { KIEN_THUC } from "./kien_thuc.js";
import { TIN } from "./tin.js";
import { khoaDung, napVanBan, timKienThuc, dsVanBan, xuatVanBan } from "./kien_thuc_db.js";
// Máy chủ trung gian cho app "Trợ lý số Giáo viên".
// App gọi POST /v1/ai, Worker gọi Claude (Haiku), đếm lượt theo từng máy mỗi ngày.
//
// Gắn trên Cloudflare:
//   - D1 database, tên biến DB (bảng tạo bằng schema.sql)
//   - Secret ANTHROPIC_API_KEY  (người dùng tự dán, không để trong mã)
//   - Biến AI_ENABLED = "1"     (đặt "0" để tạm khóa mọi nút AI)
//   - Secret APP_KEY            (tùy chọn, chuỗi dùng chung với app)
//
// Đường dẫn:
//   GET  /health                      kiểm tra máy chủ
//   GET  /v1/quota?device_id=...      số lượt còn lại hôm nay
//   POST /v1/ai                       { device_id, mode: "hoi"|"nhanxet"|"tinnhan", input }
//   GET  /v1/admob-ssv?...            AdMob gọi về sau khi xem hết quảng cáo nhận thưởng
//
// Chặn một máy lạm dụng: INSERT INTO flags(k, v) VALUES ('block:<mã máy>', 'ly do');
// Gói Pro: flags 'pro:<mã máy>' với v = thời điểm hết hạn (mili giây), do phần kiểm tra
// giao dịch mua tạo ra (chưa làm ở bản đầu).

const MODEL = "claude-haiku-5-5";
const MAX_INPUT = 2000;      // ký tự tối đa mỗi lần gửi
const MAX_TOKENS = 800;      // độ dài câu trả lời tối đa
// Riêng từng chế độ (chế độ không có ở đây dùng mức chung ở trên)
const MAX_IN = { bienban: 12000, detuongtu: 4000 };
const MAX_OUT = { hoi: 2000, nhanxet: 2000, tinnhan: 1200, giaide: 4000, detuongtu: 3000, bienban: 3000 };
const IMG_MODES = ["giaide", "detuongtu", "hoi"]; // chế độ được gửi ảnh, tối đa 4 ảnh
// Chế độ chạy bằng Gemini (gói miễn phí) khi câu hỏi không có thông tin cá nhân; lỗi hoặc hết hạn mức thì dùng Claude.
// Nhận xét học sinh, tin nhắn phụ huynh, biên bản họp luôn dùng Claude.
const GEMINI_MODES = ["hoi", "giaide", "detuongtu"];
// Thử lần lượt; gói miễn phí đôi lúc báo quá tải (503/429). "gemini-flash-latest" quá tải thường xuyên nên không dùng.
const GEMINI_MODELS = ["gemini-flash-lite-latest", "gemini-3.1-flash-lite"];

// Lượt mỗi máy mỗi ngày. Bản thử nghiệm để nhiều lượt.
// Dự kiến khi phát hành: miễn phí hoi 10, nhanxet 20, tinnhan 10; Pro có trần 100 mỗi loại.
const LIMITS = {
  free: { hoi: 100, nhanxet: 100, tinnhan: 100, giaide: 10, detuongtu: 10, bienban: 20 },
  pro: { hoi: 100, nhanxet: 100, tinnhan: 100, giaide: 50, detuongtu: 50, bienban: 100 },
};
const IP_LIMIT = 1000;       // trần mỗi địa chỉ mạng mỗi ngày (cả trường dùng chung wifi)
const BONUS_PER_AD = 5;      // xem một quảng cáo nhận thưởng được thêm 5 lượt
const MAX_ADS_PER_DAY = 10;  // tối đa 10 quảng cáo nhận thưởng mỗi ngày
const ADMOB_KEYS_URL = "https://www.gstatic.com/admob/reward/verifier-keys.json";
const TTS_MAX_CHARS = 1000;    // ký tự mỗi lần đọc (app chia nhỏ, đoạn đầu ngắn để đọc sớm)
const TTS_DAY_CHARS = 30000;   // ký tự mỗi máy mỗi ngày (khoảng 15 trang), Google miễn phí 4 triệu ký tự/tháng
const TTS_VOICE = "vi-VN-Wavenet-A";
// Gemini đọc thành tiếng: giọng người dùng chọn 19/11 là gemini-3.1-flash-tts-preview, giọng Kore;
// hết lượt thì chuyển sang mô hình khác (mỗi mô hình có hạn mức miễn phí riêng)
const TTS_GEMINI_MODELS = ["gemini-3.1-flash-tts-preview", "gemini-3.8-flash-tts", "gemini-2.5-flash-preview-tts", "gemini-3.8-flash-lite-tts"];
const TTS_GEMINI_VOICE = "Kore";
const KEEP_MS = 3 * 86400 * 1000; // bộ đếm giữ 3 ngày rồi xóa

const CHUNG =
  "Bạn là Trợ lý số Giáo viên, trả lời bằng tiếng Việt, ngắn gọn, đúng mực, dễ hiểu. Gọi người dùng là thầy cô, xưng tôi. " +
  "Không bịa số liệu, số hiệu văn bản; không chắc thì nói rõ là cần kiểm tra văn bản gốc. " +
  "Nếu câu hỏi có mã học sinh (HS01, HS02...) thì gọi học sinh bằng đúng mã đó. " +
  "Không nhắc người dùng về việc dùng mã, giữ bí mật hay quyền riêng tư; không hỏi tên thật của học sinh. " +
  "Câu hỏi ngắn hoặc chưa rõ ý thì đoán ý gần nhất và trả lời luôn, kèm một câu hỏi lại ngắn nếu cần. " +
  "Người dùng hay gõ vội trên điện thoại: sai chính tả, thiếu dấu, viết tắt (cip, clíp = clip; ko = không; gv = giáo viên; " +
  "hs = học sinh; vntđ = Việt Nam Tiêu Điểm); hiểu theo nghĩa hợp ngữ cảnh nhất, không giảng giải về chữ gõ sai. " +
  "\"Việt Nam Tiêu Điểm\" là kênh clip tin giáo dục ngắn trên Facebook đi cùng app này; các clip xem ở mục Tin của app. " +
  "Khi có danh sách clip gửi kèm thì trả lời dựa vào danh sách đó.";

const SYSTEM = {
  hoi:
    CHUNG +
    " Trả lời mọi câu hỏi của người dùng một cách hữu ích. " +
    "Không dùng LaTeX, không dùng ký hiệu $ bao công thức; viết phép tính bằng ký hiệu thường (5% + 2% = 7%, x², √). " +
    "Ngày giờ hiện tại đã cho ở cuối hướng dẫn này, dùng nó khi được hỏi ngày, giờ, thứ, đếm ngày. " +
    "Bạn không có dữ liệu thời gian thực khác: hỏi giá cả, tỷ giá, thời tiết, tin tức hôm nay " +
    "thì nói rõ là không có số liệu mới và gợi ý nơi tra cứu, không đoán số.",
  nhanxet:
    CHUNG +
    " Nhiệm vụ: viết nhận xét học sinh cho giáo viên từ các ý giáo viên đưa vào. " +
    "Lời văn tích cực, cụ thể, có điểm mạnh và điều cần cố gắng, phù hợp quy định đánh giá học sinh hiện hành. " +
    "Chỉ trả về đoạn nhận xét, không thêm lời giải thích.",
  tinnhan:
    CHUNG +
    " Nhiệm vụ: soạn tin nhắn giáo viên gửi phụ huynh từ các ý giáo viên đưa vào. " +
    "Lời lẽ lịch sự, tôn trọng, rõ việc, ngắn (dưới 120 chữ). Chỉ trả về nội dung tin nhắn, không dùng markdown. " +
    "Giữ nguyên từng chữ các chỗ trống trong ngoặc vuông giáo viên đưa ra, như [tên học sinh], [họ tên], [lớp]; " +
    "không đổi thành [mã học sinh] hay chữ khác.",
  giaide:
    CHUNG +
    " Nhiệm vụ: làm đáp án và hướng dẫn chấm từ đề bài (ảnh hoặc chữ), theo chương trình GDPT 2018. " +
    "Chỗ ảnh mờ, không đọc chắc thì ghi '(không đọc rõ)', không đoán. Với từng câu: chép lại đề ngắn gọn, " +
    "lời giải từng bước theo cách học sinh lớp đó được học, đáp số; bài tự luận thêm gợi ý thang điểm. " +
    "Kiểm tra lại phép tính. Viết công thức bằng ký hiệu thường (x², √, ≤, π), không dùng LaTeX, không dùng markdown. " +
    "Nếu đề có câu trắc nghiệm, cuối bài thêm đúng một dòng: 'ĐÁP ÁN TRẮC NGHIỆM: 1A 2C 3B …'.",
  detuongtu:
    CHUNG +
    " Nhiệm vụ: ra đề tương tự từ đề mẫu (ảnh hoặc chữ). Giữ dạng bài, mức độ, kiến thức từng câu; " +
    "đổi số liệu, ngữ cảnh, bảo đảm có đáp án đúng. Trả về đề mới đánh số như đề mẫu, sau đó phần 'ĐÁP ÁN' ngắn gọn. " +
    "Không dùng LaTeX, không dùng markdown. Có câu trắc nghiệm thì cuối bài thêm đúng một dòng: 'ĐÁP ÁN TRẮC NGHIỆM: 1A 2C 3B …'.",
  bienban:
    CHUNG +
    " Nhiệm vụ: viết lại ghi chép cuộc họp trong nhà trường thành nội dung biên bản. Văn phong hành chính, khách quan, " +
    "ngôi thứ ba, đúng ý từng người phát biểu, không thêm ý, số liệu, tên người không có trong ghi chép. " +
    "Trả về đúng hai phần: dòng 'NỘI DUNG:' rồi các đoạn diễn biến; dòng 'KẾT LUẬN:' rồi kết luận, phân công, thời hạn " +
    "(không có kết luận thì tóm tắt việc đã thống nhất). Không dùng markdown.",
};

// Hướng dẫn hệ thống kèm ngày giờ Việt Nam để AI trả lời đúng câu hỏi về ngày tháng
function sysOf(mode, now = new Date()) {
  const vn = new Date(now.getTime() + 7 * 3600 * 1000);
  const thu = ["Chủ nhật", "Thứ hai", "Thứ ba", "Thứ tư", "Thứ năm", "Thứ sáu", "Thứ bảy"][vn.getUTCDay()];
  const h = (n) => String(n).padStart(2, "0");
  return SYSTEM[mode] + " Hiện tại ở Việt Nam là " + thu + ", ngày " + h(vn.getUTCDate()) + "/" + h(vn.getUTCMonth() + 1) +
    "/" + vn.getUTCFullYear() + ", " + h(vn.getUTCHours()) + " giờ " + h(vn.getUTCMinutes()) + ".";
}

// Các lượt hỏi đáp trước trong cùng cuộc trò chuyện (chỉ Hỏi Trợ lý), tối đa 4 lượt, mỗi phần tối đa 2.000 ký tự
// Câu hỏi về lương, phụ cấp, chế độ, chính sách của thầy cô đi thẳng Claude (người dùng chốt 20/11/2026):
// Gemini bản nhẹ trả lời "không có dữ liệu" về Nghị định 182/2026 khi thử 20/11.
const CHE_DO_RE = new RegExp(
  [
    "lương", "luong", "phụ cấp", "phu cap", "chế độ", "che do", "chính sách", "chinh sach",
    "thâm niên", "tham nien", "ưu đãi", "uu dai", "truy lĩnh", "truy linh", "hệ số", "he so",
    "bậc", "nâng bậc", "nang bac", "hạng", "thăng hạng", "thang hang", "xếp lương", "xep luong",
    "bổ nhiệm", "bo nhiem", "chức danh", "chuc danh", "thưởng", "thuong tet", "nghỉ hưu", "nghi huu",
    "hưu trí", "huu tri", "bảo hiểm", "bao hiem", "bhxh", "bhyt", "thai sản", "thai san",
    "nghị định", "nghi dinh", "thông tư", "thong tu", "luật nhà giáo", "luat nha giao", "nghị quyết", "nghi quyet",
    "định mức", "dinh muc", "tiết dạy", "tiet day", "dạy thêm giờ", "vượt giờ", "vuot gio", "kiêm nhiệm", "kiem nhiem",
    "tuyển dụng", "tuyen dung", "biên chế", "bien che", "hợp đồng", "hop dong", "thôi việc", "thoi viec",
    "kỷ luật", "ky luat", "học phí", "hoc phi", "trợ cấp", "tro cap", "hỗ trợ", "ho tro",
    "dạy thêm", "day them", "học thêm", "hoc them", "nghỉ hè", "nghi he", "nghỉ phép", "nghi phep",
    "chủ nhiệm", "chu nhiem", "giảm tiết", "giam tiet", "điều lệ", "dieu le", "chuẩn nghề nghiệp", "chuan nghe nghiep",
    "thuyên chuyển", "thuyen chuyen", "điều động", "dieu dong", "thi đua", "thi dua", "khen thưởng", "khen thuong",
    "giờ dạy", "gio day", "tập sự", "tap su", "nghỉ ốm", "nghi om",
    "tuyển sinh", "tuyen sinh", "vào lớp 10", "vao lop 10", "vào lớp 6", "vao lop 6", "thi tốt nghiệp", "thi tot nghiep",
    "tốt nghiệp thpt", "tot nghiep thpt", "xét tốt nghiệp", "xet tot nghiep", "quy chế thi", "quy che thi", "quy chế tuyển", "quy che tuyen",
    "miễn thi", "mien thi", "đặc cách", "dac cach", "điểm ưu tiên", "diem uu tien", "cộng điểm", "cong diem",
    "điểm khuyến khích", "diem khuyen khich", "phúc khảo", "phuc khao", "bảo lưu điểm", "bao luu diem",
    "bao nhiêu tiết", "bao nhieu tiet", "số tiết", "so tiet", "tiết một tuần", "tiết mỗi tuần", "tiết/tuần", "tiet/tuan",
    "tổng phụ trách", "tong phu trach", "tổ trưởng", "to truong", "nhiệm vụ của giáo viên", "quyền của giáo viên",
    "thỉnh giảng", "thinh giang", "mã số chức danh", "ma so chuc danh", "bằng tốt nghiệp", "bang tot nghiep",
  ].map((w) => w.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")).join("|"),
  "i",
);
// Các loại câu khác cũng đi Claude (người dùng chốt 20/11/2026): thủ tục, hồ sơ, văn bản hành chính;
// tình huống nhạy cảm với học sinh; đánh giá, xếp loại theo Thông tư 22, 27; pháp luật nói chung.
const KHAC_RE = new RegExp(
  [
    "thủ tục", "thu tuc", "hồ sơ", "ho so", "tờ trình", "to trinh", "công văn", "cong van", "đơn xin", "don xin",
    "đơn đề nghị", "don de nghi", "đơn kiến nghị", "khiếu nại", "khieu nai", "biên bản", "quyết định", "quyet dinh",
    "bạo lực", "bao luc", "đánh nhau", "danh nhau", "bắt nạt", "bat nat", "xâm hại", "xam hai", "quấy rối", "quay roi",
    "tự tử", "tu tu", "tự sát", "tự hại", "tu hai", "tự làm đau", "trầm cảm", "tram cam", "rạch tay", "bỏ nhà", "bo nha",
    "ma túy", "ma tuy", "mang thai", "có thai", "phụ huynh dọa", "phụ huynh đánh", "phụ huynh chửi",
    "thông tư 22", "thong tu 22", "thông tư 27", "thong tu 27", "xếp loại", "xep loai", "học bạ", "hoc ba",
    "đánh giá học sinh", "danh gia hoc sinh", "khen thưởng học sinh", "lên lớp", "len lop", "ở lại lớp", "o lai lop", "rèn luyện hè",
    "pháp luật", "phap luat", "luật ", "luat ", "đất đai", "dat dai", "sổ đỏ", "so do", "thừa kế", "thua ke", "ly hôn", "ly hon",
    "vi phạm giao thông", "phạt nguội", "phat nguoi", "xử phạt", "xu phat", "tòa án", "toa an", "công an", "cong an", "lừa đảo", "lua dao",
  ].map((w) => w.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")).join("|"),
  "i",
);

function laCauCheDo(input, hist) {
  const t = [input, ...hist.slice(-2).map((h) => h.q)].join("\n").toLowerCase();
  return CHE_DO_RE.test(t) || KHAC_RE.test(t);
}

function historyOf(body, mode) {
  if (mode !== "hoi" || !Array.isArray(body.history)) return [];
  return body.history
    .filter((t) => t && typeof t.q === "string" && typeof t.a === "string" && t.q.trim() && t.a.trim())
    .slice(-4)
    .map((t) => ({ q: t.q.trim().slice(0, 2000), a: t.a.trim().slice(0, 2000) }));
}

// Đóng gói âm thanh PCM 16 bit (Gemini trả về dạng thô) thành tệp WAV để điện thoại phát được
function pcmToWavB64(b64, rate = 24000) {
  const pcm = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
  const h = new DataView(new ArrayBuffer(44));
  const s = (o, t) => [...t].forEach((c, i) => h.setUint8(o + i, c.charCodeAt(0)));
  s(0, "RIFF"); h.setUint32(4, 36 + pcm.length, true); s(8, "WAVE"); s(12, "fmt ");
  h.setUint32(16, 16, true); h.setUint16(20, 1, true); h.setUint16(22, 1, true);
  h.setUint32(24, rate, true); h.setUint32(28, rate * 2, true); h.setUint16(32, 2, true); h.setUint16(34, 16, true);
  s(36, "data"); h.setUint32(40, pcm.length, true);
  const all = new Uint8Array(44 + pcm.length);
  all.set(new Uint8Array(h.buffer), 0); all.set(pcm, 44);
  let bin = "";
  for (let i = 0; i < all.length; i += 0x8000) bin += String.fromCharCode(...all.subarray(i, i + 0x8000));
  return btoa(bin);
}

async function ttsGemini(env, text) {
  let last = { err: "loi_tts", msg: "Chưa đọc được, thầy cô thử lại.", status: "" };
  for (const model of TTS_GEMINI_MODELS) {
    let r;
    try {
      r = await env.GEMINI.fetch("https://gemini/", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          model,
          timeout: 40000,
          body: {
            contents: [{ parts: [{ text }] }],
            generationConfig: {
              responseModalities: ["AUDIO"],
              speechConfig: { voiceConfig: { prebuiltVoiceConfig: { voiceName: TTS_GEMINI_VOICE } } },
            },
          },
        }),
      });
    } catch {
      last = { err: "loi_mang", msg: "Chưa đọc được, thầy cô thử lại.", status: "mang" };
      continue;
    }
    if (!r.ok) {
      last = r.status === 429
        ? { err: "het_luot_chung", msg: "Giọng đọc qua mạng tạm hết lượt miễn phí trong ngày, sau 15 giờ thầy cô dùng lại được.", status: model + ":429" }
        : { err: "loi_tts", msg: "Chưa đọc được, thầy cô thử lại.", status: model + ":" + r.status };
      continue; // mỗi mô hình có hạn mức riêng, thử mô hình kế tiếp
    }
    const j = await r.json();
    const p = ((((j.candidates || [])[0] || {}).content || {}).parts || []).find((x) => x.inlineData);
    if (!p) { last = { err: "loi_tts", msg: "Chưa đọc được, thầy cô thử lại.", status: model + ":rong" }; continue; }
    const mime = String(p.inlineData.mimeType || "").toLowerCase();
    if (mime.includes("wav")) return { audio: p.inlineData.data, mime: "audio/wav", by: "gemini" };
    const rate = parseInt((mime.match(/rate=(\d+)/) || [])[1] || "24000", 10);
    return { audio: pcmToWavB64(p.inlineData.data, rate), mime: "audio/wav", by: "gemini" };
  }
  return last;
}

async function ttsGoogle(env, text, rateIn) {
  const rate = Math.min(2, Math.max(0.5, Number(rateIn) || 1));
  let r;
  try {
    r = await fetch("https://texttospeech.googleapis.com/v1/text:synthesize?key=" + encodeURIComponent(env.GOOGLE_TTS_KEY), {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        input: { text },
        voice: { languageCode: "vi-VN", name: TTS_VOICE },
        audioConfig: { audioEncoding: "MP3", speakingRate: rate },
      }),
    });
  } catch {
    return { err: "loi_mang", msg: "Chưa đọc được, thầy cô thử lại.", status: "mang" };
  }
  if (!r.ok) return { err: "loi_tts", msg: "Chưa đọc được, thầy cô thử lại.", status: "google:" + r.status };
  const audio = (await r.json()).audioContent;
  if (!audio) return { err: "loi_tts", msg: "Chưa đọc được, thầy cô thử lại.", status: "google:rong" };
  return { audio, mime: "audio/mpeg", by: "google" };
}

function json(obj, status = 200) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Headers": "Content-Type, X-App-Key, X-Kt-Key",
      "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
    },
  });
}

function err(code, message, status) {
  return json({ ok: false, error: code, message }, status);
}

// Ngày theo giờ Việt Nam (UTC+7), dạng 2026-11-18
function vnDate() {
  return new Date(Date.now() + 7 * 3600 * 1000).toISOString().slice(0, 10);
}

function okDevice(d) {
  return /^[A-Za-z0-9_-]{8,64}$/.test(d);
}

// ---- Bộ đếm trong D1 ----
async function getN(db, k) {
  const row = await db.prepare("SELECT n FROM counters WHERE k = ?").bind(k).first();
  return row ? row.n : 0;
}

// Cộng d vào bộ đếm, trả về giá trị mới (một câu lệnh, không bị đếm sai khi bấm dồn dập)
async function addN(db, k, d) {
  const row = await db
    .prepare(
      "INSERT INTO counters (k, n, exp) VALUES (?1, ?2, ?3) " +
        "ON CONFLICT(k) DO UPDATE SET n = n + ?2 RETURNING n"
    )
    .bind(k, d, Date.now() + KEEP_MS)
    .first();
  return row.n;
}

async function getFlag(db, k) {
  const row = await db.prepare("SELECT v FROM flags WHERE k = ?").bind(k).first();
  return row ? row.v : null;
}

async function tierOf(db, device) {
  const until = parseInt((await getFlag(db, "pro:" + device)) || "0", 10);
  return until > Date.now() ? "pro" : "free";
}

async function cleanup(db) {
  await db.prepare("DELETE FROM counters WHERE exp < ?").bind(Date.now()).run();
  await db.prepare("DELETE FROM reports WHERE exp < ?").bind(Date.now()).run();
}

// ---- Kiểm tra chữ ký AdMob (server-side verification) ----
function b64ToBytes(s) {
  s = s.replace(/-/g, "+").replace(/_/g, "/");
  while (s.length % 4) s += "=";
  const bin = atob(s);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

// Chữ ký AdMob dạng DER, WebCrypto cần dạng r||s 64 byte
function derToRaw(der) {
  let i = 2;
  if (der[1] & 0x80) i = 2 + (der[1] & 0x7f);
  const part = () => {
    i++; // 0x02
    const len = der[i++];
    let v = der.slice(i, i + len);
    i += len;
    while (v.length > 32 && v[0] === 0) v = v.slice(1);
    const p = new Uint8Array(32);
    p.set(v, 32 - v.length);
    return p;
  };
  const r = part();
  const s = part();
  const raw = new Uint8Array(64);
  raw.set(r, 0);
  raw.set(s, 32);
  return raw;
}

async function verifyAdmob(url, fetchKeys) {
  const q = url.search.slice(1);
  const at = q.indexOf("&signature=");
  if (at < 0) return false;
  const message = q.slice(0, at);
  const sig = url.searchParams.get("signature");
  const keyId = url.searchParams.get("key_id");
  if (!sig || !keyId) return false;
  const keys = await fetchKeys();
  const k = (keys.keys || []).find((x) => String(x.keyId) === String(keyId));
  if (!k) return false;
  const pub = await crypto.subtle.importKey(
    "spki", b64ToBytes(k.base64), { name: "ECDSA", namedCurve: "P-256" }, false, ["verify"]);
  return crypto.subtle.verify(
    { name: "ECDSA", hash: "SHA-256" }, pub, derToRaw(b64ToBytes(sig)), new TextEncoder().encode(message));
}

async function quota(db, device, day) {
  const tier = await tierOf(db, device);
  const left = {};
  for (const m of Object.keys(SYSTEM)) {
    left[m] = Math.max(0, LIMITS[tier][m] - (await getN(db, "d:" + day + ":" + m + ":" + device)));
  }
  return {
    tier,
    left,
    bonus: await getN(db, "b:" + day + ":" + device),
    ads_left: Math.max(0, MAX_ADS_PER_DAY - (await getN(db, "a:" + day + ":" + device))),
  };
}

async function callClaude(env, mode, content, hist = [], trich = "") {
  // Hỏi Trợ lý qua Claude luôn kèm kiến thức nền về chế độ nhà giáo (mô hình chưa biết văn bản năm 2026)
  // và các điều văn bản gốc tìm được trong kho (trich)
  const system = mode === "hoi" ? sysOf(mode) + "\n" + KIEN_THUC + trich : sysOf(mode);
  let r;
  try {
    r = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "x-api-key": env.ANTHROPIC_API_KEY,
        "anthropic-version": "2023-06-01",
        "content-type": "application/json",
      },
      body: JSON.stringify({
        model: MODEL,
        max_tokens: MAX_OUT[mode] || MAX_TOKENS,
        system,
        messages: [
          ...hist.flatMap((t) => [{ role: "user", content: t.q }, { role: "assistant", content: t.a }]),
          { role: "user", content },
        ],
      }),
    });
  } catch {
    return { err: "loi_mang", msg: "Không kết nối được dịch vụ AI, thầy cô thử lại sau." };
  }
  if (!r.ok) {
    // 400 do hết hạn mức chi tiêu, 401 sai khóa, 429 quá tải, 529 dịch vụ bận
    console.log(JSON.stringify({ ev: "ai_error", status: r.status, mode }));
    const code = r.status === 401 ? "sai_khoa_ai" : r.status === 429 || r.status === 529 ? "ai_ban" : "loi_ai";
    return { err: code, msg: "Dịch vụ AI đang bận hoặc tạm dừng, thầy cô thử lại sau.", status: r.status };
  }
  const data = await r.json();
  const text = (data.content || []).filter((c) => c.type === "text").map((c) => c.text).join("").trim();
  if (!text) {
    console.log(JSON.stringify({ ev: "ai_empty", mode, stop: data.stop_reason }));
    return { err: "loi_ai", msg: "AI chưa trả lời được, thầy cô thử lại.", status: "rong:" + data.stop_reason };
  }
  return { text, by: "claude", usage: data.usage || {} };
}

async function callGemini(env, mode, input, imgs, hist = []) {
  let last = null;
  for (const model of GEMINI_MODELS) {
    last = await callGeminiOnce(env, mode, input, imgs, model, hist);
    if (!last.err || !/^(429|503|504)/.test(String(last.status))) return last;
  }
  return last;
}

async function callGeminiOnce(env, mode, input, imgs, model, hist = []) {
  const parts = [
    ...imgs.map((a) => ({ inline_data: { mime_type: "image/jpeg", data: a } })),
    { text: input || (mode === "hoi" ? "Giải thích nội dung trong ảnh." : "Giải đề trong ảnh.") },
  ];
  let r;
  try {
    r = await env.GEMINI.fetch("https://gemini/", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        model,
        body: {
          systemInstruction: { parts: [{ text: sysOf(mode) }] },
          contents: [
            ...hist.flatMap((t) => [{ role: "user", parts: [{ text: t.q }] }, { role: "model", parts: [{ text: t.a }] }]),
            { role: "user", parts },
          ],
          // Mô hình có bước suy nghĩ cũng tính vào giới hạn, nên để rộng
          generationConfig: { maxOutputTokens: 8192 },
        },
      }),
    });
  } catch {
    return { err: "loi_mang", status: 0 };
  }
  if (!r.ok) {
    let why = "";
    try { const e = (await r.json()).error || {}; why = (e.status || "") + " " + String(e.message || "").slice(0, 120); } catch {}
    return { err: "loi_ai", status: r.status + (why ? ":" + why : "") };
  }
  const data = await r.json();
  const c = (data.candidates || [])[0] || {};
  const text = ((c.content || {}).parts || []).filter((p) => p.text && !p.thought).map((p) => p.text).join("").trim();
  if (!text) return { err: "loi_ai", status: "rong:" + (c.finishReason || "") };
  const u = data.usageMetadata || {};
  return { text, by: "gemini", usage: { input_tokens: u.promptTokenCount, output_tokens: u.candidatesTokenCount } };
}

export default {
  async fetch(request, env, ctx, deps = {}) {
    const fetchKeys = deps.fetchKeys || (() => fetch(ADMOB_KEYS_URL).then((r) => r.json()));
    const url = new URL(request.url);
    const db = env.DB;
    // Nhận cả tên biến ANTHROPIC_API (đã tạo trên Cloudflare) lẫn ANTHROPIC_API_KEY
    env = { ...env, ANTHROPIC_API_KEY: env.ANTHROPIC_API_KEY || env.ANTHROPIC_API };
    if (request.method === "OPTIONS") return json({ ok: true });
    if (url.pathname === "/health") {
      return json({
        ok: true,
        ai_enabled: env.AI_ENABLED !== "0",
        has_key: Boolean(env.ANTHROPIC_API_KEY),
        has_db: Boolean(db),
      });
    }
    if (PAGES[url.pathname]) return page(url.pathname);
    if (url.pathname === "/tin" && request.method === "GET") {
      return new Response(JSON.stringify(TIN), {
        headers: { "content-type": "application/json; charset=utf-8", "cache-control": "public, max-age=300" },
      });
    }
    if (!db) return err("chua_cau_hinh", "Máy chủ chưa được cấu hình xong.", 503);
    const day = vnDate();

    // AdMob gọi về: cộng lượt thưởng
    if (url.pathname === "/v1/admob-ssv") {
      const device = url.searchParams.get("user_id") || "";
      const tx = url.searchParams.get("transaction_id") || "";
      if (!okDevice(device) || !tx) return err("sai_du_lieu", "Thiếu mã máy hoặc mã giao dịch.", 400);
      let valid = false;
      try {
        valid = await verifyAdmob(url, fetchKeys);
      } catch {
        valid = false;
      }
      if (!valid) return err("sai_chu_ky", "Chữ ký không hợp lệ.", 403);
      if ((await addN(db, "tx:" + tx, 1)) > 1) return json({ ok: true, duplicate: true });
      const ads = await addN(db, "a:" + day + ":" + device, 1);
      if (ads > MAX_ADS_PER_DAY) return json({ ok: true, capped: true });
      const bonus = await addN(db, "b:" + day + ":" + device, BONUS_PER_AD);
      console.log(JSON.stringify({ ev: "ad_reward", day, device, bonus }));
      return json({ ok: true, bonus });
    }

    if (env.APP_KEY && request.headers.get("X-App-Key") !== env.APP_KEY) {
      return err("sai_khoa_app", "App không hợp lệ.", 401);
    }

    if (url.pathname === "/v1/quota" && request.method === "GET") {
      const device = url.searchParams.get("device_id") || "";
      if (!okDevice(device)) return err("sai_ma_may", "Mã máy không hợp lệ.", 400);
      return json({ ok: true, ...(await quota(db, device, day)) });
    }

    // Xóa dữ liệu của tôi: xóa bộ đếm lượt, lượt thưởng và nội dung đã báo cáo của máy này
    // (giữ thông tin gói Pro đã mua và danh sách chặn)
    if (url.pathname === "/v1/delete" && request.method === "POST") {
      let b;
      try {
        b = await request.json();
      } catch {
        return err("sai_du_lieu", "Dữ liệu gửi lên không đúng định dạng.", 400);
      }
      const device = String(b.device_id || "");
      if (!okDevice(device)) return err("sai_ma_may", "Mã máy không hợp lệ.", 400);
      await db.prepare("DELETE FROM counters WHERE k LIKE ?").bind("%:" + device).run();
      await db.prepare("DELETE FROM reports WHERE device = ?").bind(device).run();
      console.log(JSON.stringify({ ev: "delete", device }));
      return json({ ok: true, message: "Đã xóa dữ liệu của máy này trên máy chủ." });
    }

    // Báo cáo nội dung AI: lưu 90 ngày để xem xét, mỗi máy tối đa 20 báo cáo mỗi ngày
    if (url.pathname === "/v1/report" && request.method === "POST") {
      let b;
      try {
        b = await request.json();
      } catch {
        return err("sai_du_lieu", "Dữ liệu gửi lên không đúng định dạng.", 400);
      }
      const device = String(b.device_id || "");
      if (!okDevice(device)) return err("sai_ma_may", "Mã máy không hợp lệ.", 400);
      if ((await addN(db, "r:" + day + ":" + device, 1)) > 20) {
        return err("qua_nhieu", "Hôm nay thầy cô đã gửi nhiều báo cáo, xin cảm ơn.", 429);
      }
      const now = Date.now();
      await db
        .prepare("INSERT INTO reports (device, mode, input, output, reason, created, exp) VALUES (?, ?, ?, ?, ?, ?, ?)")
        .bind(device, String(b.mode || "").slice(0, 20), String(b.input || "").slice(0, MAX_INPUT),
          String(b.output || "").slice(0, 4000), String(b.reason || "").slice(0, 500), now, now + 90 * 86400 * 1000)
        .run();
      return json({ ok: true, message: "Cảm ơn thầy cô, chúng tôi sẽ xem xét." });
    }

    // Đọc to qua máy chủ, dùng khi điện thoại không có bộ đọc tiếng Việt.
    // Mặc định dùng Gemini đọc thành tiếng (gói miễn phí, chung khóa Gemini); có khóa Google Cloud thì dùng Google Cloud.
    if (url.pathname === "/v1/tts" && request.method === "POST") {
      let b;
      try { b = await request.json(); } catch { return err("sai_du_lieu", "Dữ liệu gửi lên không đúng định dạng.", 400); }
      const device = String(b.device_id || "").slice(0, 64);
      const text = String(b.text || "").trim();
      if (!okDevice(device)) return err("sai_ma_may", "Mã máy không hợp lệ.", 400);
      if (!text) return err("trong", "Chưa có chữ để đọc.", 400);
      if (text.length > TTS_MAX_CHARS) return err("qua_dai", "Mỗi lần đọc tối đa " + TTS_MAX_CHARS + " ký tự.", 400);
      if (!env.GOOGLE_TTS_KEY && !env.GEMINI) return err("chua_bat", "Giọng đọc qua mạng chưa được bật.", 503);
      const key = "t:" + day + ":" + device;
      if ((await getN(db, key)) + text.length > TTS_DAY_CHARS) {
        return err("het_luot", "Hôm nay máy này đã nghe đọc nhiều quá, mai dùng tiếp nhé.", 429);
      }
      const res = env.GOOGLE_TTS_KEY ? await ttsGoogle(env, text, b.rate) : await ttsGemini(env, text);
      if (res.err) {
        console.log(JSON.stringify({ ev: "tts_error", status: res.status }));
        return err(res.err, res.msg, res.err === "het_luot_chung" ? 429 : 502);
      }
      await addN(db, key, text.length);
      return json({ ok: true, audio: res.audio, mime: res.mime, by: res.by });
    }

    // Kho văn bản: nạp, xem danh sách, xuất (cần khóa quản trị)
    if (url.pathname.startsWith("/v1/kt/")) {
      if (!(await khoaDung(request.headers.get("X-Kt-Key")))) return err("khong_quyen", "Sai khóa quản trị.", 403);
      if (url.pathname === "/v1/kt/nap" && request.method === "POST") {
        let vb;
        try {
          vb = await request.json();
        } catch {
          return err("sai_du_lieu", "Dữ liệu không đúng.", 400);
        }
        if (!vb.so || !vb.text || String(vb.text).length < 200) return err("sai_du_lieu", "Thiếu số hiệu hoặc nội dung.", 400);
        const n = await napVanBan(db, vb);
        return json({ ok: true, so: vb.so, so_doan: n, ky_tu: String(vb.text).length });
      }
      if (url.pathname === "/v1/kt/ds") return json({ ok: true, ds: await dsVanBan(db) });
      if (url.pathname === "/v1/kt/xuat") return json({ ok: true, text: await xuatVanBan(db, url.searchParams.get("so") || "") });
      if (url.pathname === "/v1/kt/tim") return json({ ok: true, trich: await timKienThuc(db, url.searchParams.get("q") || "") });
      return err("khong_tim_thay", "Đường dẫn không đúng.", 404);
    }

    if (url.pathname !== "/v1/ai" || request.method !== "POST") {
      return err("khong_tim_thay", "Đường dẫn không đúng.", 404);
    }
    if (env.AI_ENABLED === "0") {
      return err("tam_khoa", "Tính năng AI đang tạm dừng, thầy cô vui lòng thử lại sau.", 503);
    }
    if (!env.ANTHROPIC_API_KEY) {
      return err("chua_cau_hinh", "Máy chủ chưa được cấu hình xong.", 503);
    }

    let body;
    try {
      body = await request.json();
    } catch {
      return err("sai_du_lieu", "Dữ liệu gửi lên không đúng định dạng.", 400);
    }
    const mode = String(body.mode || "");
    const input = String(body.input || "").trim();
    const device = String(body.device_id || "").slice(0, 64);
    if (!SYSTEM[mode]) return err("sai_che_do", "Chế độ không hợp lệ.", 400);
    if (!okDevice(device)) return err("sai_ma_may", "Mã máy không hợp lệ.", 400);
    const imgs = Array.isArray(body.images) ? body.images.filter((a) => typeof a === "string" && a) : [];
    if (imgs.length && !IMG_MODES.includes(mode)) return err("sai_du_lieu", "Chế độ này không nhận ảnh.", 400);
    if (imgs.length > 4 || imgs.some((a) => a.length > 2000000)) return err("anh_lon", "Tối đa 4 ảnh, mỗi ảnh dưới 1,5 MB.", 400);
    const pdfs = Array.isArray(body.pdfs) ? body.pdfs.filter((a) => typeof a === "string" && a) : [];
    if (pdfs.length && !IMG_MODES.includes(mode)) return err("sai_du_lieu", "Chế độ này không nhận tệp PDF.", 400);
    if (pdfs.length > 1 || pdfs.some((a) => a.length > 6000000)) return err("pdf_lon", "Mỗi lần gửi một tệp PDF, dưới 4 MB.", 400);
    if (!input && !imgs.length && !pdfs.length) return err("trong", "Thầy cô chưa nhập nội dung.", 400);
    const maxIn = MAX_IN[mode] || MAX_INPUT;
    if (input.length > maxIn) {
      return err("qua_dai", "Nội dung dài quá, tối đa " + maxIn + " ký tự.", 400);
    }
    const content = imgs.length || pdfs.length
      ? [...pdfs.map((a) => ({ type: "document", source: { type: "base64", media_type: "application/pdf", data: a } })),
        ...imgs.map((a) => ({ type: "image", source: { type: "base64", media_type: "image/jpeg", data: a } })),
        { type: "text", text: input || (mode === "hoi" ? "Giải thích nội dung trong tệp." : "Giải đề trong tệp.") }]
      : input;
    if (await getFlag(db, "block:" + device)) {
      return err("bi_chan", "Máy này đã bị tạm dừng dùng AI. Thầy cô liên hệ hỗ trợ trong app.", 403);
    }

    // Đếm lượt: dùng lượt trong ngày trước, hết thì dùng lượt thưởng
    const ip = request.headers.get("CF-Connecting-IP") || "khong-ro";
    const tier = await tierOf(db, device);
    const limit = LIMITS[tier][mode];
    const devKey = "d:" + day + ":" + mode + ":" + device;
    const bonusKey = "b:" + day + ":" + device;
    const used = await getN(db, devKey);
    const bonus = used >= limit ? await getN(db, bonusKey) : 0;
    if (used >= limit && bonus <= 0) {
      const ads = await getN(db, "a:" + day + ":" + device);
      const more = ads < MAX_ADS_PER_DAY && tier === "free"
        ? " Thầy cô có thể xem một quảng cáo ngắn để nhận thêm " + BONUS_PER_AD + " lượt."
        : " Mai dùng tiếp nhé.";
      return err("het_luot", "Hôm nay thầy cô đã dùng hết " + limit + " lượt." + more, 429);
    }
    if ((await addN(db, "ip:" + day + ":" + ip, 1)) > IP_LIMIT) {
      return err("qua_nhieu", "Mạng này đã gửi quá nhiều yêu cầu hôm nay.", 429);
    }

    // Câu có thông tin cá nhân (app đánh dấu private) luôn đi qua Claude
    const priv = body.private === true;
    const hist = historyOf(body, mode);
    let res = null;
    let gem = null; // lý do Gemini không trả lời (để chẩn đoán, không chứa dữ liệu người dùng)
    // Ảnh gửi Gemini gói miễn phí hay bị treo lâu (thử ngày 19/11), nên câu có ảnh đi thẳng Claude
    const cheDo = mode === "hoi" && laCauCheDo(input, hist);
    if (!priv && !cheDo && !imgs.length && !pdfs.length && GEMINI_MODES.includes(mode) && env.GEMINI) {
      res = await callGemini(env, mode, input, imgs, hist);
      if (res.err) {
        gem = String(res.status);
        console.log(JSON.stringify({ ev: "gemini_fallback", status: res.status, device, mode }));
      }
    }
    let trich = "";
    if ((!res || res.err) && mode === "hoi") {
      trich = await timKienThuc(db, [input, ...hist.slice(-1).map((h) => h.q)].join("\n"));
    }
    if (!res || res.err) res = await callClaude(env, mode, content, hist, trich);
    if (res.err) return json({ ok: false, error: res.err, message: res.msg, gem, claude: String(res.status || "") }, 502);
    const text = res.text;
    const data = { usage: res.usage };

    // Trừ lượt sau khi AI đã trả kết quả
    let usedNow = used;
    let leftBonus = bonus;
    if (used >= limit) {
      leftBonus = await addN(db, bonusKey, -1);
    } else {
      usedNow = await addN(db, devKey, 1);
    }
    // Thỉnh thoảng dọn bộ đếm cũ
    if (Math.random() < 0.01 && ctx && ctx.waitUntil) ctx.waitUntil(cleanup(db));
    // Nhật ký (xem trong Observability > Logs) để phát hiện máy dùng bất thường
    const u = data.usage || {};
    console.log(JSON.stringify({ ev: "ai", day, device, mode, tier, ip, by: res.by, priv, cheDo, kt: trich.length, in: u.input_tokens, out: u.output_tokens }));
    return json({
      ok: true,
      text,
      by: res.by,
      ...(gem ? { gem } : {}),
      remaining: Math.max(0, limit - usedNow),
      bonus: Math.max(0, leftBonus),
    });
  },
};

// ---- Trang công khai: Điều khoản sử dụng, Chính sách quyền riêng tư ----
function esc(s) {
  return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

function inline(s) {
  return esc(s)
    .replace(/\*\*(.+?)\*\*/g, "<b>$1</b>")
    .replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2">$1</a>');
}

// Đổi markdown đơn giản (tiêu đề, đoạn, danh sách, bảng) thành HTML
function mdToHtml(md) {
  const out = [];
  const lines = md.split("\n");
  let i = 0;
  while (i < lines.length) {
    const l = lines[i];
    if (!l.trim()) { i++; continue; }
    if (l.startsWith("## ")) { out.push("<h2>" + inline(l.slice(3)) + "</h2>"); i++; continue; }
    if (l.startsWith("| ")) {
      const rows = [];
      while (i < lines.length && lines[i].startsWith("|")) { rows.push(lines[i]); i++; }
      const cells = (r) => r.slice(1, -1).split(" | ").map((c) => c.trim());
      let h = "<table><tr>" + cells(rows[0]).map((c) => "<th>" + inline(c) + "</th>").join("") + "</tr>";
      for (const r of rows.slice(2)) h += "<tr>" + cells(r).map((c) => "<td>" + inline(c) + "</td>").join("") + "</tr>";
      out.push(h + "</table>");
      continue;
    }
    if (/^(- |\d+\. )/.test(l)) {
      const ordered = /^\d+\. /.test(l);
      let h = ordered ? "<ol>" : "<ul>";
      while (i < lines.length && /^(- |\d+\. |    - )/.test(lines[i])) {
        if (lines[i].startsWith("    - ")) {
          let sub = "<ul>";
          while (i < lines.length && lines[i].startsWith("    - ")) { sub += "<li>" + inline(lines[i].slice(6)) + "</li>"; i++; }
          h = h.replace(/<\/li>$/, sub + "</ul></li>");
          continue;
        }
        h += "<li>" + inline(lines[i].replace(/^(- |\d+\. )/, "")) + "</li>";
        i++;
      }
      out.push(h + (ordered ? "</ol>" : "</ul>"));
      continue;
    }
    out.push("<p>" + inline(l) + "</p>");
    i++;
  }
  return out.join("\n");
}

function page(path) {
  const p = PAGES[path];
  const html = "<!doctype html><html lang=\"vi\"><head><meta charset=\"utf-8\">" +
    "<meta name=\"viewport\" content=\"width=device-width,initial-scale=1\"><title>" + p.title + "</title><style>" +
    "body{font-family:system-ui,-apple-system,Segoe UI,Roboto,sans-serif;max-width:760px;margin:0 auto;padding:24px 16px;line-height:1.6;color:#1f2933;background:#fff}" +
    "h1{font-size:1.6em;color:#0b4f8a}h2{font-size:1.2em;margin-top:1.6em;color:#0b4f8a}" +
    "table{border-collapse:collapse;width:100%;font-size:.9em}th,td{border:1px solid #d5dde5;padding:6px 8px;text-align:left;vertical-align:top}th{background:#eef4fa}" +
    "a{color:#0b6bcb}.meta{color:#5b6b7a;font-size:.9em}</style></head><body>" +
    "<h1>" + p.title + "</h1><p class=\"meta\">Cập nhật: " + p.updated + "</p>" + mdToHtml(p.md) + "</body></html>";
  return new Response(html, { headers: { "Content-Type": "text/html; charset=utf-8", "Cache-Control": "public, max-age=3600" } });
}

const PAGES = {
  "/dieu-khoan": {
    title: "Điều khoản sử dụng – Trợ lý số Giáo viên - Một chạm",
    updated: "19/11/2026",
    md: String.raw`## 1. Giới thiệu và chấp nhận điều khoản
- "Trợ lý số Giáo viên - Một chạm" (gọi tắt là "Ứng dụng") là ứng dụng hỗ trợ công việc hành chính và chuyên môn của giáo viên, do ông Nguyễn Văn Toàn (gọi là "chúng tôi") cung cấp.
- Khi cài đặt hoặc sử dụng Ứng dụng, thầy cô đồng ý với Điều khoản sử dụng này và [Chính sách quyền riêng tư](/quyen-rieng-tu). Nếu không đồng ý, thầy cô vui lòng ngừng sử dụng và gỡ Ứng dụng.
- Ứng dụng được phân phối qua Google Play và App Store. Ngoài Điều khoản này, thầy cô còn chịu điều khoản của Google hoặc Apple khi tải, thanh toán và sử dụng.
## 2. Điều kiện sử dụng
- Ứng dụng dành cho giáo viên, cán bộ quản lý và người làm công tác giáo dục từ đủ 18 tuổi. Học sinh không phải là người dùng của Ứng dụng.
- Bản đầu không cần đăng ký tài khoản. Ứng dụng tạo một mã máy ngẫu nhiên để đếm lượt dùng tính năng AI; mã này không chứa tên, số điện thoại hay email.
- Gỡ Ứng dụng hoặc xóa dữ liệu Ứng dụng có thể làm mất các tệp lưu trên máy và lượt thưởng chưa dùng. Khi gói Pro được áp dụng, gói đã mua được khôi phục bằng nút "Khôi phục gói đã mua" trong trang Tài khoản, với cùng tài khoản Google hoặc Apple.
## 3. Tính năng AI và lượt sử dụng
- Các tính năng AI gồm: Hỏi Trợ lý (hỏi bằng chữ hoặc chụp ảnh), Nhờ AI viết nhận xét, Nhờ AI soạn tin, Giải đề, Ra đề tương tự, Nhờ AI sắp xếp biên bản. Hỏi Trợ lý trả lời câu hỏi thuộc nhiều chủ đề nhưng không có dữ liệu theo thời gian thực (giá cả, tỷ giá, tin tức trong ngày); thầy cô cần tự kiểm tra lại thông tin quan trọng.
- **Mỗi lượt** là một lần bấm nút và nhận được kết quả: một câu trả lời, một đoạn nhận xét cho một học sinh, hoặc một tin nhắn. Bấm "Viết lại" được tính thêm một lượt. Lần bấm bị lỗi (mất mạng, AI bận) không bị trừ lượt.
- Số lượt miễn phí mỗi ngày của Giải đề, nhận xét, tin nhắn hiển thị trong Ứng dụng; Hỏi Trợ lý không hiện số câu nhưng có giới hạn cao để chống lạm dụng. Lượt được tính lại từ 0 giờ theo giờ Việt Nam. Chúng tôi có thể điều chỉnh số lượt này và sẽ thông báo trong Ứng dụng.
- **Xem quảng cáo nhận lượt:** chưa áp dụng ở bản hiện tại. Khi mở, xem hết một quảng cáo nhận thưởng được thêm 5 lượt, tối đa 10 quảng cáo mỗi ngày. Lượt thưởng dùng trong ngày, không cộng dồn sang ngày sau, không đổi thành tiền.
- **Nội dung do AI tạo ra có thể sai hoặc chưa phù hợp.** Thầy cô luôn đọc, kiểm tra và sửa trước khi dùng, nhất là nhận xét học sinh, tin nhắn phụ huynh và thông tin về chế độ, văn bản. Nội dung AI không thay thế văn bản chính thức hay ý kiến của cơ quan có thẩm quyền.
- **Báo cáo nội dung:** gặp nội dung AI sai, xúc phạm hoặc không phù hợp, thầy cô bấm nút "Báo cáo" ngay dưới câu trả lời; chúng tôi xem xét và điều chỉnh.
- Tính năng AI có thể tạm dừng khi bảo trì, khi nhà cung cấp AI gặp sự cố hoặc khi vượt giới hạn chi phí của hệ thống. Các tiện ích chạy không cần mạng vẫn dùng bình thường.

Ứng dụng hiện được cung cấp miễn phí, không có quảng cáo và không có tính năng trả phí. Trong các phiên bản sau, nhà phát triển có thể bổ sung quảng cáo hoặc gói trả phí; khi đó ứng dụng sẽ thông báo trước ít nhất 7 ngày và Điều khoản này sẽ được cập nhật. Các tính năng cơ bản đang miễn phí vẫn tiếp tục được cung cấp miễn phí.
## 4. Gói Pro
Gói Pro chưa áp dụng. Giá và quyền lợi sẽ được công bố khi mở gói; mục này áp dụng từ thời điểm đó.
- **Quyền lợi:** nhiều lượt AI hơn gói miễn phí, tối đa số lượt mỗi tính năng mỗi ngày công bố khi mở gói. Giới hạn lượt mỗi ngày nhằm giữ dịch vụ ổn định và ngăn lạm dụng.
- **Giá:** công bố khi mở gói. Giá chính thức là giá hiển thị trên Google Play hoặc App Store tại thời điểm mua, đã gồm các khoản thuế do kho ứng dụng áp dụng.
- **Thanh toán:** thầy cô trả tiền qua tài khoản Google Play hoặc Apple. Chúng tôi không thu tiền trực tiếp và không lưu thông tin thẻ hay tài khoản ngân hàng của thầy cô.
- **Tự động gia hạn:** gói tự gia hạn và trừ tiền khi hết kỳ, trừ khi thầy cô hủy trước thời điểm gia hạn theo quy định của kho (với App Store: ít nhất 24 giờ trước khi hết kỳ).
- **Hủy gói:**
    - Android: Google Play → ảnh đại diện → Thanh toán và gói đăng ký → Gói đăng ký → Trợ lý số Giáo viên → Hủy.
    - iPhone: Cài đặt → tên tài khoản Apple → Đăng ký → Trợ lý số Giáo viên → Hủy.
    - Gỡ Ứng dụng không tự hủy gói. Sau khi hủy, quyền lợi Pro vẫn còn đến hết kỳ đã trả.
- **Thay đổi giá:** nếu tăng giá, chúng tôi báo trước qua Ứng dụng và kho ứng dụng; giá mới chỉ áp dụng từ kỳ gia hạn sau khi thầy cô được thông báo theo quy định của kho.
## 5. Hoàn tiền
Tiền mua gói Pro do Google hoặc Apple thu, nên việc hoàn tiền trước hết theo chính sách của kho nơi thầy cô mua.
| Nơi mua | Cách yêu cầu hoàn tiền | Chúng tôi hỗ trợ |
| --- | --- | --- |
| Google Play | Trong 48 giờ sau khi mua: yêu cầu ngay trên Google Play. Quá 48 giờ: liên hệ chúng tôi | Chúng tôi có thể hoàn tiền qua Google Play Console trong các trường hợp dưới đây |
| App Store | Yêu cầu tại reportaproblem.apple.com; Apple xem xét và quyết định | Nhà phát triển không tự hoàn tiền được; chúng tôi xác nhận lỗi để thầy cô gửi Apple |
- **Chúng tôi đề nghị hoàn tiền kỳ đã trả** khi: bị trừ tiền hai lần cho cùng một kỳ; hoặc tính năng AI của gói Pro không dùng được liên tục quá 3 ngày do lỗi từ phía chúng tôi.
- **Không hoàn tiền** phần thời gian còn lại khi thầy cô tự hủy giữa kỳ (quyền lợi vẫn dùng đến hết kỳ), trừ khi kho ứng dụng hoặc pháp luật quy định khác.
- Khi liên hệ về hoàn tiền, thầy cô gửi mã đơn hàng trong email biên nhận của Google hoặc Apple và mô tả lỗi. Chúng tôi trả lời trong 3 ngày làm việc.
## 6. Quy tắc sử dụng
Thầy cô không được:
- Dùng Ứng dụng, kể cả tính năng AI, để tạo nội dung vi phạm pháp luật Việt Nam, xúc phạm, phân biệt đối xử, hoặc xâm phạm quyền của người khác.
- Nhập tên thật kèm thông tin nhạy cảm của học sinh, phụ huynh vào ô gửi AI, khi Ứng dụng đã cung cấp cách dùng mã thay tên.
- Tìm cách vượt giới hạn lượt (đổi mã máy hàng loạt, giả lượt xem quảng cáo, dùng công cụ tự động), hoặc khai thác máy chủ của Ứng dụng cho mục đích khác.
- Sao chép, bán lại, dịch ngược hoặc phát hành lại Ứng dụng.
Khi phát hiện vi phạm, chúng tôi có thể tạm dừng hoặc chặn tính năng AI trên máy đó mà không hoàn lại lượt đã dùng. Thầy cô cho rằng bị chặn nhầm thì liên hệ theo mục 8 để được xem xét.
## 7. Dữ liệu và quảng cáo
- Việc thu thập, xử lý dữ liệu cá nhân được nêu chi tiết trong [Chính sách quyền riêng tư](/quyen-rieng-tu), theo pháp luật Việt Nam về bảo vệ dữ liệu cá nhân.
- Tệp quét, ảnh thẻ, nhận xét, tin nhắn thầy cô tạo được lưu trên máy của thầy cô, trừ khi thầy cô chọn gửi lên AI.
- Khi dùng tính năng AI, nội dung thầy cô nhập được gửi qua máy chủ của chúng tôi tới nhà cung cấp AI để tạo câu trả lời. Câu hỏi bằng chữ không có thông tin cá nhân trong Hỏi Trợ lý, Giải đề, Ra đề tương tự được gửi tới Google (Gemini), nội dung này có thể được Google dùng để cải thiện dịch vụ; câu hỏi kèm ảnh, câu hỏi có tên học sinh, số điện thoại, email và các tính năng Nhận xét học sinh, Nhắn phụ huynh, sắp xếp biên bản được gửi tới Anthropic (Claude). Tên học sinh trong danh sách lớp được thay bằng mã trước khi gửi. Máy chủ chỉ lưu mã máy, địa chỉ mạng, số lượt và nhật ký kỹ thuật ngắn hạn, không lưu nội dung câu hỏi (trừ nội dung thầy cô bấm Báo cáo).
- Bản hiện tại không có quảng cáo. Nếu sau này bổ sung, quảng cáo do Google AdMob cung cấp và được thông báo trước theo mục 3. Thầy cô có thể điều chỉnh quảng cáo cá nhân hóa trong cài đặt của máy. Nội dung quảng cáo thuộc trách nhiệm của bên quảng cáo.
## 8. Trách nhiệm, thay đổi và liên hệ
- **Giới hạn trách nhiệm:** Ứng dụng được cung cấp theo hiện trạng. Trong phạm vi pháp luật cho phép, chúng tôi không chịu trách nhiệm về thiệt hại phát sinh từ việc dùng nội dung AI mà không kiểm tra, về dữ liệu mất do gỡ Ứng dụng hay hỏng máy. Trách nhiệm bồi hoàn của chúng tôi, nếu có, không vượt quá số tiền thầy cô đã trả cho gói Pro trong 3 tháng gần nhất.
- **Thay đổi dịch vụ:** chúng tôi có thể thêm, sửa hoặc ngừng một tiện ích, đổi nhà cung cấp AI. Nếu ngừng hẳn gói Pro, chúng tôi báo trước ít nhất 30 ngày và ngừng gia hạn.
- **Thay đổi Điều khoản:** bản mới được thông báo trong Ứng dụng và có hiệu lực từ ngày ghi trên bản đó. Thầy cô tiếp tục dùng nghĩa là đồng ý với bản mới.
- **Luật áp dụng:** Điều khoản này theo pháp luật Việt Nam. Tranh chấp ưu tiên giải quyết bằng thương lượng; không thành thì đưa ra cơ quan có thẩm quyền tại Việt Nam.
- **Liên hệ:** Nguyễn Văn Toàn · email hotro.trolysogv@gmail.com · trong Ứng dụng: Tài khoản → Hỗ trợ.`,
  },
  "/quyen-rieng-tu": {
    title: "Chính sách quyền riêng tư – Trợ lý số Giáo viên - Một chạm",
    updated: "19/11/2026",
    md: String.raw`## 1. Tóm tắt
- Ứng dụng "Trợ lý số Giáo viên - Một chạm" do ông Nguyễn Văn Toàn (gọi là "chúng tôi") cung cấp và chịu trách nhiệm xử lý dữ liệu nêu trong chính sách này.
- **Chúng tôi thu:** một mã máy ngẫu nhiên, địa chỉ mạng (IP) và số lượt dùng AI để giới hạn lượt và chống lạm dụng; nội dung thầy cô chủ động gửi cho AI, chỉ để tạo câu trả lời.
- **Chúng tôi không:** bán dữ liệu; lưu nội dung câu hỏi trên máy chủ; tải tệp quét, ảnh, ghi âm của thầy cô lên máy chủ khi thầy cô không dùng AI.
- Chính sách này áp dụng theo pháp luật Việt Nam về bảo vệ dữ liệu cá nhân và đi cùng [Điều khoản sử dụng](/dieu-khoan).
## 2. Dữ liệu thu thập và mục đích
| Dữ liệu | Mục đích | Nơi lưu | Thời gian lưu |
| --- | --- | --- | --- |
| Tệp quét PDF, ảnh thẻ, nhận xét, tin nhắn, ghi âm, lịch công tác | Các tiện ích của Ứng dụng | Trên máy của thầy cô | Đến khi thầy cô xóa hoặc gỡ Ứng dụng |
| Mã máy ngẫu nhiên (do Ứng dụng tạo, không gắn với tên hay số điện thoại) | Đếm lượt AI, chống lạm dụng (và ghi nhận gói Pro khi gói được áp dụng) | Trên máy và máy chủ | Bộ đếm lượt tự xóa sau 3 ngày; thông tin gói Pro lưu đến khi gói hết hạn |
| Địa chỉ mạng (IP) | Giới hạn số lượt mỗi mạng, chống lạm dụng | Máy chủ | Tự xóa sau 3 ngày |
| Nội dung thầy cô gửi cho AI (kể cả ảnh đề bài khi dùng Giải đề, ghi chép họp khi nhờ AI sắp xếp biên bản) và câu trả lời | Tạo câu trả lời, nhận xét, tin nhắn | Chỉ chuyển qua máy chủ, không lưu; nhà cung cấp AI xử lý theo mục 3 | Không lưu trên máy chủ của chúng tôi |
| Nhật ký kỹ thuật: thời điểm, mã máy, IP, loại tính năng, số ký tự (token) | Phát hiện lỗi, lạm dụng | Máy chủ | Tối đa 7 ngày |
| Nội dung thầy cô bấm "Báo cáo" | Xem xét và cải thiện câu trả lời AI | Máy chủ | Tối đa 90 ngày |
| Thư thầy cô gửi đến email hỗ trợ | Trả lời, hỗ trợ, hoàn tiền | Hộp thư hotro.trolysogv@gmail.com | Đến khi xử lý xong và tối đa 2 năm |
Chúng tôi chỉ dùng dữ liệu cho các mục đích trên. Thầy cô đồng ý khi dùng tính năng tương ứng và có thể rút lại đồng ý bằng cách ngừng dùng tính năng đó.
## 3. Bên thứ ba nhận dữ liệu
Chúng tôi không bán dữ liệu của thầy cô. Dữ liệu chỉ đến các bên dưới đây, để Ứng dụng hoạt động; các bên này có thể xử lý dữ liệu ngoài Việt Nam.
| Bên nhận | Nhận gì | Để làm gì | Chính sách của họ |
| --- | --- | --- | --- |
| Google (dịch vụ AI Gemini) | Câu hỏi bằng chữ không có thông tin cá nhân trong Hỏi Trợ lý, Giải đề, Ra đề tương tự; không kèm mã máy hay IP của thầy cô | Tạo câu trả lời; Google có thể dùng nội dung này để cải thiện dịch vụ | [ai.google.dev/gemini-api/terms](https://ai.google.dev/gemini-api/terms) |
| Anthropic (dịch vụ AI Claude) | Câu hỏi kèm ảnh, câu hỏi có tên học sinh, số điện thoại, email; nội dung Nhận xét học sinh, Nhắn phụ huynh, sắp xếp biên bản. Tên học sinh trong danh sách lớp đã thay bằng mã; không kèm mã máy hay IP | Tạo câu trả lời | [anthropic.com/legal/privacy](https://www.anthropic.com/legal/privacy) |
| Cloudflare (máy chủ) | Mã máy, IP, bộ đếm lượt, nhật ký kỹ thuật | Vận hành máy chủ của Ứng dụng | [cloudflare.com/privacypolicy](https://www.cloudflare.com/privacypolicy/) |
| Google AdMob (quảng cáo, chưa dùng ở bản hiện tại) | Mã quảng cáo của máy, IP, thông tin thiết bị, tương tác với quảng cáo; mã máy khi xem quảng cáo nhận thưởng | Hiện quảng cáo, xác nhận lượt thưởng | [policies.google.com/privacy](https://policies.google.com/privacy) |
| Google Play, Apple App Store | Thông tin mua gói Pro khi gói được áp dụng (chúng tôi không nhận số thẻ) | Thanh toán, gia hạn, hoàn tiền | [policies.google.com/privacy](https://policies.google.com/privacy), [apple.com/legal/privacy](https://www.apple.com/legal/privacy/) |
- Bản hiện tại không có quảng cáo và không thu dữ liệu quảng cáo. Khi bổ sung quảng cáo, Ứng dụng sẽ thông báo trước và cập nhật chính sách này.
- Chúng tôi chỉ cung cấp dữ liệu cho cơ quan nhà nước khi có yêu cầu hợp pháp theo quy định của pháp luật Việt Nam.
## 4. Dữ liệu học sinh và phụ huynh
- Ứng dụng dành cho giáo viên. Thông tin học sinh, phụ huynh (tên, điểm, nhận xét, số điện thoại) do thầy cô nhập và được lưu trên máy của thầy cô.
- Trước khi gửi lên AI, Ứng dụng thay tên học sinh có trong danh sách lớp bằng mã (ví dụ "HS07"); trong Nhận xét học sinh, tên thật được ghép lại trên máy sau khi nhận câu trả lời. Câu hỏi có dấu hiệu chứa tên người, số điện thoại, email được gửi tới Claude thay vì Gemini. Số điện thoại phụ huynh không được gửi lên AI.
- Thầy cô không nhập vào ô gửi AI các thông tin nhạy cảm của học sinh, phụ huynh (sức khỏe, hoàn cảnh gia đình, số định danh). Thầy cô và nhà trường chịu trách nhiệm về việc thu thập, sử dụng thông tin học sinh theo quy định của ngành.
- Phần Họp (ghi âm, biên bản) mặc định xử lý ngay trên máy; chỉ gửi lên AI khi thầy cô bấm đồng ý cho từng lần.
## 5. Quyền truy cập trên máy
Ứng dụng chỉ xin quyền khi thầy cô mở tiện ích cần đến; từ chối thì chỉ tiện ích đó không dùng được.
| Quyền | Dùng cho |
| --- | --- |
| Máy ảnh | Quét giấy tờ, chụp ảnh thẻ, chấm trắc nghiệm |
| Micro | Ghi âm cuộc họp, đọc giọng nói thành văn bản, nói vào ô Trợ lý |
| Ảnh và tệp | Chọn ảnh, lưu tệp PDF, Word, ảnh thẻ |
| Thông báo | Nhắc việc sắp đến hạn trong Lịch công tác |
| Mạng | Tính năng AI, tin cho thầy cô |
Ứng dụng không xin quyền vị trí, danh bạ hay tin nhắn.
## 6. Quyền của thầy cô và cách xóa dữ liệu
Theo pháp luật về bảo vệ dữ liệu cá nhân, thầy cô có quyền biết, xem, yêu cầu sửa, xóa dữ liệu của mình, rút lại đồng ý và khiếu nại.
1. **Xóa dữ liệu trên máy:** xóa tệp trong mục Tệp của tôi, hoặc gỡ Ứng dụng.
2. **Xóa dữ liệu trên máy chủ:** trong Ứng dụng vào Tài khoản → Xóa dữ liệu của tôi, hoặc gửi email đến hotro.trolysogv@gmail.com kèm mã máy (xem trong Tài khoản). Chúng tôi xóa trong 7 ngày làm việc. Bộ đếm lượt và nhật ký cũng tự xóa sau 3–7 ngày dù thầy cô không yêu cầu.
3. **Xem, sửa dữ liệu hoặc khiếu nại:** gửi email; chúng tôi trả lời trong 7 ngày làm việc.
4. **Rút lại đồng ý:** ngừng dùng tính năng AI, tắt quyền truy cập trong cài đặt máy, hoặc gỡ Ứng dụng.
Xóa dữ liệu không tự hủy gói Pro; thầy cô hủy gói trên Google Play hoặc App Store.
## 7. Bảo mật, trẻ em, thay đổi và liên hệ
- **Bảo mật:** dữ liệu giữa Ứng dụng và máy chủ được mã hóa khi truyền (HTTPS); khóa truy cập dịch vụ AI chỉ nằm trên máy chủ, không nằm trong Ứng dụng. Khi xảy ra sự cố lộ dữ liệu, chúng tôi thông báo cho người dùng và cơ quan có thẩm quyền theo quy định.
- **Trẻ em:** Ứng dụng dành cho người từ đủ 18 tuổi, không dành cho học sinh và không cố ý thu dữ liệu trực tiếp từ trẻ em.
- **Thay đổi chính sách:** bản mới được thông báo trong Ứng dụng, ghi ngày cập nhật ở đầu trang. Thay đổi lớn (thu thêm loại dữ liệu mới) sẽ xin đồng ý lại.
- **Liên hệ:** Nguyễn Văn Toàn · email hotro.trolysogv@gmail.com · trong Ứng dụng: Tài khoản → Hỗ trợ.`,
  },
  "/ho-tro": {
    title: "Hỗ trợ – Trợ lý số Giáo viên - Một chạm",
    updated: "18/11/2026",
    md: String.raw`## Liên hệ
- Email: **hotro.trolysogv@gmail.com**. Chúng tôi trả lời trong vòng 3 ngày làm việc.
- Khi báo lỗi, thầy cô ghi kèm **mã máy** (Tài khoản → Mã máy, bấm để chép), tên điện thoại và mô tả việc đang làm.
## Câu hỏi thường gặp
- **Mỗi ngày được bao nhiêu lượt AI?** Hỏi Trợ lý thoải mái (có giới hạn chống lạm dụng), Nhờ AI viết nhận xét 100 lượt, Nhờ AI soạn tin 100 lượt, Giải đề 10 lượt, Ra đề tương tự 10 lượt, Nhờ AI sắp xếp biên bản 20 lượt. Lượt được làm mới lúc 0 giờ (giờ Việt Nam).
- **AI trả lời sai thì sao?** Thầy cô bấm **Báo cáo** dưới câu trả lời. AI có thể nhầm, thầy cô kiểm tra lại thông tin quan trọng trước khi dùng.
- **Dữ liệu học sinh có bị gửi đi không?** Danh sách học sinh, điểm, biên bản, ảnh lưu trên điện thoại. Khi bấm nút AI, tên học sinh được thay bằng mã HS01, HS02.
- **Xóa dữ liệu thế nào?** Tài khoản → Xóa dữ liệu của tôi trên máy chủ. Dữ liệu trên điện thoại xóa khi gỡ Ứng dụng.
- **Đổi điện thoại có mất dữ liệu không?** Có. Bản này chưa có sao lưu, thầy cô xuất PDF, Excel những gì cần giữ trước khi đổi máy.
## Văn bản liên quan
- [Điều khoản sử dụng](/dieu-khoan)
- [Chính sách quyền riêng tư](/quyen-rieng-tu)`,
  },
};
