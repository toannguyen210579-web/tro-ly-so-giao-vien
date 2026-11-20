// Thử thật từng cổng tìm kiếm, từng AI miễn phí bằng khóa trong GitHub Secrets (chạy trên máy GitHub ở Mỹ).
// In ra: cổng nào chạy, mất bao lâu, AI nào viết tiếng Việt ra sao, tên mô hình nào còn dùng được.
import { CONG_TIM, AI_MIEN_PHI } from "./mien_phi.js";

const env = { ...process.env };
// Giả máy chủ phụ: gọi thẳng dịch vụ
env.GEMINI = {
  async fetch(_u, o) {
    const b = JSON.parse(o.body);
    const r = await fetch(b.url, { method: b.method, headers: b.headers, body: b.method === "GET" ? undefined : JSON.stringify(b.data), signal: AbortSignal.timeout(30000) });
    return new Response(await r.text(), { status: r.status });
  },
};

const CAU_TIM = "lịch nghỉ Tết Nguyên đán 2027 của giáo viên";
for (const c of CONG_TIM) {
  if (!env[c.khoa]) { console.log(`TIM ${c.ten}: chưa có khóa ${c.khoa}`); continue; }
  const t = Date.now();
  try {
    const r = await c.tim(env, CAU_TIM);
    console.log(`TIM ${c.ten}: mã ${r.status}, ${r.kq?.length || 0} kết quả, ${Date.now() - t} ms | ${(r.kq || []).slice(0, 2).map((x) => x.tit + " " + x.url).join(" | ")}${r.status !== 200 ? " | báo lỗi: " + JSON.stringify(r.json || "").slice(0, 200) : ""}`);
  } catch (e) { console.log(`TIM ${c.ten}: LỖI ${e}`); }
}

const HOI = [
  { role: "system", content: "Bạn là trợ lý cho giáo viên Việt Nam. Trả lời bằng tiếng Việt có dấu, ngắn gọn, đúng chính tả." },
  { role: "user", content: "Gợi ý 3 cách giúp học sinh lớp 6 nhớ bảng cửu chương lâu hơn." },
];
for (const d of AI_MIEN_PHI) {
  if (d.ai) continue;
  if (!env[d.khoa]) { console.log(`AI ${d.ten}: chưa có khóa ${d.khoa}`); continue; }
  try {
    const m = await fetch(d.url.replace(/chat\/completions$/, "models"), { headers: { Authorization: "Bearer " + env[d.khoa] } });
    const ds = m.ok ? ((await m.json()).data || []).map((x) => x.id) : [];
    console.log(`AI ${d.ten}: các mô hình (${ds.length}): ${ds.slice(0, 40).join(", ")}`);
  } catch {}
  for (const model of d.mo) {
    const t = Date.now();
    const r = await fetch(d.url, { method: "POST", headers: { Authorization: "Bearer " + env[d.khoa], "content-type": "application/json" }, body: JSON.stringify({ model, messages: HOI, max_tokens: 600, ...(d.them || {}) }) });
    const tho = await r.text();
    let j = {};
    try { j = JSON.parse(tho); } catch {}
    const txt = j.choices?.[0]?.message?.content || tho.slice(0, 300);
    console.log(`AI ${d.ten} ${model}: mã ${r.status}, ${Date.now() - t} ms\n   ${txt.replace(/\s+/g, " ").slice(0, 400)}`);
  }
}
// lần chạy: 1795161229
// lần chạy: 2026-11-20T08:16:48Z đủ khóa You, TinyFish, Z.ai, GitHub Models
// lần chạy: 2026-11-20T08:18:52Z Z.ai tắt suy nghĩ, in lỗi
// lần chạy: 2026-11-20T08:55:16Z dán lại khóa TinyFish, You
