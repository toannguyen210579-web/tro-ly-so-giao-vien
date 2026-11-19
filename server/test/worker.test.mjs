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
  const hist = [{ q: "Phụ cấp thâm niên là gì?", a: "Là khoản..." }, { q: "Tính thế nào?", a: "Lấy 5%..." }];
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

test("Đọc to qua máy chủ: chưa có khóa thì báo chưa bật, không gọi Google", async () => {
  const { env } = moiTruong();
  const r = await goiTts(env, { text: "Xin chào" });
  assert.equal(r.status, 503);
  assert.equal((await r.json()).error, "chua_bat");
});

test("Đọc to qua máy chủ: gọi Google đúng giọng tiếng Việt, đếm ký tự theo ngày", async () => {
  const { env } = moiTruong();
  env.GOOGLE_TTS_KEY = "khoa-thu";
  const goi = [];
  globalThis.fetch = async (url, o) => {
    goi.push({ url: String(url), body: JSON.parse(o.body) });
    return new Response(JSON.stringify({ audioContent: "SUQz" }), { status: 200 });
  };
  const r = await (await goiTts(env, { text: "Kính gửi quý phụ huynh", rate: 1.2 })).json();
  assert.equal(r.ok, true);
  assert.equal(r.audio, "SUQz");
  assert.match(goi[0].url, /texttospeech\.googleapis\.com.*key=khoa-thu/);
  assert.equal(goi[0].body.voice.languageCode, "vi-VN");
  assert.equal(goi[0].body.audioConfig.speakingRate, 1.2);
  // Vượt trần ngày thì dừng
  const dai = "a".repeat(2000);
  let cuoi;
  for (let i = 0; i < 16; i++) cuoi = await goiTts(env, { text: dai });
  assert.equal(cuoi.status, 429);
  assert.equal((await goiTts(env, { text: "b".repeat(2001) })).status, 400);
});
