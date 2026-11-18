// Máy chủ trung gian cho app "Trợ lý số Giáo viên" (Cloudflare Worker).
// - Giữ khóa API Claude (biến bí mật ANTHROPIC_API_KEY, đặt bằng lệnh `wrangler secret put`).
// - Đếm số câu của từng máy mỗi ngày (kho KV tên LUOT).
// - Nhận báo cáo nội dung AI (Google Play bắt buộc).

const MO_HINH = "claude-haiku-5-5";
const GIOI_HAN = { hoi: 5, nhan_xet: 30, tin_ph: 20, bien_ban: 10 }; // số lượt miễn phí mỗi ngày
const DO_DAI_TOI_DA = { hoi: 2000, nhan_xet: 4000, tin_ph: 1000, bien_ban: 12000 }; // ký tự mỗi lần gửi lên
const SO_CHU_TRA_LOI = { hoi: 800, nhan_xet: 2500, tin_ph: 600, bien_ban: 3000 }; // giới hạn độ dài câu trả lời

const LOI_DAN = {
  hoi:
    "Bạn là Trợ lý số Giáo viên, trả lời bằng tiếng Việt, ngắn gọn, dễ hiểu cho giáo viên Việt Nam. " +
    "Chỉ trả lời các việc của nghề giáo: chế độ, tiền lương, phụ cấp, Thông tư và quy định của ngành giáo dục, " +
    "cách viết văn bản hành chính trong nhà trường, phương pháp dạy học, đánh giá học sinh. " +
    "Với câu hỏi ngoài phạm vi đó, lịch sự từ chối trong một câu và mời hỏi việc của nghề giáo. " +
    "Không bàn chuyện chính trị, không đưa ý kiến cá nhân về chủ trương, chính sách. " +
    "Khi nêu quy định, ghi rõ số, ký hiệu văn bản và điều, khoản nếu biết chắc; không chắc thì nói rõ là cần đối chiếu văn bản gốc. " +
    "Không bịa số liệu, số văn bản.",
  nhan_xet:
    "Bạn giúp giáo viên Việt Nam viết lời nhận xét học sinh, theo Thông tư 27/2020/TT-BGDĐT (tiểu học) " +
    "hoặc Thông tư 22/2021/TT-BGDĐT (THCS, THPT) tùy thông tin được cung cấp. " +
    "Học sinh được gọi bằng mã, không có tên thật. Mỗi lời nhận xét 1 đến 2 câu, cụ thể, động viên, không lặp ý giữa các em. " +
    "Chỉ trả về lời nhận xét, mỗi em một dòng, bắt đầu bằng mã học sinh.",
  tin_ph:
    "Bạn giúp giáo viên chủ nhiệm Việt Nam soạn tin nhắn gửi phụ huynh: lịch sự, ngắn gọn, rõ việc, " +
    "xưng hô 'quý phụ huynh', ký 'GVCN'. Giữ nguyên các chỗ trống trong ngoặc vuông. Chỉ trả về nội dung tin nhắn.",
  bien_ban:
    "Bạn giúp thư ký cuộc họp trong nhà trường Việt Nam viết lại ghi chép thành phần nội dung biên bản. " +
    "Văn phong hành chính, khách quan, ngôi thứ ba, ghi đúng ý từng người phát biểu, không thêm ý không có trong ghi chép, " +
    "không bịa số liệu, tên người. Mỗi ý kiến một đoạn, mở đầu bằng người phát biểu nếu ghi chép có nêu. " +
    "Trả về đúng hai phần: dòng 'NỘI DUNG:' rồi các đoạn diễn biến; sau đó dòng 'KẾT LUẬN:' rồi các ý kết luận, " +
    "phân công, thời hạn (nếu ghi chép không có kết luận thì tóm tắt các việc đã thống nhất). Không dùng định dạng markdown.",
};

function json(obj, status = 200) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { "Content-Type": "application/json; charset=utf-8" },
  });
}

function ngayVN() {
  // Ngày theo giờ Việt Nam (UTC+7) để đặt lại lượt lúc 0 giờ.
  return new Date(Date.now() + 7 * 3600 * 1000).toISOString().slice(0, 10);
}

async function goiClaude(env, loai, noiDung) {
  const res = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "x-api-key": env.ANTHROPIC_API_KEY,
      "anthropic-version": "2023-06-01",
      "content-type": "application/json",
    },
    body: JSON.stringify({
      model: MO_HINH,
      max_tokens: SO_CHU_TRA_LOI[loai],
      system: LOI_DAN[loai],
      messages: [{ role: "user", content: noiDung }],
    }),
  });
  if (!res.ok) return null;
  const j = await res.json();
  return (j.content || []).filter((c) => c.type === "text").map((c) => c.text).join("\n").trim();
}

async function xuLyHoi(req, env) {
  let b;
  try {
    b = await req.json();
  } catch {
    return json({ loi: "Yêu cầu không hợp lệ." }, 400);
  }
  const may = String(b.may || "").slice(0, 64);
  const loai = LOI_DAN[b.loai] ? b.loai : "hoi";
  const noiDung = String(b.noi_dung || "").trim();
  if (!may || !noiDung) return json({ loi: "Thiếu nội dung." }, 400);
  if (noiDung.length > DO_DAI_TOI_DA[loai]) return json({ loi: "Câu hỏi quá dài, thầy cô rút gọn giúp." }, 400);

  const khoa = `luot:${ngayVN()}:${loai}:${may}`;
  const daDung = parseInt((await env.LUOT.get(khoa)) || "0", 10);
  const gioiHan = GIOI_HAN[loai];
  if (daDung >= gioiHan) {
    return json({ loi: "Thầy cô đã dùng hết lượt hôm nay. Ngày mai lượt sẽ được làm mới.", con_lai: 0 });
  }

  const traLoi = await goiClaude(env, loai, noiDung);
  if (!traLoi) {
    // Hết tiền tặng kèm hoặc lỗi phía AI: không trừ lượt.
    return json({ loi: "Trợ lý đang tạm nghỉ, thầy cô thử lại sau.", con_lai: gioiHan - daDung });
  }
  await env.LUOT.put(khoa, String(daDung + 1), { expirationTtl: 60 * 60 * 48 });
  return json({ tra_loi: traLoi, con_lai: gioiHan - daDung - 1 });
}

async function xuLyBaoCao(req, env) {
  let b;
  try {
    b = await req.json();
  } catch {
    return json({ loi: "Yêu cầu không hợp lệ." }, 400);
  }
  const khoa = `bao_cao:${new Date().toISOString()}:${String(b.may || "").slice(0, 16)}`;
  await env.LUOT.put(
    khoa,
    JSON.stringify({
      cau_hoi: String(b.cau_hoi || "").slice(0, 2000),
      tra_loi: String(b.tra_loi || "").slice(0, 4000),
      ly_do: String(b.ly_do || "").slice(0, 200),
    }),
    { expirationTtl: 60 * 60 * 24 * 90 }
  );
  return json({ ok: true });
}

export default {
  async fetch(req, env) {
    const url = new URL(req.url);
    if (req.method === "POST" && url.pathname === "/hoi") return xuLyHoi(req, env);
    if (req.method === "POST" && url.pathname === "/bao-cao") return xuLyBaoCao(req, env);
    return json({ ten: "Trợ lý số Giáo viên", trang_thai: "đang chạy" });
  },
};
