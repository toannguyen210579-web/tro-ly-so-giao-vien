// Cổng tìm trên mạng và nhóm AI miễn phí (chốt 20/11/2026).
// - Tìm trên mạng: TinyFish, LangSearch, Exa, Tavily, You.com, Firecrawl (đăng ký không gắn thẻ nên không thể bị trừ tiền).
//   Chia lượt ngẫu nhiên cho các cổng, cổng nào hết lượt hay bận thì nghỉ một lúc và chuyển ngay sang cổng khác.
//   Kết quả tìm lưu lại 6 giờ: nhiều thầy cô hỏi cùng chuyện thì chỉ tìm một lần.
// - AI viết câu trả lời: Gemini trước (tiếng Việt tốt nhất), bận hoặc hết lượt thì sang Workers AI, Groq, Cerebras,
//   Mistral, Z.ai, Hugging Face, GitHub Models. Tất cả bận mới dùng Claude (trần chi tiêu 20 USD/tháng, chặn cứng).
// - Câu có thông tin cá nhân, câu về chế độ, quy chế không đi qua các AI miễn phí (worker.js quyết định).
// Dịch vụ nào chưa có khóa thì tự bỏ qua. Mọi lệnh gọi đi qua máy chủ phụ ở Mỹ (env.GEMINI) vì vài nơi chặn Hồng Kông.

// Cổng đang nghỉ (hết lượt, lỗi): tên -> thời điểm được dùng lại. Giữ trong bộ nhớ của máy chủ.
const NGHI = new Map();
const dangNghi = (ten) => (NGHI.get(ten) || 0) > Date.now();
const choNghi = (ten, giay) => NGHI.set(ten, Date.now() + giay * 1000);
/** Xóa trạng thái nghỉ (dùng khi kiểm thử). */
export const datLaiNghi = () => NGHI.clear();

function tronNgauNhien(a) {
  const b = [...a];
  for (let i = b.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [b[i], b[j]] = [b[j], b[i]];
  }
  return b;
}

// Gọi một dịch vụ bên ngoài qua máy chủ phụ ở Mỹ. Trả về { status, json }.
async function goiNgoai(env, url, { method = "POST", headers = {}, data, timeout = 20000 } = {}) {
  const r = await env.GEMINI.fetch("https://gemini/", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ url, method, headers: { "content-type": "application/json", ...headers }, data, timeout }),
  });
  let j = null;
  try { j = await r.json(); } catch {}
  return { status: r.status, json: j };
}

const cat = (s, n) => String(s || "").replace(/\s+/g, " ").trim().slice(0, n);

// ---------- Tìm trên mạng ----------
export const CONG_TIM = [
  {
    ten: "tinyfish", khoa: "TINYFISH_API_KEY",
    async tim(env, q) {
      const u = "https://api.search.tinyfish.ai/?" + new URLSearchParams({ query: q, location: "VN", language: "vi" });
      const r = await goiNgoai(env, u, { method: "GET", headers: { "X-API-Key": env.TINYFISH_API_KEY } });
      return { status: r.status, kq: ((r.json || {}).results || []).map((x) => ({ tit: x.title, url: x.url, tom: x.snippet })) };
    },
  },
  {
    ten: "langsearch", khoa: "LANGSEARCH_API_KEY",
    async tim(env, q) {
      const r = await goiNgoai(env, "https://api.langsearch.com/v1/web-search", {
        headers: { Authorization: "Bearer " + env.LANGSEARCH_API_KEY }, data: { query: q, count: 6 },
      });
      const v = ((((r.json || {}).data || {}).webPages || {}).value) || [];
      return { status: r.status, kq: v.map((x) => ({ tit: x.name, url: x.url, tom: x.snippet || x.text })) };
    },
  },
  {
    ten: "exa", khoa: "EXA_API_KEY",
    async tim(env, q) {
      const r = await goiNgoai(env, "https://api.exa.ai/search", {
        headers: { "x-api-key": env.EXA_API_KEY }, data: { query: q, numResults: 6, contents: { text: { maxCharacters: 600 } } },
      });
      return { status: r.status, kq: ((r.json || {}).results || []).map((x) => ({ tit: x.title, url: x.url, tom: x.text || (x.highlights || []).join(" ") })) };
    },
  },
  {
    ten: "tavily", khoa: "TAVILY_API_KEY",
    async tim(env, q) {
      const r = await goiNgoai(env, "https://api.tavily.com/search", {
        headers: { Authorization: "Bearer " + env.TAVILY_API_KEY }, data: { query: q, max_results: 6, search_depth: "basic" },
      });
      return { status: r.status, kq: ((r.json || {}).results || []).map((x) => ({ tit: x.title, url: x.url, tom: x.content })) };
    },
  },
  {
    ten: "you", khoa: "YOU_API_KEY",
    async tim(env, q) {
      const r = await goiNgoai(env, "https://ydc-index.io/v1/search", {
        headers: { "X-API-Key": env.YOU_API_KEY }, data: { query: q, count: 6, country: "VN" },
      });
      const web = (((r.json || {}).results || {}).web) || [];
      return { status: r.status, kq: web.map((x) => ({ tit: x.title, url: x.url, tom: x.description || (x.snippets || []).join(" ") })) };
    },
  },
  {
    ten: "firecrawl", khoa: "FIRECRAWL_API_KEY",
    async tim(env, q) {
      const r = await goiNgoai(env, "https://api.firecrawl.dev/v2/search", {
        headers: { Authorization: "Bearer " + env.FIRECRAWL_API_KEY }, data: { query: q, limit: 6 },
      });
      const d = (r.json || {}).data;
      const ds = Array.isArray(d) ? d : ((d || {}).web || []);
      return { status: r.status, kq: ds.map((x) => ({ tit: x.title, url: x.url, tom: x.description || x.markdown })) };
    },
  },
];

