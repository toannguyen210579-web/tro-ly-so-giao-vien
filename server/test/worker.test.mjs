// Kiểm thử máy chủ không cần mạng: giả lập D1, Gemini, Claude.  Chạy: node --test server/test
import test from "node:test";
import assert from "node:assert/strict";
import worker from "../worker.js";

function giaD1() {
  const c = new Map();
  const flags = new Map();
  const db = {
    flags,
    prepare(sql) {
      const lenh = (a) => ({
        async first() {
          if (sql.startsWith("SELECT n")) return c.has(a[0]) ? { n: c.get(a[0]) } : null;
          if (sql.startsWith("INSERT INTO counters")) { c.set(a[0], (c.get(a[0]) || 0) + a[1]); return { n: c.get(a[0]) }; }
          if (sql.startsWith("SELECT v FROM flags")) return flags.has(a[0]) ? { v: flags.get(a[0]) } : null;
          return null;
        },
        async run() {
          if (sql.startsWith("INSERT INTO flags")) flags.set(a[0], a[1]);
        },
        async all() {
          if (sql.startsWith("SELECT k, v FROM flags")) {
            return { results: [...flags].filter(([k]) => k.startsWith("tts_het:")).map(([k, v]) => ({ k, v })) };
          }
          return { results: [] };
        },
      });
      return { bind: (...a) => lenh(a), ...lenh([]) };
    },
  };
  return db;
}

function moiTruong({ gemini = "ok" } = {}) {
  const ghi = { gemini: [], claude: [] };
  globalThis.fetch = async (url, o) => {
    if (String(url).includes("anthropic")) {
      ghi.claude.push(JSON.parse(o.body));
      return new Response(JSON.stringify({ content: [{ type: "text", text: "Claude trả lời" }], usage: {} }), { status: 200 });
    }
    throw new Error("không mong gọi " + url);
  };
  const env = {
    DB: giaD1(),
    ANTHROPIC_API: "k",
    GEMINI: {
      async fetch(_u, o) {
        ghi.gemini.push(JSON.parse(o.body));
        if (gemini !== "ok") return new Response(JSON.stringify({ error: { status: "UNAVAILABLE" } }), { status: 503 });
        return new Response(JSON.stringify({ candidates: [{ content: { parts: [{ text: "Gemini trả lời" }] } }] }), { status: 200 });
      },
    },
  };
  return { env, ghi };
}

const goi = (env, body) =>
  worker.fetch(new Request("https://x/v1/ai", { method: "POST", body: JSON.stringify({ device_id: "kiemthu123", ...body }) }), env, {}).then((r) => r.json());

test("Hỏi Trợ lý biết ngày giờ Việt Nam", async () => {
  const { env, ghi } = moiTruong();
  const r = await goi(env, { mode: "hoi", input: "Hôm nay ngày mấy?" });
  assert.equal(r.ok, true);
  assert.equal(r.by, "gemini");
  const sys = ghi.gemini[0].body.systemInstruction.parts[0].text;
  assert.match(sys, /Hiện tại ở Việt Nam là (Thứ|Chủ nhật).*ngày \d\d\/\d\d\/20\d\d, \d\d giờ \d\d\./);
});

test("Hỏi tiếp giữ ngữ cảnh: Gemini và Claude đều nhận các lượt trước", async () => {
  const hist = [{ q: "Trò chơi khởi động là gì?", a: "Là hoạt động..." }, { q: "Chơi thế nào?", a: "Chia nhóm..." }];
  const a = moiTruong();
  await goi(a.env, { mode: "hoi", input: "Cho ví dụ", history: hist });
  const c = a.ghi.gemini[0].body.contents;
  assert.equal(c.length, 5);
  assert.deepEqual(c.map((x) => x.role), ["user", "model", "user", "model", "user"]);
  assert.equal(c[4].parts[0].text, "Cho ví dụ");

  const b = moiTruong({ gemini: "loi" });
  const r = await goi(b.env, { mode: "hoi", input: "Cho ví dụ", history: hist });
  assert.equal(r.by, "claude");
  assert.deepEqual(b.ghi.claude[0].messages.map((x) => x.role), ["user", "assistant", "user", "assistant", "user"]);
});

