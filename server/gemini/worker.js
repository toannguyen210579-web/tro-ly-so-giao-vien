// Máy chủ phụ tro-ly-gv-gemini: chỉ chuyển yêu cầu sang Gemini API.
// Đặt chạy ở Mỹ vì Gemini không nhận yêu cầu từ máy chủ Cloudflare ở Hồng Kông (gần Việt Nam nhất).
// Không có đường dẫn công khai: chỉ máy chủ chính tro-ly-gv gọi được qua service binding.
export default {
  async fetch(request, env) {
    if (request.method !== "POST") return new Response("Chỉ nhận POST", { status: 405 });
    const { model, body } = await request.json();
    if (!/^[a-z0-9.\-]+$/.test(model || "")) return new Response("Sai tên mô hình", { status: 400 });
    let r;
    try {
      r = await fetch("https://generativelanguage.googleapis.com/v1beta/models/" + model + ":generateContent", {
        method: "POST",
        headers: { "content-type": "application/json", "x-goog-api-key": env.GEMINI_API_KEY },
        body: JSON.stringify(body),
        signal: AbortSignal.timeout(25000),
      });
    } catch (e) {
      return Response.json({ error: { status: "TIMEOUT_OR_NETWORK", message: String(e).slice(0, 100) } }, { status: 504 });
    }
    return new Response(r.body, { status: r.status, headers: { "content-type": "application/json" } });
  },
};
