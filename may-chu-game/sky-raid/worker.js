// Máy chủ chơi online của Sky Raid (Phi Công Đột Kích), chạy trên Cloudflare Workers.
// - Board: bảng xếp hạng (điểm nhiệm vụ cộng dồn, điểm tuần, số máy bay bắn hạ khi đấu online), lưu SQLite.
// - Lobby: ghép trận nhanh (phòng công khai) và tạo phòng riêng có mã 4 ký tự.
// - Room: một phòng chơi, tối đa 6 người, nối bằng WebSocket; chỉ chuyển tiếp vị trí, phát bắn trúng, tính điểm, đếm giờ trận.
// Máy chủ không chạy mô phỏng bay: mỗi máy tự tính máy bay của mình; máy bay do máy điều khiển (bot) chạy trên máy chủ phòng (host).
// Không có chat.
import { DurableObject } from 'cloudflare:workers';

const HDR = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Methods': 'GET,POST,OPTIONS', 'Access-Control-Allow-Headers': 'Content-Type', 'Cache-Control': 'no-store' };
const json = (o, s = 200) => new Response(JSON.stringify(o), { status: s, headers: { ...HDR, 'Content-Type': 'application/json; charset=utf-8' } });
const CODE_RE = /^[A-Z0-9]{4,6}$/, PID_RE = /^[a-z0-9]{8,32}$/;
const MAX = 6, PVP_LEN = 180000, COOP_LEN = 480000, END_LEN = 12000, WAIT_PUB = 9000;
const BAD = ['fuck', 'shit', 'bitch', 'cunt', 'nigg', 'fag', 'nazi', 'hitler', 'porn', 'sex', 'dick', 'pussy', 'whore', 'slut', 'rape', 'dit', 'lon', 'cac', 'buoi', 'dcm', 'dmm', 'vcl', 'deo', 'dume'];

export function cleanName(s) {
  s = String(s || '').normalize('NFC').replace(/[^\p{L}\p{N} _.-]/gu, '').replace(/\s+/g, ' ').trim().slice(0, 16);
  if (s.length < 2) return '';
  const fold = s.normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/đ/gi, 'd').toLowerCase();
  const words = fold.split(/[^a-z0-9]+/).filter(Boolean), flat = words.join('');
  // short Vietnamese words are only blocked as whole words, longer ones anywhere
  if (BAD.some(b => b.length >= 4 ? flat.includes(b) : words.includes(b))) return '';
  return s;
}
export function weekKey(ms = Date.now()) {
  const d = new Date(ms); d.setUTCHours(0, 0, 0, 0); d.setUTCDate(d.getUTCDate() + 3 - ((d.getUTCDay() + 6) % 7));
  const y = d.getUTCFullYear(), w1 = new Date(Date.UTC(y, 0, 4));
  const w = 1 + Math.round(((d - w1) / 864e5 - 3 + ((w1.getUTCDay() + 6) % 7)) / 7);
  return y + '-W' + String(w).padStart(2, '0');
}

export default {
  async fetch(req, env) {
    const u = new URL(req.url), p = u.pathname;
    if (req.method === 'OPTIONS') return new Response(null, { status: 204, headers: HDR });
    if (p === '/health') return json({ ok: true, v: 1, week: weekKey() });
    if (p === '/score' || p === '/top') return env.BOARD.get(env.BOARD.idFromName('main')).fetch(req);
    if (p === '/quick' || p === '/create' || p === '/peek') return env.LOBBY.get(env.LOBBY.idFromName('main')).fetch(req);
    if (p === '/ws') {
      const code = (u.searchParams.get('room') || '').toUpperCase();
      if (!CODE_RE.test(code)) return json({ err: 'room' }, 400);
      if (req.headers.get('Upgrade') !== 'websocket') return json({ err: 'ws' }, 426);
      return env.ROOM.get(env.ROOM.idFromName(code)).fetch(req);
    }
    return env.ASSETS ? env.ASSETS.fetch(req) : json({ err: '404' }, 404);
  },
};