test("Ngữ cảnh chỉ dùng cho Hỏi Trợ lý, tối đa 4 lượt, bỏ lượt hỏng", async () => {
  const hist = [1, 2, 3, 4, 5, 6].map((i) => ({ q: "h" + i, a: "t" + i }));
  const a = moiTruong();
  await goi(a.env, { mode: "hoi", input: "x", history: [...hist, { q: "", a: "y" }, "rác", null] });
  assert.equal(a.ghi.gemini[0].body.contents.length, 9);
  assert.equal(a.ghi.gemini[0].body.contents[0].parts[0].text, "h3");
  const b = moiTruong();
  await goi(b.env, { mode: "giaide", input: "Câu 1. 1+1", history: hist });
  assert.equal(b.ghi.gemini[0].body.contents.length, 1);
});

test("Tin nhắn phụ huynh giữ chỗ trống [tên học sinh]", async () => {
  const { env, ghi } = moiTruong();
  await goi(env, { mode: "tinnhan", input: "Loại tin: Mời họp." });
  assert.match(ghi.claude[0].system, /\[tên học sinh\]/);
  assert.match(ghi.claude[0].system, /không đổi thành \[mã học sinh\]/);
});

test("Câu riêng tư đi thẳng Claude, kèm ngữ cảnh", async () => {
  const { env, ghi } = moiTruong();
  const r = await goi(env, { mode: "hoi", input: "HS01 nói chuyện", private: true, history: [{ q: "a", a: "b" }] });
  assert.equal(r.by, "claude");
  assert.equal(ghi.gemini.length, 0);
  assert.equal(ghi.claude[0].messages.length, 3);
});

const goiTts = (env, body) =>
  worker.fetch(new Request("https://x/v1/tts", { method: "POST", body: JSON.stringify({ device_id: "kiemthu123", ...body }) }), env, {});

test("Đọc to qua máy chủ: không có Gemini lẫn khóa Google thì báo chưa bật", async () => {
  const { env } = moiTruong();
  delete env.GEMINI;
  const r = await goiTts(env, { text: "Xin chào" });
  assert.equal(r.status, 503);
  assert.equal((await r.json()).error, "chua_bat");
});

test("Đọc to bằng Gemini: âm thanh thô được đóng thành WAV, hết lượt mô hình này thì thử mô hình sau", async () => {
  const { env } = moiTruong();
  const goi = [];
  env.GEMINI = {
    async fetch(_u, o) {
      const b = JSON.parse(o.body);
      goi.push(b);
      if (goi.length === 1) return new Response(JSON.stringify({ error: { code: 429 } }), { status: 429 });
      const pcm = Buffer.from([1, 0, 2, 0, 3, 0, 4, 0]).toString("base64");
      return new Response(JSON.stringify({ candidates: [{ content: { parts: [{ inlineData: { mimeType: "audio/L16;codec=pcm;rate=24000", data: pcm } }] } }] }), { status: 200 });
    },
  };
  const r = await (await goiTts(env, { text: "Kính gửi quý phụ huynh" })).json();
  assert.equal(r.ok, true);
  assert.equal(r.by, "gemini");
  assert.equal(r.mime, "audio/wav");
  const wav = Buffer.from(r.audio, "base64");
  assert.equal(wav.subarray(0, 4).toString(), "RIFF");
  assert.equal(wav.readUInt32LE(24), 24000);
  assert.equal(wav.readUInt32LE(40), 8);
  assert.equal(wav.length, 52);
  assert.equal(goi[0].model, "gemini-3.8-flash-tts");
  assert.equal(goi[1].model, "gemini-3.8-flash-lite-tts");
  assert.equal(r.mo_hinh, "gemini-3.8-flash-lite-tts");
  assert.deepEqual(goi[0].body.generationConfig.responseModalities, ["AUDIO"]);
  assert.equal(goi[0].body.contents[0].parts[0].text, "Kính gửi quý phụ huynh");
});

// Lời báo 429 thật của Gemini (rút gọn): hết lượt theo ngày hoặc theo phút
const bao429 = (loai, giay = "37s") =>
  new Response(JSON.stringify({
    error: {
      code: 429, status: "RESOURCE_EXHAUSTED", message: "You exceeded your current quota.",
      details: [
        { "@type": "type.googleapis.com/google.rpc.QuotaFailure",
          violations: [{ quotaMetric: "generativelanguage.googleapis.com/generate_content_free_tier_requests",
            quotaId: loai === "ngay" ? "GenerateRequestsPerDayPerProjectPerModel-FreeTier" : "GenerateRequestsPerMinutePerProjectPerModel-FreeTier" }] },
        { "@type": "type.googleapis.com/google.rpc.RetryInfo", retryDelay: giay },
      ],
    },
  }), { status: 429 });