// Câu hỏi cần thông tin mới thì mới tìm (đỡ tốn lượt): giá cả, tin tức, lịch, văn bản mới, địa chỉ trang web...
const CAN_TIM = new RegExp(
  [
    "hôm nay", "hom nay", "hiện nay", "hien nay", "hiện tại", "mới nhất", "moi nhat", "mới đây", "gần đây", "vừa ban hành", "vừa có",
    "tuần này", "tháng này", "năm nay", "năm sau", "sắp tới", "202[5-9]", "giá ", "gia vang", "giá vàng", "tỷ giá", "ty gia", "thời tiết", "thoi tiet",
    "lịch nghỉ", "lich nghi", "nghỉ tết", "nghi tet", "lịch thi", "lich thi", "điểm chuẩn", "diem chuan", "tin tức", "tin tuc", "tin mới",
    "kết quả", "bao giờ", "khi nào", "đã có chưa", "ban hành", "công văn mới", "thông báo mới", "dự thảo", "du thao",
    "ở đâu", "địa chỉ", "trang web", "website", "đường dẫn", "link", "tra cứu ở", "tải ở", "mua ở",
  ].join("|"),
  "i",
);
export const canTim = (q) => CAN_TIM.test(q);

function chuanCau(q) {
  return q.toLowerCase().normalize("NFC").replace(/[^\p{L}\p{N} ]/gu, " ").replace(/\s+/g, " ").trim().slice(0, 300);
}

/** Tìm trên mạng qua các cổng miễn phí. Trả về { kq: [{tit,url,tom}], cong } hoặc null khi không tìm được. */
export async function timTrenMang(env, cau, caches = globalThis.caches) {
  const q = cat(cau, 300);
  const khoaLuu = "https://luu.tro-ly-gv/tim?q=" + encodeURIComponent(chuanCau(q));
  const kho = caches && caches.default;
  if (kho) {
    try {
      const daCo = await kho.match(khoaLuu);
      if (daCo) return { ...(await daCo.json()), luu: true };
    } catch {}
  }
  const ds = tronNgauNhien(CONG_TIM.filter((c) => env[c.khoa] && !dangNghi(c.ten)));
  for (const c of ds) {
    let r;
    try {
      r = await c.tim(env, q);
    } catch {
      choNghi(c.ten, 60);
      continue;
    }
    if (r.status === 429 || r.status === 402 || r.status === 403) { choNghi(c.ten, 30 * 60); continue; } // hết lượt
    if (r.status === 401) { choNghi(c.ten, 6 * 3600); continue; } // sai khóa
    if (r.status !== 200) { choNghi(c.ten, 60); continue; }
    const kq = (r.kq || []).filter((x) => x.url && x.tit).slice(0, 5).map((x) => ({ tit: cat(x.tit, 150), url: x.url, tom: cat(x.tom, 500) }));
    if (!kq.length) continue;
    const ra = { kq, cong: c.ten };
    if (kho) {
      try {
        await kho.put(khoaLuu, new Response(JSON.stringify(ra), { headers: { "cache-control": "max-age=21600", "content-type": "application/json" } }));
      } catch {}
    }
    return ra;
  }
  return null;
}

