// Kiểm thử máy chủ không cần mạng: giả lập D1, Gemini, Claude.  Chạy: node --test server/test
import test from "node:test";
import assert from "node:assert/strict";
import worker from "../worker.js";

function giaD1() {
  const c = new Map();
  return {
    prepare(sql) {
      return {
        bind(...a) {
          return {
            async first() {
              if (sql.startsWith("SELECT n")) return c.has(a[0]) ? { n: c.get(a[0]) } : null;
              if (sql.startsWith("INSERT INTO counters")) { c.set(a[0], (c.get(a[0]) || 0) + a[1]); return { n: c.get(a[0]) }; }
              return null;
            },
            async run() {},
          };
        },
      };
    },
  };
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
  assert.equal(goi[0].model, "gemini-3.1-flash-tts-preview");
  assert.equal(goi[1].model, "gemini-3.8-flash-tts");
  assert.deepEqual(goi[0].body.generationConfig.responseModalities, ["AUDIO"]);
  assert.equal(goi[0].body.contents[0].parts[0].text, "Kính gửi quý phụ huynh");
});

test("Đọc to bằng Gemini: mọi mô hình hết lượt thì báo dễ hiểu", async () => {
  const { env } = moiTruong();
  env.GEMINI = { fetch: async () => new Response("{}", { status: 429 }) };
  const r = await goiTts(env, { text: "Xin chào" });
  assert.equal(r.status, 429);
  assert.match((await r.json()).message, /tạm hết lượt miễn phí/);
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