const amThanh = () => new Response(JSON.stringify({
  candidates: [{ content: { parts: [{ inlineData: { mimeType: "audio/L16;codec=pcm;rate=24000", data: "AQACAA==" } }] } }],
}), { status: 200 });

test("Đọc to: không dùng gemini-3.1-flash-tts-preview (để dành cho lồng tiếng clip)", async () => {
  const { env } = moiTruong();
  const goi = [];
  env.GEMINI = { fetch: async (_u, o) => { goi.push(JSON.parse(o.body).model); return bao429("ngay"); } };
  await goiTts(env, { text: "Xin chào" });
  assert.deepEqual(goi, ["gemini-3.8-flash-tts", "gemini-3.8-flash-lite-tts", "gemini-2.5-flash-preview-tts"]);
});

test("Đọc to: mọi mô hình hết lượt ngày thì báo giờ dùng lại, lần sau trả lời ngay không gọi Google", async () => {
  const { env } = moiTruong();
  let dem = 0;
  env.GEMINI = { fetch: async () => { dem++; return bao429("ngay"); } };
  const r = await goiTts(env, { text: "Xin chào" });
  assert.equal(r.status, 429);
  const j = await r.json();
  assert.equal(j.error, "het_luot_chung");
  assert.match(j.message, /tạm hết lượt miễn phí trong ngày, sau 1[45] giờ/);
  assert.equal(dem, 3);
  // Lần gọi sau: không gọi Google nữa
  const r2 = await goiTts(env, { text: "Câu thứ hai" });
  assert.equal(r2.status, 429);
  assert.equal((await r2.json()).error, "het_luot_chung");
  assert.equal(dem, 3);
  // Trang kiểm tra máy chủ hiện các mô hình đang nghỉ
  const h = await (await worker.fetch(new Request("https://x/health"), env, {})).json();
  assert.equal(h.ok, true);
  assert.equal(Object.keys(h.tts_nghi).length, 3);
  assert.match(h.tts_nghi["gemini-3.8-flash-tts"], /^1[45] giờ 0[01] ngày /);
});

test("Đọc to: một mô hình hết lượt phút thì nghỉ riêng mô hình đó, nghỉ ngắn rồi dùng lại", async () => {
  const { env } = moiTruong();
  const goi = [];
  env.GEMINI = {
    fetch: async (_u, o) => {
      const m = JSON.parse(o.body).model;
      goi.push(m);
      return m === "gemini-3.8-flash-tts" ? bao429("phut", "20s") : amThanh();
    },
  };
  const r = await (await goiTts(env, { text: "Xin chào" })).json();
  assert.equal(r.ok, true);
  assert.equal(r.mo_hinh, "gemini-3.8-flash-lite-tts");
  const den = Number(env.DB.flags.get("tts_het:gemini-3.8-flash-tts"));
  assert.ok(den - Date.now() > 15000 && den - Date.now() <= 21000, "nghỉ khoảng 20 giây");
  // Lần sau bỏ qua mô hình đang nghỉ, gọi thẳng mô hình kế tiếp
  goi.length = 0;
  await goiTts(env, { text: "Câu thứ hai" });
  assert.deepEqual(goi, ["gemini-3.8-flash-lite-tts"]);
  // Hết giờ nghỉ thì dùng lại mô hình đầu
  env.DB.flags.set("tts_het:gemini-3.8-flash-tts", String(Date.now() - 1));
  goi.length = 0;
  await goiTts(env, { text: "Câu thứ ba" });
  assert.deepEqual(goi, ["gemini-3.8-flash-tts", "gemini-3.8-flash-lite-tts"]);
});

