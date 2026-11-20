// Kho văn bản quy phạm về giáo dục, lưu trong D1 (bảng kt_vb + bảng tìm kiếm toàn văn kt_fts).
// Nạp văn bản: POST /v1/kt/nap (khóa quản trị X-Kt-Key). Hỏi Trợ lý lấy các điều liên quan nhất đưa cho Claude.

// SHA-256 của khóa quản trị (khóa không nằm trong mã nguồn)
const KT_KEY_SHA = "18412831a6ff4fea50639207cf0f0ce7f2dec5556479e091067377844e5d0560";
const MAX_DOAN = 2400; // ký tự tối đa mỗi đoạn lưu
const MAX_LAY = 7000; // ký tự tối đa đưa vào câu hỏi (khoảng 2–3 trang)

const SCHEMA = [
  "CREATE TABLE IF NOT EXISTS kt_vb (so TEXT PRIMARY KEY, ten TEXT, ngay TEXT, hieu_luc TEXT, tinh_trang TEXT, nguon TEXT, cap_nhat TEXT, so_doan INTEGER)",
  "CREATE VIRTUAL TABLE IF NOT EXISTS kt_fts USING fts5(so UNINDEXED, tieu_de, noi_dung, tokenize = 'unicode61 remove_diacritics 2')",
];

export async function khoaDung(key) {
  if (!key) return false;
  const h = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(key));
  const hex = [...new Uint8Array(h)].map((b) => b.toString(16).padStart(2, "0")).join("");
  return hex === KT_KEY_SHA;
}

// Cắt văn bản thành từng điều; điều dài thì cắt tiếp theo khoản
export function chiaDieu(text) {
  const t = String(text).replace(/\r/g, "").replace(/[ \t]+\n/g, "\n").replace(/\n{2,}/g, "\n").trim();
  const parts = t.split(/\n(?=Điều \d+[a-zđ]?\.)/);
  const out = [];
  let chuong = "";
  for (const p of parts) {
    const m = p.match(/^(Điều \d+[a-zđ]?\.[^\n]*)/);
    const tieuDe = m ? m[1].trim() : "Phần mở đầu";
    const doan = [];
    let cur = "";
    for (const line of p.split("\n")) {
      if (cur && cur.length + line.length > MAX_DOAN && /^(\d+\.|[a-zđ]\))/.test(line)) {
        doan.push(cur);
        cur = tieuDe + " (tiếp)\n";
      }
      cur += (cur ? "\n" : "") + line;
    }
    if (cur) doan.push(cur);
    for (const d of doan) out.push({ tieu_de: (chuong ? chuong + " · " : "") + tieuDe, noi_dung: d.slice(0, MAX_DOAN + 600) });
    // Ghi nhớ chương đang đọc (dòng "Chương ..." nằm cuối điều trước)
    const ch = p.match(/\nChương [IVXLC\d]+[^\n]*\n([^\n]+)/g);
    if (ch) chuong = ch[ch.length - 1].replace(/\n/g, " ").trim();
  }
  return out;
}

export async function napVanBan(db, vb) {
  for (const s of SCHEMA) await db.prepare(s).run();
  const doan = chiaDieu(vb.text);
  const st = [
    db.prepare("DELETE FROM kt_fts WHERE so = ?").bind(vb.so),
    db.prepare("INSERT OR REPLACE INTO kt_vb (so, ten, ngay, hieu_luc, tinh_trang, nguon, cap_nhat, so_doan) VALUES (?, ?, ?, ?, ?, ?, ?, ?)")
      .bind(vb.so, vb.ten || "", vb.ngay || "", vb.hieu_luc || "", vb.tinh_trang || "", vb.nguon || "", vb.cap_nhat || "", doan.length),
    ...doan.map((d) => db.prepare("INSERT INTO kt_fts (so, tieu_de, noi_dung) VALUES (?, ?, ?)").bind(vb.so, d.tieu_de, d.noi_dung)),
  ];
  for (let i = 0; i < st.length; i += 50) await db.batch(st.slice(i, i + 50));
  return doan.length;
}

// Cụm hai tiếng quá phổ biến, không giúp tìm đúng điều
const BO_QUA = new Set(("giáo viên,thầy cô,học sinh,nhà trường,cho tôi,cho em,như thế,thế nào,bao nhiêu,có được,được không,quy định,theo quy,định của,hiện nay,hiện tại,năm học,là gì,có phải,phải không,xin hỏi,cho hỏi,hỏi về,mới nhất,trường hợp,của tôi,tôi là,em là,thì sao,có không,như nào,ra sao,làm sao,vậy ạ,không ạ,được bao")
  .split(","));
const BO_DAU = (s) => s.normalize("NFD").replace(/[̀-ͯ]/g, "").replace(/đ/g, "d");
const BO_QUA_KD = new Set([...BO_QUA].map(BO_DAU));

export function cauTimKiem(q) {
  const s = String(q).toLowerCase();
  const so = [...s.matchAll(/(\d{1,3})\s*\/\s*(\d{4})/g)].map((m) => `"${m[1]} ${m[2]}"`);
  const w = s.replace(/[^\p{L}\p{N}]+/gu, " ").trim().split(/\s+/).filter(Boolean);
  const cum = [];
  for (let i = 0; i + 1 < w.length; i++) {
    const c = w[i] + " " + w[i + 1];
    if (BO_QUA.has(c) || BO_QUA_KD.has(BO_DAU(c))) continue;
    if (/^\d+$/.test(w[i]) && /^\d+$/.test(w[i + 1])) continue;
    cum.push(`"${c}"`);
  }
  const all = [...new Set([...so, ...cum])].slice(0, 30);
  return all.join(" OR ");
}

// Lấy các điều liên quan nhất, trả về đoạn chữ để ghép vào lời dặn cho Claude ("" nếu không có)
export async function timKienThuc(db, q) {
  const m = cauTimKiem(q);
  if (!db || !m) return "";
  let rows;
  try {
    const r = await db
      .prepare(
        "SELECT kt_fts.so AS so, tieu_de, noi_dung, ten, hieu_luc, tinh_trang FROM kt_fts JOIN kt_vb ON kt_vb.so = kt_fts.so " +
          "WHERE kt_fts MATCH ? ORDER BY bm25(kt_fts, 0, 2, 1) LIMIT 8",
      )
      .bind(m)
      .all();
    rows = r.results || [];
  } catch {
    return ""; // chưa có bảng hoặc câu tìm lỗi: trả lời như cũ
  }
  let out = "";
  for (const x of rows) {
    const doan = `\n--- ${x.ten} (${x.so}; ${x.hieu_luc}; ${x.tinh_trang})\n${x.noi_dung}\n`;
    if (out.length + doan.length > MAX_LAY) continue;
    out += doan;
  }
  if (!out) return "";
  return (
    "\nTRÍCH VĂN BẢN GỐC LIÊN QUAN (lấy từ kho văn bản của app, ưu tiên dùng, trích dẫn đúng tên văn bản, điều, khoản; " +
    "nếu phần trích không đủ để trả lời thì nói rõ và không bịa):" + out
  );
}

export async function dsVanBan(db) {
  try {
    const r = await db.prepare("SELECT so, ten, ngay, hieu_luc, tinh_trang, nguon, cap_nhat, so_doan FROM kt_vb ORDER BY so").all();
    return r.results || [];
  } catch {
    return [];
  }
}

export async function xuatVanBan(db, so) {
  const r = await db.prepare("SELECT tieu_de, noi_dung FROM kt_fts WHERE so = ? ORDER BY rowid").bind(so).all();
  return (r.results || []).map((x) => x.noi_dung).join("\n");
}
