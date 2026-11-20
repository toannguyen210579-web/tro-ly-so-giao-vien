// Kiểm thử cổng tìm trên mạng và nhóm AI miễn phí (giả lập, không gọi dịch vụ thật)
import test from "node:test";
import assert from "node:assert/strict";
import worker from "../worker.js";
import { datLaiNghi, locKetQua } from "../mien_phi.js";

test.beforeEach(() => datLaiNghi());

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
            async all() { return { results: [] }; },
          };
        },
      };
    },
  };
}

// Máy chủ phụ giả: Gemini (có trường model) và các dịch vụ khác (có trường url)
function moiTruong({ gemini = 200, dv = {}, khoa = [] } = {}) {
  const ghi = { gemini: [], ngoai: [], claude: [] };
  globalThis.fetch = async (url, o) => {
    ghi.claude.push(JSON.parse(o.body));
    return new Response(JSON.stringify({ content: [{ type: "text", text: "Claude trả lời" }], usage: {} }), { status: 200 });
  };
  const env = {
    DB: giaD1(),
    ANTHROPIC_API: "k",
    GEMINI: {
      async fetch(_u, o) {
        const b = JSON.parse(o.body);
        if (b.url) {
          ghi.ngoai.push(b);
          const host = new URL(b.url).hostname;
          const [st, js] = dv[host] || [500, {}];
          return new Response(JSON.stringify(js), { status: st });
        }
        ghi.gemini.push(b);
        if (gemini !== 200) return new Response("{}", { status: gemini });
        return new Response(JSON.stringify({ candidates: [{ content: { parts: [{ text: "Gemini trả lời" }] } }] }), { status: 200 });
      },
    },
  };
  for (const k of khoa) env[k] = "khoa-" + k;
  return { env, ghi };
}

const goi = (env, body) =>
  worker.fetch(new Request("https://x/v1/ai", { method: "POST", body: JSON.stringify({ device_id: "kiemthu" + Math.random().toString(36).slice(2, 10), ...body }) }), env, {}).then((r) => r.json());

const TAVILY = { "api.tavily.com": [200, { results: [{ title: "Giá vàng SJC hôm nay", url: "https://vnexpress.net/gia-vang", content: "Vàng miếng SJC 150 triệu đồng/lượng" }] }] };

test("Câu cần tin mới: tìm trên mạng rồi đưa kết quả cho Gemini, có nguồn", async () => {
  const { env, ghi } = moiTruong({ dv: TAVILY, khoa: ["TAVILY_API_KEY"] });
  const r = await goi(env, { mode: "hoi", input: "giá vàng hôm nay bao nhiêu" });
  assert.equal(r.ok, true);
  assert.equal(r.by, "gemini");
  assert.equal(r.tim, "tavily");
  const gui = ghi.gemini[0].body.contents.at(-1).parts.at(-1).text;
  assert.match(gui, /Kết quả tìm trên mạng/);
  assert.match(gui, /https:\/\/vnexpress\.net\/gia-vang/);
  assert.match(gui, /Nguồn:/);
  assert.equal(ghi.ngoai[0].headers.Authorization, "Bearer khoa-TAVILY_API_KEY");
});

test("Câu thường không tìm, không tốn lượt tìm", async () => {
  const { env, ghi } = moiTruong({ dv: TAVILY, khoa: ["TAVILY_API_KEY"] });
  const r = await goi(env, { mode: "hoi", input: "Viết giúp tôi lời chào đầu giờ học" });
  assert.equal(r.ok, true);
  assert.equal(ghi.ngoai.length, 0);
  assert.equal(r.tim, undefined);
});

test("Cổng tìm hết lượt thì chuyển sang cổng khác", async () => {
  const dv = { ...TAVILY, "api.exa.ai": [429, { error: "het" }] };
  for (let i = 0; i < 4; i++) {
    const { env } = moiTruong({ dv, khoa: ["TAVILY_API_KEY", "EXA_API_KEY"] });
    const r = await goi(env, { mode: "hoi", input: "lịch nghỉ tết 2027 của giáo viên " + i });
    assert.equal(r.tim, "tavily");
  }
});

test("Không cổng tìm nào chạy được thì vẫn trả lời bình thường", async () => {
  const { env } = moiTruong({ dv: { "api.tavily.com": [500, {}] }, khoa: ["TAVILY_API_KEY"] });
  const r = await goi(env, { mode: "hoi", input: "tỷ giá đô la hôm nay" });
  assert.equal(r.ok, true);
  assert.equal(r.tim, undefined);
});