// ---------- bảng xếp hạng ----------
export class Board extends DurableObject {
  constructor(ctx, env) {
    super(ctx, env); this.sql = ctx.storage.sql; this.last = new Map();
    this.sql.exec(`CREATE TABLE IF NOT EXISTS best(pid TEXT PRIMARY KEY, name TEXT, pts INTEGER, mis INTEGER, t INTEGER);
      CREATE TABLE IF NOT EXISTS wk(w TEXT, pid TEXT, name TEXT, pts INTEGER, PRIMARY KEY(w, pid));
      CREATE TABLE IF NOT EXISTS pvp(w TEXT, pid TEXT, name TEXT, k INTEGER, win INTEGER, PRIMARY KEY(w, pid));
      CREATE INDEX IF NOT EXISTS best_pts ON best(pts DESC);
      CREATE INDEX IF NOT EXISTS wk_pts ON wk(w, pts DESC);
      CREATE INDEX IF NOT EXISTS pvp_k ON pvp(w, k DESC);`);
  }
  async fetch(req) {
    const u = new URL(req.url);
    if (u.pathname === '/score' && req.method === 'POST') return this.score(await req.json().catch(() => ({})));
    if (u.pathname === '/top') return this.top(u.searchParams);
    return json({ err: '404' }, 404);
  }
  score(b) {
    const pid = String(b.pid || ''); if (!PID_RE.test(pid)) return json({ err: 'pid' }, 400);
    const name = cleanName(b.name) || 'Pilot', mis = Math.max(1, Math.min(999, b.mission | 0));
    const gain = Math.max(0, Math.min(b.gain | 0, 600 + mis * 250));   // one mission can not be worth more than this
    const now = Date.now(); if (now - (this.last.get(pid) || 0) < 20000) return json({ err: 'slow' }, 429);
    this.last.set(pid, now); if (this.last.size > 5000) this.last.clear();
    const w = weekKey(now);
    this.sql.exec(`INSERT INTO best(pid, name, pts, mis, t) VALUES(?, ?, ?, ?, ?) ON CONFLICT(pid) DO UPDATE SET name = excluded.name, pts = pts + excluded.pts, mis = MAX(mis, excluded.mis), t = excluded.t`, pid, name, gain, mis, now);
    this.sql.exec(`INSERT INTO wk(w, pid, name, pts) VALUES(?, ?, ?, ?) ON CONFLICT(w, pid) DO UPDATE SET name = excluded.name, pts = pts + excluded.pts`, w, pid, name, gain);
    return json({ ok: true, gain, all: this.rank('all', pid, w), week: this.rank('week', pid, w) });
  }
  rank(b, pid, w) {
    const q = {
      all: ['SELECT pts AS v FROM best WHERE pid = ?', "SELECT COUNT(*) AS n FROM best WHERE pts > ? AND pid NOT LIKE 'zztest%'", []],
      week: ['SELECT pts AS v FROM wk WHERE w = ? AND pid = ?', "SELECT COUNT(*) AS n FROM wk WHERE w = ? AND pts > ? AND pid NOT LIKE 'zztest%'", [w]],
      pvp: ['SELECT k AS v FROM pvp WHERE w = ? AND pid = ?', "SELECT COUNT(*) AS n FROM pvp WHERE w = ? AND k > ? AND pid NOT LIKE 'zztest%'", [w]],
    }[b];
    const me = this.sql.exec(q[0], ...q[2], pid).toArray()[0];
    return me ? { v: me.v, r: this.sql.exec(q[1], ...q[2], me.v).one().n + 1 } : null;
  }
  top(qs) {
    const b = ['all', 'week', 'pvp'].includes(qs.get('b')) ? qs.get('b') : 'all', n = Math.min(100, Math.max(5, +qs.get('n') || 50)), pid = qs.get('pid') || '', w = weekKey();
    // rows written by the server self-test (pid "zztest...") are only shown to the self-test
    const hide = pid.startsWith('zztest') ? '' : " AND pid NOT LIKE 'zztest%'";
    const rows = b === 'all' ? this.sql.exec(`SELECT pid, name, pts AS v FROM best WHERE 1${hide} ORDER BY pts DESC LIMIT ?`, n).toArray()
      : b === 'week' ? this.sql.exec(`SELECT pid, name, pts AS v FROM wk WHERE w = ?${hide} ORDER BY pts DESC LIMIT ?`, w, n).toArray()
        : this.sql.exec(`SELECT pid, name, k AS v FROM pvp WHERE w = ?${hide} ORDER BY k DESC, win DESC LIMIT ?`, w, n).toArray();
    return json({ b, w, rows: rows.map(r => ({ n: r.name, v: r.v, me: r.pid === pid ? 1 : 0 })), me: PID_RE.test(pid) ? this.rank(b, pid, w) : null });
  }
  // called by a room at the end of each online match
  pvpResult(list) {
    const w = weekKey();
    for (const r of list || []) {
      if (!PID_RE.test(String(r.pid || ''))) continue;
      this.sql.exec(`INSERT INTO pvp(w, pid, name, k, win) VALUES(?, ?, ?, ?, ?) ON CONFLICT(w, pid) DO UPDATE SET name = excluded.name, k = k + excluded.k, win = win + excluded.win`,
        w, r.pid, cleanName(r.name) || 'Pilot', Math.max(0, Math.min(60, r.k | 0)), r.win ? 1 : 0);
    }
    return true;
  }
}

