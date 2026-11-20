// Kiểm thử kho văn bản bằng SQLite thật của Node (có FTS5) giả làm D1.  Chạy: node --test server/test/*.test.mjs
import test from "node:test";
import assert from "node:assert/strict";
import { DatabaseSync } from "node:sqlite";
import { chiaDieu, cauTimKiem, napVanBan, timKienThuc, khoaDung } from "../kien_thuc_db.js";
import worker from "../worker.js";
import { readFileSync } from "node:fs";

function d1() {
  const s = new DatabaseSync(":memory:");
  s.exec(readFileSync(new URL("../schema.sql", import.meta.url), "utf8"));
  const stmt = (sql, a = []) => ({
    bind: (...b) => stmt(sql, b),
    async run() { s.prepare(sql).run(...a); return {}; },
    async all() { return { results: s.prepare(sql).all(...a) }; },
    async first() { return s.prepare(sql).get(...a) || null; },
    _sql: sql, _a: a,
  });
  return { prepare: (sql) => stmt(sql), async batch(list) { for (const x of list) await x.run(); return []; } };
}

const TT05 = `Điều 1. Phạm vi điều chỉnh
Thông tư này quy định chế độ làm việc đối với giáo viên phổ thông.
Chương II
NHIỆM VỤ, THỜI GIAN LÀM VIỆC
Điều 7. Định mức tiết dạy đối với giáo viên
1. Định mức tiết dạy là tổng số tiết giảng dạy trực tiếp của mỗi giáo viên phải thực hiện trong 01 năm học.
3. Định mức tiết dạy trung bình trong 01 tuần
a) Giáo viên trường tiểu học là 23 tiết, giáo viên trường trung học cơ sở là 19 tiết, giáo viên trường trung học phổ thông là 17 tiết;
Điều 12. Giảm định mức tiết dạy đối với giáo viên nữ có con nhỏ
Giáo viên nữ nuôi con nhỏ dưới 12 tháng tuổi được giảm 03 tiết/tuần.`;

test("Cắt văn bản theo điều, giữ tên chương", () => {
  const d = chiaDieu(TT05);
  assert.equal(d.length, 3);
  assert.match(d[1].tieu_de, /Chương II.*Điều 7\. Định mức/);
  assert.match(d[1].noi_dung, /19 tiết/);
});

test("Câu tìm kiếm bỏ cụm phổ biến, giữ số hiệu", () => {
  const q = cauTimKiem("Cho tôi hỏi giáo viên THCS dạy bao nhiêu tiết theo Thông tư 05/2025?");
  assert.match(q, /"05 2025"/);
  assert.doesNotMatch(q, /"giáo viên"/);
  assert.match(q, /"bao nhiêu tiết"|"thcs dạy"/);
});

test("Nạp văn bản rồi tìm đúng điều, gõ không dấu cũng tìm được", async () => {
  const db = d1();
  const n = await napVanBan(db, { so: "05/2025/TT-BGDĐT", ten: "Thông tư 05/2025/TT-BGDĐT", hieu_luc: "hiệu lực 22/4/2025", tinh_trang: "đang hiệu lực", text: TT05 });
  assert.equal(n, 3);
  const a = await timKienThuc(db, "định mức tiết dạy giáo viên trung học cơ sở");
  assert.match(a, /19 tiết/);
  assert.match(a, /05\/2025\/TT-BGDĐT/);
  const b = await timKienThuc(db, "giao vien nu nuoi con nho duoc giam may tiet");
  assert.match(b, /03 tiết\/tuần/);
  // nạp lại không bị trùng
  await napVanBan(db, { so: "05/2025/TT-BGDĐT", ten: "x", text: TT05 });
  const c = await timKienThuc(db, "định mức tiết dạy");
  assert.equal((c.match(/Điều 7\./g) || []).length, 1);
  assert.equal(await timKienThuc(db, "thời tiết hôm nay đẹp"), "");
});

test("Chưa có kho thì trả rỗng, không lỗi", async () => {
  assert.equal(await timKienThuc(d1(), "định mức tiết dạy"), "");
});

test("Khóa quản trị: sai khóa bị từ chối", async () => {
  assert.equal(await khoaDung("sai"), false);
  const r = await worker.fetch(new Request("https://x/v1/kt/ds", { headers: { "X-Kt-Key": "sai" } }), { DB: d1() }, {});
  assert.equal(r.status, 403);
});

test("Hỏi Trợ lý về định mức tiết dạy: Claude nhận điều văn bản gốc", async () => {
  const db = d1();
  await napVanBan(db, { so: "05/2025/TT-BGDĐT", ten: "Thông tư 05/2025/TT-BGDĐT", hieu_luc: "22/4/2025", tinh_trang: "đang hiệu lực", text: TT05 });
  const goiClaude = [];
  globalThis.fetch = async (url, o) => {
    goiClaude.push(JSON.parse(o.body));
    return new Response(JSON.stringify({ content: [{ type: "text", text: "ok" }], usage: {} }), { status: 200 });
  };
  const r = await worker.fetch(new Request("https://x/v1/ai", { method: "POST", body: JSON.stringify({ device_id: "kiemthu123", mode: "hoi", input: "Định mức tiết dạy giáo viên THCS là bao nhiêu?" }) }),
    { DB: db, ANTHROPIC_API: "k" }, {}).then((x) => x.json());
  assert.equal(r.ok, true);
  assert.match(goiClaude[0].system, /TRÍCH VĂN BẢN GỐC[\s\S]*19 tiết/);
});
