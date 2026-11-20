// Máy GitHub tự nạp kho văn bản sau mỗi lần triển khai. Khóa lấy từ secret KT_KEY_CI, không in ra.
// Nạp toàn bộ: máy chủ xóa bản cũ theo số hiệu rồi nạp lại, không bị trùng.
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const BASE = process.env.KT_BASE || "https://tro-ly-gv.toannguyen210579.workers.dev";
const KEY = process.env.KT_KEY;
if (!KEY) { console.log("Chưa có secret KT_KEY_CI, bỏ qua nạp kho."); process.exit(0); }
const dir = dirname(fileURLToPath(import.meta.url));
const ds = JSON.parse(readFileSync(join(dir, "ds.json"), "utf8"));
let loi = 0;
for (const { file, so, ten } of ds) {
  const text = readFileSync(join(dir, file), "utf8");
  const r = await fetch(`${BASE}/v1/kt/nap`, {
    method: "POST",
    headers: { "Content-Type": "application/json", "X-Kt-Key": KEY },
    body: JSON.stringify({ so, ten, nguon: file, text }),
  });
  console.log(file, "->", r.status);
  if (!r.ok) { loi++; console.log((await r.text()).slice(0, 200)); }
}
const r = await fetch(`${BASE}/v1/kt/ds`, { headers: { "X-Kt-Key": KEY } });
const j = await r.json();
console.log("Trên máy chủ có", j.ds?.length, "văn bản");
if (loi) process.exit(1);