// ---------- sảnh: ghép trận, tạo phòng ----------
export class Lobby extends DurableObject {
  constructor(ctx, env) {
    super(ctx, env); this.rooms = new Map();
    ctx.blockConcurrencyWhile(async () => { const all = await ctx.storage.list({ prefix: 'r:' }); for (const [k, v] of all) this.rooms.set(k.slice(2), v); });
  }
  put(c, r) { this.rooms.set(c, r); return this.ctx.storage.put('r:' + c, r); }
  del(c) { this.rooms.delete(c); return this.ctx.storage.delete('r:' + c); }
  async gc() { const now = Date.now(); for (const [c, r] of this.rooms) if (now - r.t > (r.n > 0 ? 900000 : 120000)) await this.del(c); }
  code(prefix) {
    const A = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    for (;;) { let s = prefix; while (s.length < (prefix ? 5 : 4)) s += A[Math.floor(Math.random() * A.length)]; if (!this.rooms.has(s)) return s; }
  }
  async fetch(req) {
    const u = new URL(req.url), b = req.method === 'POST' ? await req.json().catch(() => ({})) : {};
    await this.gc();
    const now = Date.now();
    if (u.pathname === '/quick') {
      let best = null;
      for (const [c, r] of this.rooms) if (r.pub && r.n < MAX && (r.ph !== 'play' || r.end - now > 50000) && (!best || r.n > best[1].n)) best = [c, r];
      if (best) { best[1].n++; best[1].t = now; await this.put(best[0], best[1]); return json({ room: best[0], mode: 'pvp' }); }
      const c = this.code('Q'); await this.put(c, { pub: true, mode: 'pvp', n: 1, ph: 'wait', end: 0, t: now });
      return json({ room: c, mode: 'pvp' });
    }
    if (u.pathname === '/create') {
      const mode = b.mode === 'coop' ? 'coop' : 'pvp', c = this.code('');
      await this.put(c, { pub: false, mode, n: 0, ph: 'wait', end: 0, t: now });
      return json({ room: c, mode });
    }
    if (u.pathname === '/peek') { let p = 0; for (const r of this.rooms.values()) p += r.n; return json({ players: p, rooms: this.rooms.size }); }
    return json({ err: '404' }, 404);
  }
  info(c) { return this.rooms.get(c) || null; }
  async report(c, inf) {
    if (!inf || inf.n <= 0) { await this.del(c); return true; }
    await this.put(c, { ...(this.rooms.get(c) || { pub: false, mode: 'pvp' }), ...inf, t: Date.now() }); return true;
  }
}