test("Gemini hết lượt: AI miễn phí khác viết thay, chưa tốn Claude", async () => {
  const groq = { "api.groq.com": [200, { choices: [{ message: { content: "Groq trả lời" } }], usage: { prompt_tokens: 10, completion_tokens: 5 } }] };
  const { env, ghi } = moiTruong({ gemini: 429, dv: groq, khoa: ["GROQ_API_KEY"] });
  const r = await goi(env, { mode: "hoi", input: "Cách dạy phép chia cho lớp 3" });
  assert.equal(r.by, "groq");
  assert.equal(r.text, "Groq trả lời");
  assert.equal(ghi.claude.length, 0);
  assert.equal(ghi.ngoai[0].data.messages[0].role, "system");
});

test("Tên mô hình không còn (404) thì thử tên kế tiếp", async () => {
  let lan = 0;
  const { env, ghi } = moiTruong({ gemini: 503, khoa: ["CEREBRAS_API_KEY"] });
  const goc = env.GEMINI.fetch;
  env.GEMINI.fetch = async (u, o) => {
    const b = JSON.parse(o.body);
    if (b.url) {
      ghi.ngoai.push(b);
      lan++;
      return lan === 1 ? new Response("{}", { status: 404 }) : new Response(JSON.stringify({ choices: [{ message: { content: "<think>x</think>Cerebras trả lời" } }] }), { status: 200 });
    }
    return goc(u, o);
  };
  const r = await goi(env, { mode: "hoi", input: "Gợi ý trò chơi khởi động" });
  assert.equal(r.by, "cerebras");
  assert.equal(r.text, "Cerebras trả lời");
  assert.notEqual(ghi.ngoai[0].data.model, ghi.ngoai[1].data.model);
});

test("Workers AI của Cloudflare viết thay khi Gemini bận", async () => {
  const { env } = moiTruong({ gemini: 429 });
  env.AI = { run: async (m, x) => ({ response: "Workers AI trả lời " + x.messages.length }) };
  const r = await goi(env, { mode: "hoi", input: "Bài thơ về mùa thu" });
  assert.equal(r.by, "workersai");
});

test("Mọi AI miễn phí đều bận thì Claude trả lời", async () => {
  const { env, ghi } = moiTruong({ gemini: 429, dv: { "api.groq.com": [429, {}] }, khoa: ["GROQ_API_KEY"] });
  const r = await goi(env, { mode: "hoi", input: "Kể chuyện cười ngắn" });
  assert.equal(r.by, "claude");
  assert.equal(ghi.claude.length, 1);
});

test("Câu riêng tư không đi qua AI miễn phí nhưng vẫn được tìm trên mạng", async () => {
  const groq = { "api.groq.com": [200, { choices: [{ message: { content: "Groq" } }] }], ...TAVILY };
  const { env, ghi } = moiTruong({ dv: groq, khoa: ["GROQ_API_KEY", "TAVILY_API_KEY"] });
  const r = await goi(env, { mode: "hoi", input: "HS01 hỏi lịch nghỉ tết năm nay", private: true });
  assert.equal(r.by, "claude");
  assert.equal(ghi.gemini.length, 0);
  assert.ok(ghi.ngoai.every((x) => !x.url.includes("groq")));
  assert.match(JSON.stringify(ghi.claude[0].messages.at(-1)), /vnexpress/);
});

test("Kết quả tìm được lưu lại, câu trùng không tìm lần hai", async () => {
  const kho = new Map();
  globalThis.caches = { default: { match: async (k) => kho.get(k)?.clone(), put: async (k, v) => kho.set(k, v) } };
  try {
    const { env, ghi } = moiTruong({ dv: TAVILY, khoa: ["TAVILY_API_KEY"] });
    await goi(env, { mode: "hoi", input: "Giá vàng hôm nay?" });
    await goi(env, { mode: "hoi", input: "giá vàng hôm nay" });
    assert.equal(ghi.ngoai.length, 1);
  } finally {
    delete globalThis.caches;
  }
});

test("Lọc kết quả: bỏ kết quả tiếng Hindi, Trung; đưa tiếng Việt, trang .vn lên đầu", () => {
  const kq = locKetQua([
    { tit: "सरकारी कर्मचारियों के लिए 2027 की छुट्टियों का कैलेंडर", url: "https://hindi.example.in/a", tom: "छुट्टियों" },
    { tit: "2027年春节放假安排", url: "https://cn.example.com/b", tom: "春节" },
    { tit: "Vietnam Tet holiday 2027", url: "https://en.example.com/c", tom: "Seven days off" },
    { tit: "Lịch nghỉ Tết 2027 của giáo viên", url: "https://baomoi.com/d", tom: "Giáo viên nghỉ 7 ngày" },
    { tit: "Tết Nguyên đán 2027: nghỉ 7 ngày", url: "https://nhandan.vn/e", tom: "Công chức, viên chức" },
    { tit: "Không có đường dẫn", url: "", tom: "x" },
  ]);
  assert.deepEqual(kq.map((x) => x.url), ["https://nhandan.vn/e", "https://baomoi.com/d", "https://en.example.com/c"]);
});
