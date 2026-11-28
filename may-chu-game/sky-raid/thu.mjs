// Thử máy chủ Sky Raid online: node thu.mjs [địa chỉ]   (mặc định http://127.0.0.1:8787)
// In từng mục ĐẠT/LỖI; thoát mã 1 nếu có lỗi.
const BASE = process.argv[2] || 'http://127.0.0.1:8787';
const WSB = BASE.replace(/^http/, 'ws');
let bad = 0;
const ok = (c, m) => { console.log((c ? 'ĐẠT ' : 'LỖI ') + m); if (!c) bad++; };
const J = async (p, b) => { const r = await fetch(BASE + p, b ? { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(b) } : {}); return { s: r.status, j: await r.json().catch(() => null) }; };
// mã người chơi thử bắt đầu bằng zztest: máy chủ không đưa vào bảng xếp hạng thật
const rid = () => 'zztest' + Math.random().toString(36).slice(2, 12) + Math.random().toString(36).slice(2, 6);
const sleep = ms => new Promise(r => setTimeout(r, ms));

function conn(room, pid, name, jet = 'viper') {
  const ws = new WebSocket(`${WSB}/ws?room=${room}&pid=${pid}&name=${encodeURIComponent(name)}&jet=${jet}`);
  const box = [], waits = [];
  ws.onmessage = e => { const m = JSON.parse(e.data); box.push(m); for (let i = waits.length - 1; i >= 0; i--) if (waits[i].f(m)) { waits[i].r(m); waits.splice(i, 1); } };
  const c = {
    ws, box, send: o => ws.send(JSON.stringify(o)),
    wait: (f, ms = 4000) => { const hit = box.find(f); if (hit) return Promise.resolve(hit); return new Promise((r, j) => { waits.push({ f, r }); setTimeout(() => r(null), ms); }); },
    open: new Promise(r => { ws.onopen = () => r(true); ws.onerror = () => r(false); }),
  };
  return c;
}