// ---------- phòng chơi ----------
export class Room extends DurableObject {
  constructor(ctx, env) {
    super(ctx, env); this.st = null;
    ctx.blockConcurrencyWhile(async () => { this.st = (await ctx.storage.get('st')) || null; });
  }
  who(ws) { try { return ws.deserializeAttachment() || {}; } catch (e) { return {}; } }
  players(skip) {
    const m = new Map();   // readyState 2, 3: closing, closed
    for (const ws of this.ctx.getWebSockets()) { if (ws === skip || ws.readyState === 2 || ws.readyState === 3) continue; const a = this.who(ws); if (a.pid) m.set(a.pid, { ws, ...a }); }
    return m;
  }
  save() { return this.st ? this.ctx.storage.put('st', this.st) : null; }
  lobby() { return this.env.LOBBY.get(this.env.LOBBY.idFromName('main')); }
  pub() { const s = this.st; return { code: s.code, mode: s.mode, pubr: s.pub, ph: s.ph, end: s.end, startAt: s.startAt || 0, host: s.host, seed: s.seed, round: s.round, sc: s.sc, wave: s.wave || 0, team: s.team || 0, now: Date.now() }; }
  send(ws, o) { try { ws.send(JSON.stringify(o)); } catch (e) { } }
  bcast(o, skip) { const m = JSON.stringify(o); for (const ws of this.ctx.getWebSockets()) if (ws !== skip && ws.readyState !== 2 && ws.readyState !== 3) { try { ws.send(m); } catch (e) { } } }
  sendTo(pid, o) { for (const [k, p] of this.players()) if (k === pid) this.send(p.ws, o); }
  report(skip) { if (!this.st) return; const n = this.players(skip).size; this.ctx.waitUntil(this.lobby().report(this.st.code, { n, ph: this.st.ph, end: this.st.end, mode: this.st.mode, pub: this.st.pub }).catch(() => { })); }

  async fetch(req) {
    const u = new URL(req.url), q = u.searchParams, code = (q.get('room') || '').toUpperCase();
    const pid = q.get('pid') || '', name = cleanName(q.get('name')) || 'Pilot', jet = (q.get('jet') || 'falcon').replace(/[^a-z]/g, '').slice(0, 12) || 'falcon';
    if (!PID_RE.test(pid)) return json({ err: 'pid' }, 400);
    const [cli, srv] = Object.values(new WebSocketPair());
    this.ctx.acceptWebSocket(srv);
    const bye = (t, c) => { this.send(srv, { t }); try { srv.close(c, t); } catch (e) { } return new Response(null, { status: 101, webSocket: cli }); };
    if (!this.st) {
      // two players can arrive at the same moment: ask the lobby only once and let both wait for the same answer
      this.making = this.making || this.lobby().info(code).then(inf => {
        if (inf && !this.st) this.st = { code, mode: inf.mode, pub: !!inf.pub, ph: 'wait', end: 0, startAt: 0, host: '', sc: {}, round: 0, seed: (Math.random() * 1e6) | 0, wave: 0, team: 0 };
      }).finally(() => { this.making = null; });
      await this.making;
      if (!this.st) return bye('nf', 4004);
    }
    const pl = this.players(srv);
    const old = pl.get(pid); if (old) { try { old.ws.close(4001, 'replaced'); } catch (e) { } pl.delete(pid); }
    if (pl.size >= MAX) return bye('full', 4009);
    srv.serializeAttachment({ pid, name, jet });
    if (!this.st.host || !pl.has(this.st.host)) this.st.host = pid;
    this.st.sc[pid] = this.st.sc[pid] || { n: name, k: 0, d: 0 }; this.st.sc[pid].n = name;
    if (this.st.ph === 'wait' && this.st.pub && !this.st.startAt) { this.st.startAt = Date.now() + WAIT_PUB; await this.ctx.storage.setAlarm(this.st.startAt); }
    await this.save();
    this.send(srv, { t: 'hi', you: pid, ...this.pub(), list: [...pl.values()].map(p => ({ pid: p.pid, name: p.name, jet: p.jet })) });
    this.bcast({ t: 'join', pid, name, jet }, srv);
    this.report();
    return new Response(null, { status: 101, webSocket: cli });
  }