test("Đọc to: lời báo 429 không rõ loại thì nghỉ 60 giây, không khóa cả ngày", async () => {
  const { env } = moiTruong();
  env.GEMINI = { fetch: async () => new Response("{}", { status: 429 }) };
  const r = await goiTts(env, { text: "Xin chào" });
  assert.equal(r.status, 429);
  assert.match((await r.json()).message, /tạm hết lượt miễn phí, thầy cô thử lại sau ít phút/);
  const den = Number(env.DB.flags.get("tts_het:gemini-2.5-flash-preview-tts"));
  assert.ok(den - Date.now() > 50000 && den - Date.now() <= 61000);
});

test("Đọc to: lỗi khác (không phải hết lượt) thì không ghi nghỉ", async () => {
  const { env } = moiTruong();
  env.GEMINI = { fetch: async () => new Response("{}", { status: 500 }) };
  const r = await goiTts(env, { text: "Xin chào" });
  assert.equal(r.status, 502);
  assert.equal(env.DB.flags.size, 0);
});

test("Đọc to bằng Google Cloud khi có khóa, đếm ký tự theo ngày", async () => {
  const { env } = moiTruong();
  env.GOOGLE_TTS_KEY = "khoa-thu";
  const goi = [];
  globalThis.fetch = async (url, o) => {
    goi.push({ url: String(url), body: JSON.parse(o.body) });
    return new Response(JSON.stringify({ audioContent: "SUQz" }), { status: 200 });
  };
  const r = await (await goiTts(env, { text: "Kính gửi quý phụ huynh", rate: 1.2 })).json();
  assert.equal(r.ok, true);
  assert.equal(r.mime, "audio/mpeg");
  assert.match(goi[0].url, /texttospeech\.googleapis\.com.*key=khoa-thu/);
  assert.equal(goi[0].body.voice.languageCode, "vi-VN");
  const dai = "a".repeat(1000);
  let cuoi;
  for (let i = 0; i < 31; i++) cuoi = await goiTts(env, { text: dai });
  assert.equal(cuoi.status, 429);
  assert.equal((await goiTts(env, { text: "b".repeat(1001) })).status, 400);
});

test("Hỏi Trợ lý được dặn không dùng LaTeX", async () => {
  const { env, ghi } = moiTruong();
  await goi(env, { mode: "hoi", input: "Tính 5% + 2%" });
  assert.match(ghi.gemini[0].body.systemInstruction.parts[0].text, /Không dùng LaTeX/);
});

test("Câu hỏi về lương, phụ cấp, chế độ đi thẳng Claude", async () => {
  for (const q of ["Phụ cấp ưu đãi theo Nghị định 182/2026 là bao nhiêu?", "giao vien hang II he so bao nhieu", "Thông tư 93 ai được truy lĩnh?", "Nghỉ hưu sớm cần mấy năm đóng BHXH?"]) {
    const { env, ghi } = moiTruong();
    const r = await goi(env, { mode: "hoi", input: q });
    assert.equal(r.ok, true);
    assert.equal(r.by, "claude", q);
    assert.equal(ghi.gemini.length, 0, q);
  }
});

test("Câu hỏi tiếp nối của chuỗi về chế độ vẫn đi Claude", async () => {
  const { env, ghi } = moiTruong();
  const r = await goi(env, { mode: "hoi", input: "còn mầm non thì sao?", history: [{ q: "Phụ cấp ưu đãi tiểu học bao nhiêu?", a: "45%" }] });
  assert.equal(r.by, "claude");
  assert.equal(ghi.gemini.length, 0);
});

test("Câu hỏi thường vẫn dùng Gemini", async () => {
  const { env, ghi } = moiTruong();
  const r = await goi(env, { mode: "hoi", input: "Gợi ý trò chơi khởi động tiết Toán lớp 3" });
  assert.equal(r.by, "gemini");
  assert.equal(ghi.gemini.length, 1);
});

test("Thủ tục, tình huống nhạy cảm, Thông tư 22, pháp luật đi Claude", async () => {
  for (const q of ["Viết giúp đơn xin nghỉ phép", "Học sinh lớp 7 bị bạn bắt nạt, tôi nên làm gì?", "Thông tư 22 xếp loại học lực thế nào?", "Thủ tục sang tên sổ đỏ"]) {
    const { env, ghi } = moiTruong();
    const r = await goi(env, { mode: "hoi", input: q });
    assert.equal(r.by, "claude", q);
    assert.equal(ghi.gemini.length, 0, q);
  }
});