(async () => {
  const h = await J('/health'); ok(h.s === 200 && h.j.ok, 'health ' + JSON.stringify(h.j));
  // ---- bảng xếp hạng ----
  const a = rid(), b = rid();
  let r = await J('/score', { pid: a, name: 'Anh Toàn', mission: 3, gain: 900 }); ok(r.s === 200 && r.j.all && r.j.all.v === 900, 'gửi điểm 900 ' + JSON.stringify(r.j));
  r = await J('/score', { pid: a, name: 'Anh Toàn', mission: 3, gain: 900 }); ok(r.s === 429, 'gửi lại ngay bị chặn 20 giây');
  r = await J('/score', { pid: b, name: 'Kẻ gian', mission: 1, gain: 999999 }); ok(r.s === 200 && r.j.gain === 850, 'điểm gian bị cắt còn 850: ' + r.j.gain);
  r = await J('/score', { pid: 'BAD!', name: 'x', mission: 1, gain: 5 }); ok(r.s === 400, 'mã người chơi sai bị từ chối');
  r = await J('/top?b=all&pid=' + a); ok(r.s === 200 && r.j.rows.length >= 2 && r.j.me && r.j.me.r >= 1, 'bảng mọi lúc ' + JSON.stringify(r.j.rows.slice(0, 3)) + ' tôi ' + JSON.stringify(r.j.me));
  r = await J('/top?b=week&pid=' + a); ok(r.s === 200 && r.j.rows.some(x => x.me), 'bảng tuần có tôi');
  const c = rid(); r = await J('/score', { pid: c, name: 'fuck you', mission: 1, gain: 10 }); r = await J('/top?b=all&n=100&pid=' + c); ok(r.j.rows.find(x => x.me).n === 'Pilot', 'tên tục bị thay bằng Pilot');
  // ---- phòng riêng, chơi cùng phe ----
  r = await J('/create', { mode: 'coop' }); const code = r.j.room; ok(/^[A-Z0-9]{4}$/.test(code) && r.j.mode === 'coop', 'tạo phòng ' + code);
  const p1 = conn(code, a, 'Anh Toàn', 'falcon'), p2 = conn(code, b, 'Bạn 2', 'viper');
  ok(await p1.open && await p2.open, 'hai người nối được');
  let m = await p1.wait(x => x.t === 'hi'); ok(m && m.host === a && m.mode === 'coop' && m.ph === 'wait', 'người 1 là chủ phòng');
  m = await p1.wait(x => x.t === 'join' && x.pid === b); ok(!!m, 'người 1 thấy người 2 vào');
  m = await p2.wait(x => x.t === 'hi'); ok(m && m.list.length === 1 && m.list[0].pid === a, 'người 2 thấy danh sách có người 1');
  p2.send({ t: 'start' }); await sleep(300); ok(!p1.box.some(x => x.t === 'go'), 'người không phải chủ phòng không bắt đầu được');
  p1.send({ t: 'start' }); m = await p2.wait(x => x.t === 'go'); ok(m && m.ph === 'play' && m.end > Date.now(), 'chủ phòng bắt đầu trận');
  p1.send({ t: 's', p: [1, 2, 3], v: [0, 0, 50], a: [0, 0, 0], h: 100 }); m = await p2.wait(x => x.t === 's'); ok(m && m.f === a && m.p[2] === 3, 'vị trí người 1 tới người 2');
  p1.send({ t: 'b', l: [['b1', 0, 100, 0, 0, 0, 1, 0, 1]] }); m = await p2.wait(x => x.t === 'b'); ok(!!m, 'máy bay máy (bot) từ chủ phòng tới người 2');
  p2.send({ t: 'hit', to: 'b1', d: 9 }); m = await p1.wait(x => x.t === 'hit' && x.to === 'b1'); ok(m && m.f === b && m.d === 9, 'người 2 bắn trúng bot, chủ phòng nhận');
  p1.send({ t: 'die', id: 'b1', by: b }); m = await p2.wait(x => x.t === 'kill' && x.id === 'b1'); ok(m && m.sc[b].k === 1 && m.team === 1, 'bot rơi, người 2 được tính 1 lần hạ');
  p2.send({ t: 'die', id: 'b2', by: b }); await sleep(300); ok(!p1.box.some(x => x.t === 'kill' && x.id === 'b2'), 'người thường không tự báo bot rơi được');
  p1.send({ t: 'win' }); m = await p2.wait(x => x.t === 'end'); ok(m && m.won && m.list.length === 2, 'thắng trận cùng phe ' + JSON.stringify(m && m.list));
  p1.ws.close(); m = await p2.wait(x => x.t === 'host'); ok(m && m.pid === b, 'chủ phòng rời, người 2 thành chủ phòng');
  p2.ws.close();
  // ---- ghép trận nhanh, bắn nhau ----
  const q1 = await J('/quick', {}), q2 = await J('/quick', {}); ok(q1.j.room && q1.j.room === q2.j.room, 'ghép nhanh hai lần vào cùng phòng ' + q1.j.room);
  const x = rid(), y = rid(), k1 = conn(q1.j.room, x, 'Át chủ'), k2 = conn(q1.j.room, y, 'Đối thủ');
  await k1.open; await k2.open;
  m = await k1.wait(z => z.t === 'hi'); ok(m && m.mode === 'pvp' && m.startAt > Date.now(), 'phòng công khai tự đếm giờ bắt đầu');
  m = await k2.wait(z => z.t === 'go', 15000); ok(!!m, 'trận tự bắt đầu sau khoảng 9 giây');
  k1.send({ t: 'hit', to: y, d: 30, k: 'm' }); m = await k2.wait(z => z.t === 'hit'); ok(m && m.f === x && m.d === 30 && m.k === 'm', 'tên lửa người 1 trúng người 2');
  k2.send({ t: 'die', by: x }); m = await k1.wait(z => z.t === 'kill'); ok(m && m.sc[x].k === 1 && m.sc[y].d === 1, 'người 2 rơi: người 1 được 1 hạ');
  k1.send({ t: 'ping', c: 7 }); m = await k1.wait(z => z.t === 'pong'); ok(m && m.c === 7, 'ping');
  // a 7th player can not join a full room
  const extra = []; for (let i = 0; i < 4; i++) { const e = conn(q1.j.room, rid(), 'Phụ ' + i); await e.open; extra.push(e); }
  const full = conn(q1.j.room, rid(), 'Thứ bảy'); await full.open; m = await full.wait(z => z.t === 'full'); ok(!!m, 'phòng 6 người thì người thứ 7 bị báo đầy');
  [k1, k2, ...extra, full].forEach(e => { try { e.ws.close(); } catch (er) { } });
  r = await J('/peek'); ok(r.s === 200, 'đếm người đang chơi ' + JSON.stringify(r.j));
  const nf = conn('ZZZZ', rid(), 'Lạc'); await nf.open; m = await nf.wait(z => z.t === 'nf'); ok(!!m, 'mã phòng không có thì báo không tìm thấy');
  try { nf.ws.close(); } catch (e) { }
  console.log(bad ? `CÓ ${bad} LỖI` : 'TẤT CẢ ĐẠT');
  process.exit(bad ? 1 : 0);
})().catch(e => { console.log('LỖI chạy thử', e); process.exit(1); });