/** Ghép kết quả tìm vào câu hỏi để AI đọc và viết câu trả lời có nguồn. */
export function kemKetQua(input, tim, gio) {
  if (!tim || !tim.kq.length) return input;
  const ds = tim.kq.map((x, i) => "[" + (i + 1) + "] " + x.tit + "\n" + x.url + "\n" + x.tom).join("\n\n");
  return input + "\n\n(Kết quả tìm trên mạng lúc " + gio + ", dùng để trả lời, không nhắc lại phần này nguyên văn: " +
    "dựa vào các kết quả dưới đây để trả lời đúng câu hỏi, có số liệu, ngày tháng cụ thể; " +
    "nguồn nào không đáng tin hoặc không khớp câu hỏi thì bỏ qua; kết quả mâu thuẫn thì nói rõ. " +
    "Cuối câu trả lời ghi dòng \"Nguồn:\" rồi liệt kê 1–3 đường dẫn đã dùng, mỗi đường dẫn một dòng, ghi đầy đủ https://.\n\n" +
    ds + ")";
}

// ---------- AI miễn phí viết câu trả lời ----------
// Các mô hình xếp theo thứ tự thử; tên sai hoặc bị bỏ thì tự thử tên kế tiếp.
export const AI_MIEN_PHI = [
  { ten: "workersai", ai: true, mo: ["@cf/openai/gpt-oss-120b", "@cf/meta/llama-3.3-70b-instruct-fp8-fast"] },
  { ten: "groq", khoa: "GROQ_API_KEY", url: "https://api.groq.com/openai/v1/chat/completions", mo: ["openai/gpt-oss-120b", "llama-3.3-70b-versatile"] },
  { ten: "cerebras", khoa: "CEREBRAS_API_KEY", url: "https://api.cerebras.ai/v1/chat/completions", mo: ["gpt-oss-120b", "llama-3.3-70b"] },
  { ten: "mistral", khoa: "MISTRAL_API_KEY", url: "https://api.mistral.ai/v1/chat/completions", mo: ["mistral-medium-latest", "mistral-small-latest"] },
  { ten: "zai", khoa: "ZAI_API_KEY", url: "https://api.z.ai/api/paas/v4/chat/completions", mo: ["glm-4.7-flash", "glm-4.5-flash"] },
  { ten: "huggingface", khoa: "HF_TOKEN", url: "https://router.huggingface.co/v1/chat/completions", mo: ["openai/gpt-oss-120b", "Qwen/Qwen3-235B-A22B-Instruct-2507"] },
  { ten: "github", khoa: "GH_MODELS_TOKEN", url: "https://models.github.ai/inference/chat/completions", mo: ["openai/gpt-4.1-mini", "openai/gpt-4o-mini"] },
];

function tinNhan(system, input, hist) {
  return [
    { role: "system", content: system },
    ...hist.flatMap((t) => [{ role: "user", content: t.q }, { role: "assistant", content: t.a }]),
    { role: "user", content: input },
  ];
}

// Bỏ phần "suy nghĩ" một số mô hình in ra
const sach = (t) => String(t || "").replace(/<think>[\s\S]*?<\/think>/g, "").trim();

async function goiMot(env, d, model, messages, maxOut) {
  if (d.ai) {
    const r = await env.AI.run(model, { messages, max_tokens: maxOut });
    const text = sach(r.response || (((r.choices || [])[0] || {}).message || {}).content);
    return text ? { text } : { status: "rong" };
  }
  const r = await goiNgoai(env, d.url, {
    headers: { Authorization: "Bearer " + env[d.khoa] },
    data: { model, messages, max_tokens: maxOut, temperature: 0.4 },
    timeout: 30000,
  });
  if (r.status !== 200) return { status: r.status };
  const text = sach((((r.json || {}).choices || [])[0] || {}).message?.content);
  return text ? { text, usage: (r.json || {}).usage } : { status: "rong" };
}

/** Thử lần lượt các AI miễn phí (ngẫu nhiên để chia tải). Trả về { text, by } hoặc { err, status }. */
export async function vietMienPhi(env, system, input, hist, maxOut) {
  const ds = tronNgauNhien(AI_MIEN_PHI.filter((d) => (d.ai ? env.AI : env[d.khoa]) && !dangNghi(d.ten)));
  const messages = tinNhan(system, input, hist);
  let cuoi = "khong_co";
  for (const d of ds) {
    for (const model of d.mo) {
      let r;
      try {
        r = await goiMot(env, d, model, messages, maxOut);
      } catch {
        r = { status: "loi" };
      }
      if (r.text) return { text: r.text, by: d.ten, usage: { input_tokens: r.usage?.prompt_tokens, output_tokens: r.usage?.completion_tokens } };
      cuoi = d.ten + ":" + r.status;
      if (r.status === 404 || r.status === 400) continue; // tên mô hình không còn: thử tên kế
      break;
    }
    choNghi(d.ten, /:(429|402)$/.test(cuoi) ? 30 * 60 : /:401$/.test(cuoi) ? 6 * 3600 : 60);
  }
  return { err: "loi_ai", status: cuoi };
}