test("Hỏi Trợ lý qua Claude được nạp kiến thức nền, các chế độ khác thì không", async () => {
  const a = moiTruong();
  await goi(a.env, { mode: "hoi", input: "Phụ cấp ưu đãi tiểu học bao nhiêu?" });
  assert.match(a.ghi.claude[0].system, /Nghị định 182\/2026\/NĐ-CP/);
  assert.match(a.ghi.claude[0].system, /45%/);
  const b = moiTruong();
  await goi(b.env, { mode: "nhanxet", input: "HS01 chăm chỉ" });
  assert.doesNotMatch(b.ghi.claude[0].system, /KIẾN THỨC NỀN/);
});

test("Mục Tin: /tin trả danh sách clip của kênh", async () => {
  const { env } = moiTruong();
  const r = await worker.fetch(new Request("https://x/tin"), env, {});
  assert.equal(r.status, 200);
  const ds = await r.json();
  assert.ok(ds.length >= 5);
  assert.ok(ds.every((t) => t.id && t.ngay && t.tit && t.anh_bia));
});

test("Hỏi về kênh: máy chủ tự kèm danh sách clip, câu khác thì không", async () => {
  const a = moiTruong();
  await goi(a.env, { mode: "hoi", input: "cip trên việt nam tiêu điểm nào hay nhất" });
  const gui = a.ghi.gemini.length ? a.ghi.gemini[0].body.contents.at(-1).parts[0].text : JSON.stringify(a.ghi.claude[0].messages.at(-1));
  assert.match(gui, /Các clip gần đây/);
  assert.match(gui, /chọn hẳn một clip cụ thể/);
  const b = moiTruong();
  await goi(b.env, { mode: "hoi", input: "Phụ cấp thâm niên tính thế nào?" });
  assert.doesNotMatch(JSON.stringify(b.ghi.gemini[0] || b.ghi.claude[0] || {}), /Các clip gần đây/);
});

// Ảnh thật nhỏ của từng loại (1x1 điểm ảnh), mã hóa base64 như app gửi lên
const ANH = {
  png: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==",
  jpeg: "/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////wgALCAABAAEBAREA/8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPxA=",
  gif: "R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7",
  webp: "UklGRiIAAABXRUJQVlA4IBYAAAAwAQCdASoBAAEADsD+JaQAA3AAAAAA",
  heic: "AAAAGGZ0eXBoZWljAAAAAG1pZjFoZWljAAAA",
};

test("Ảnh gửi Claude được khai đúng loại: PNG là image/png, JPEG là image/jpeg, WebP, GIF", async () => {
  for (const [loai, mime] of [["png", "image/png"], ["jpeg", "image/jpeg"], ["gif", "image/gif"], ["webp", "image/webp"]]) {
    const { env, ghi } = moiTruong();
    const r = await goi(env, { mode: "hoi", input: "", images: [ANH[loai]] });
    assert.equal(r.ok, true, loai);
    const anh = ghi.claude[0].messages.at(-1).content.find((c) => c.type === "image");
    assert.equal(anh.source.media_type, mime, loai);
  }
});

test("Ảnh định dạng lạ (HEIC) bị từ chối ngay với lời báo rõ, không gọi AI, không trừ lượt", async () => {
  const { env, ghi } = moiTruong();
  const r = await goi(env, { mode: "hoi", input: "Đây là gì?", images: [ANH.heic] });
  assert.equal(r.ok, false);
  assert.equal(r.error, "anh_la");
  assert.match(r.message, /định dạng/);
  assert.equal(ghi.claude.length, 0);
});

function moiTruongClaudeLoi(status, loi) {
  const m = moiTruong();
  globalThis.fetch = async () => new Response(JSON.stringify({ type: "error", error: loi }), { status });
  return m;
}