  async webSocketMessage(ws, raw) {
    if (typeof raw !== 'string' || raw.length > 6000 || !this.st) return;
    let m; try { m = JSON.parse(raw); } catch (e) { return; }
    const me = this.who(ws).pid; if (!me) return;
    const s = this.st;
    switch (m.t) {
      case 's': case 'b': case 'fx': m.f = me; this.bcast(m, ws); break;   // my plane, the bots (from the host), effects: pass on
      case 'hit': {   // m.to: a player id, or a bot id ("b...") that lives on the host
        const to = String(m.to || ''), d = Math.max(0, Math.min(200, +m.d || 0));
        if (!d || to === me) break;
        this.sendTo(to[0] === 'b' ? s.host : to, { t: 'hit', to, d, f: me, k: m.k === 'm' ? 'm' : 'g' });
        break;
      }
      case 'die': {   // m.id: who went down (the sender, or a bot when the sender is the host); m.by: who shot it down
        if (s.ph !== 'play') break;
        const id = String(m.id || me), by = String(m.by || '');
        if (id !== me && !(id[0] === 'b' && me === s.host)) break;
        if (id[0] !== 'b') { s.sc[id] = s.sc[id] || { n: 'Pilot', k: 0, d: 0 }; s.sc[id].d++; }
        if (by && by !== id && by[0] !== 'b' && s.sc[by]) s.sc[by].k++;
        if (s.mode === 'coop' && id[0] === 'b') s.team = (s.team || 0) + 1;
        this.bcast({ t: 'kill', id, by, sc: s.sc, team: s.team || 0 });
        await this.save(); break;
      }
      case 'start': if (me === s.host && s.ph === 'wait') await this.begin(); break;
      case 'wave': if (me === s.host) { s.wave = m.n | 0; this.bcast({ t: 'wave', n: s.wave }, ws); await this.save(); } break;
      case 'win': if (me === s.host && s.mode === 'coop' && s.ph === 'play') await this.finish(true); break;
      case 'ping': this.send(ws, { t: 'pong', c: m.c, now: Date.now() }); break;
    }
  }
  async begin() {
    const s = this.st, pl = this.players();
    for (const k of Object.keys(s.sc)) if (!pl.has(k)) delete s.sc[k];
    for (const k in s.sc) { s.sc[k].k = 0; s.sc[k].d = 0; }
    s.ph = 'play'; s.round++; s.team = 0; s.wave = 0; s.won = false; s.startAt = 0; s.seed = (Math.random() * 1e6) | 0;
    s.end = Date.now() + (s.mode === 'coop' ? COOP_LEN : PVP_LEN);
    await this.ctx.storage.setAlarm(s.end); await this.save();
    this.bcast({ t: 'go', ...this.pub() }); this.report();
  }
  async finish(won) {
    const s = this.st, pl = this.players();
    s.ph = 'end'; s.won = !!won;
    const list = Object.entries(s.sc).filter(([k]) => pl.has(k)).map(([pid, v]) => ({ pid, name: v.n, k: v.k, d: v.d }));
    list.sort((a, b) => b.k - a.k || a.d - b.d);
    if (s.mode === 'pvp' && list.length && list[0].k > 0) list[0].win = true;
    if (s.mode === 'coop' && won) list.forEach(r => r.win = true);
    this.bcast({ t: 'end', list, won: !!won, team: s.team || 0, next: Date.now() + END_LEN });
    try { await this.env.BOARD.get(this.env.BOARD.idFromName('main')).pvpResult(list.map(r => ({ pid: r.pid, name: r.name, k: r.k, win: !!r.win }))); } catch (e) { }
    await this.ctx.storage.setAlarm(Date.now() + END_LEN); await this.save(); this.report();
  }
  async alarm() {
    const s = this.st; if (!s) return;
    if (!this.players().size) { await this.ctx.storage.deleteAll(); this.st = null; return; }
    if (s.ph === 'wait') await this.begin();
    else if (s.ph === 'play') await this.finish(false);
    else if (s.pub) await this.begin();
    else { s.ph = 'wait'; s.startAt = 0; await this.save(); this.bcast({ t: 'lobby', ...this.pub() }); this.report(); }
  }
  async webSocketClose(ws, code) { try { ws.close(1000, 'bye'); } catch (e) { } await this.left(ws); }
  async webSocketError(ws) { await this.left(ws); }
  async left(ws) {
    const a = this.who(ws), s = this.st; if (!s || !a.pid) return;
    const pl = this.players(ws);
    if (pl.has(a.pid)) return;   // the same player is still here on a newer connection
    this.bcast({ t: 'left', pid: a.pid }, ws);
    if (!pl.size) { this.ctx.waitUntil(this.lobby().report(s.code, { n: 0 }).catch(() => { })); await this.ctx.storage.deleteAll(); this.st = null; return; }
    if (s.host === a.pid) { s.host = [...pl.keys()][0]; this.bcast({ t: 'host', pid: s.host }, ws); }
    await this.save(); this.report(ws);
  }
}
