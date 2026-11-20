// Máy chủ phụ tro-ly-gv-gemini: chỉ chuyển yêu cầu sang Gemini API.
// Đặt chạy ở Mỹ vì Gemini không nhận yêu cầu từ máy chủ Cloudflare ở Hồng Kông (gần Việt Nam nhất).
// Không có đường dẫn công khai: chỉ máy chủ chính tro-ly-gv gọi được qua service binding.
const CHO_PHEP = [
  "api.search.tinyfish.ai", "api.langsearch.com", "api.exa.ai", "api.tavily.com", "ydc-index.io", "api.firecrawl.dev",
  "api.groq.com", "api.cerebras.ai", "api.mistral.ai", "api.z.ai", "router.huggingface.co", "models.github.ai",
];

export default {
  async fetch(request, env) {
    if (request.method !== "POST") return new Response("Chỉ nhận POST", { status: 405 });
    const yc = await request.json();
    const { model, body, timeout } = yc;
    // Chuyển tiếp tới các dịch vụ AI, tìm kiếm miễn phí khác (cũng cần đi từ Mỹ). Chỉ các máy chủ trong danh sách.
    if (yc.url) {
      let dich;
      try { dich = new URL(yc.url); } catch { return new Response("Sai địa chỉ", { status: 400 }); }
      if (dich.protocol !== "https:" || !CHO_PHEP.includes(dich.hostname)) return new Response("Địa chỉ không được phép", { status: 400 });
      const msx = Math.min(40000, Math.max(3000, Number(timeout) || 20000));
      try {
        const r = await fetch(dich.toString(), {
          method: yc.method || "POST",
          headers: yc.headers || {},
          body: yc.method === "GET" ? undefined : yc.data === undefined ? undefined : JSON.stringify(yc.data),
          signal: AbortSignal.timeout(msx),
        });
        return new Response(r.body, { status: r.status, headers: { "content-type": r.headers.get("content-type") || "application/json" } });
      } catch (e) {
        return Response.json({ error: { status: "TIMEOUT_OR_NETWORK", message: String(e).slice(0, 100) } }, { status: 504 });
      }
    }
    // Đọc thành tiếng cần lâu hơn trả lời chữ; tối đa 40 giây
    const ms = Math.min(40000, Math.max(5000, Number(timeout) || 15000));
    if (!/^[a-z0-9.\-]+$/.test(model || "")) return new Response("Sai tên mô hình", { status: 400 });
    let r;
    try {
      r = await fetch("https://generativelanguage.googleapis.com/v1beta/models/" + model + ":generateContent", {
        method: "POST",
        headers: { "content-type": "application/json", "x-goog-api-key": env.GEMINI_API_KEY },
        body: JSON.stringify(body),
        signal: AbortSignal.timeout(ms),
      });
    } catch (e) {
      return Response.json({ error: { status: "TIMEOUT_OR_NETWORK", message: String(e).slice(0, 100) } }, { status: 504 });
    }
    return new Response(r.body, { status: r.status, headers: { "content-type": "application/json" } });
  },
};