test("Lỗi Claude báo đúng lý do, chỉ nói 'đang bận' khi dịch vụ bận thật", async () => {
  const ca = [
    [400, { type: "invalid_request_error", message: "messages.0.content.0.image.source.base64: Image does not match the provided media type image/jpeg" }, "tep_loi", /chưa đọc được ảnh/],
    [400, { type: "invalid_request_error", message: "Your credit balance is too low to access the Anthropic API." }, "het_han_muc", /hạn mức chi phí/],
    [401, { type: "authentication_error", message: "invalid x-api-key" }, "sai_khoa_ai", /cấu hình/],
    [413, { type: "request_too_large", message: "Request exceeds the maximum allowed number of bytes." }, "qua_lon", /lớn quá/],
    [529, { type: "overloaded_error", message: "Overloaded" }, "ai_ban", /đang bận/],
    [400, { type: "invalid_request_error", message: "something else" }, "loi_ai", /mã 400/],
  ];
  for (const [status, loi, ma, cau] of ca) {
    const { env } = moiTruongClaudeLoi(status, loi);
    const r = await goi(env, { mode: "hoi", input: "", images: [ANH.png] });
    assert.equal(r.ok, false);
    assert.equal(r.error, ma, loi.message);
    assert.match(r.message, cau, loi.message);
    if (ma !== "ai_ban") assert.doesNotMatch(r.message, /đang bận/, loi.message);
  }
});

test("Hết lượt: không mời xem quảng cáo khi app chưa có quảng cáo", async () => {
  const { env } = moiTruong();
  await env.DB.prepare("INSERT INTO counters").bind("d:" + new Date(Date.now() + 7 * 3600e3).toISOString().slice(0, 10) + ":giaide:kiemthu123", 10).first();
  const r = await goi(env, { mode: "giaide", input: "1+1=?" });
  assert.equal(r.error, "het_luot");
  assert.equal(r.message, "Hôm nay thầy cô đã dùng hết 10 lượt, mai dùng tiếp nhé.");
  assert.doesNotMatch(r.message, /quảng cáo/);
});

test("Biên bản chép chữ từ ảnh, PDF: đi Claude, đúng hướng dẫn chép nguyên văn", async () => {
  const { env, ghi } = moiTruong();
  const r = await goi(env, { mode: "chep_chu", input: "", images: [ANH.jpeg] });
  assert.equal(r.ok, true);
  assert.equal(ghi.gemini.length, 0);
  assert.match(ghi.claude[0].system, /chép lại chữ trong ảnh/i);
  const ndung = ghi.claude[0].messages.at(-1).content;
  assert.equal(ndung.find((c) => c.type === "text").text, "Chép lại chữ trong ảnh, tệp.");
  const b = moiTruong();
  const r2 = await goi(b.env, { mode: "chep_chu", input: "", pdfs: ["JVBERi0xLjQK"] });
  assert.equal(r2.ok, true);
  assert.equal(b.ghi.claude[0].messages.at(-1).content[0].type, "document");
});

test("Dịch tài liệu: chữ và ảnh đều đi Claude (không qua AI miễn phí), không ép trả lời tiếng Việt", async () => {
  const { env, ghi } = moiTruong();
  const r = await goi(env, { mode: "dich", input: "Dịch sang: Tiếng Anh. Kiểu: Sát nghĩa. Song ngữ: không.\n---\nXin chào thầy cô." });
  assert.equal(r.ok, true);
  assert.equal(ghi.gemini.length, 0);
  assert.equal(ghi.claude.length, 1);
  assert.match(ghi.claude[0].system, /^Bạn dịch tài liệu/);
  assert.doesNotMatch(ghi.claude[0].system, /trả lời bằng tiếng Việt/);
  const b = moiTruong();
  const r2 = await goi(b.env, { mode: "dich", input: "Dịch sang: Tiếng Việt. Kiểu: Dễ hiểu. Song ngữ: có.", images: [ANH.png] });
  assert.equal(r2.ok, true);
  assert.equal(b.ghi.claude[0].messages.at(-1).content.find((c) => c.type === "image").source.media_type, "image/png");
});

test("Dịch tài liệu: mỗi máy 20 trang mỗi ngày", async () => {
  const { env } = moiTruong();
  await env.DB.prepare("INSERT INTO counters").bind("d:" + new Date(Date.now() + 7 * 3600e3).toISOString().slice(0, 10) + ":dich:kiemthu123", 20).first();
  const r = await goi(env, { mode: "dich", input: "Dịch sang: Tiếng Anh. Kiểu: Sát nghĩa. Song ngữ: không.\n---\nChào." });
  assert.equal(r.error, "het_luot");
  assert.equal(r.message, "Hôm nay thầy cô đã dùng hết 20 lượt, mai dùng tiếp nhé.");
});
