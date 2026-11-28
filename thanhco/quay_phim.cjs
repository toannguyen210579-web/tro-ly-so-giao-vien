// Quay phim 36 giây của Gióng Phá Thành trên máy dựng (Chrome không màn hình, WebGL bằng SwiftShader).
// Cách dùng: node quay_phim.cjs <thư mục bản dựng WebGL> <thư mục ra>
// Trang mở với ?phim=quay: Unity khóa 24 khung/giây theo thời gian game, mỗi khung gọi GPT.chupKhung(i),
// trang gửi ảnh JPEG về máy chủ này (POST /khung?i=n). Xong thì ghép bằng ffmpeg thành phim.mp4.
const http = require('http');
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');
const { chromium } = require('playwright-core');

const goc = path.resolve(process.argv[2]);
const ra = path.resolve(process.argv[3] || 'phim');
const khungDir = path.join(ra, 'khung');
fs.mkdirSync(khungDir, { recursive: true });
const ghi = [];
function log(s) { const d = new Date().toISOString().slice(11, 19) + ' ' + s; ghi.push(d); console.log(d); }

const KIEU = { '.html': 'text/html; charset=utf-8', '.js': 'application/javascript', '.css': 'text/css', '.wasm': 'application/wasm',
  '.data': 'application/octet-stream', '.png': 'image/png', '.jpg': 'image/jpeg', '.json': 'application/json', '.unityweb': 'application/octet-stream' };
let soKhung = 0, lanCuoi = Date.now();
const may = http.createServer((req, res) => {
  const u = new URL(req.url, 'http://x');
  if (req.method === 'POST' && u.pathname === '/khung') {
    const i = parseInt(u.searchParams.get('i') || '0', 10);
    const phan = [];
    req.on('data', (c) => phan.push(c));
    req.on('end', () => {
      const s = Buffer.concat(phan).toString('latin1');
      const k = s.indexOf(',');
      fs.writeFileSync(path.join(khungDir, String(i).padStart(5, '0') + '.jpg'), Buffer.from(s.slice(k + 1), 'base64'));
      soKhung++; lanCuoi = Date.now();
      res.end('ok');
    });
    return;
  }
  let p = decodeURIComponent(u.pathname);
  if (p.endsWith('/')) p += 'index.html';
  const f = path.join(goc, p);
  if (!f.startsWith(goc) || !fs.existsSync(f) || fs.statSync(f).isDirectory()) { res.statusCode = 404; res.end(); return; }
  const h = {};
  let ten = f;
  if (ten.endsWith('.gz')) { h['Content-Encoding'] = 'gzip'; ten = ten.slice(0, -3); }
  else if (ten.endsWith('.br')) { h['Content-Encoding'] = 'br'; ten = ten.slice(0, -3); }
  h['Content-Type'] = KIEU[path.extname(ten)] || 'application/octet-stream';
  res.writeHead(200, h);
  fs.createReadStream(f).pipe(res);
});

(async () => {
  await new Promise((r) => may.listen(8123, r));
  const trinh = await chromium.launch({
    executablePath: process.env.CHROME || '/usr/bin/google-chrome',
    args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--enable-webgl',
      '--disable-background-timer-throttling', '--disable-renderer-backgrounding', '--autoplay-policy=no-user-gesture-required'],
  });
  const trang = await trinh.newPage({ viewport: { width: 1280, height: 720 } });
  trang.on('console', (m) => { if (ghi.length < 4000) log('[' + m.type() + '] ' + m.text().slice(0, 400)); });
  trang.on('pageerror', (e) => log('[pageerror] ' + String(e).slice(0, 400)));
  await trang.goto('http://127.0.0.1:8123/index.html?phim=quay', { timeout: 300000 });
  const batDau = Date.now();
  let anh = 0, xong = false;
  while (Date.now() - batDau < 130 * 60000) {
    await new Promise((r) => setTimeout(r, 20000));
    const tt = await trang.evaluate(() => ({ xong: !!(window.GPT && window.GPT.phimXong), k: (window.GPT && window.GPT.soKhung) || 0,
      tai: (document.getElementById('tai-pt') || {}).textContent || '' })).catch(() => ({ xong: false, k: -1, tai: '?' }));
    log('khung ' + tt.k + ' / nhan ' + soKhung + ' / tai ' + tt.tai);
    if (anh < 12 && (Date.now() - batDau) > anh * 4 * 60000) {
      await trang.screenshot({ path: path.join(ra, 'man-' + String(anh).padStart(2, '0') + '.jpg'), quality: 80, type: 'jpeg' }).catch(() => {});
      anh++;
    }
    if (tt.xong) { xong = true; break; }
    if (soKhung > 0 && Date.now() - lanCuoi > 15 * 60000) { log('qua 15 phut khong co khung moi, dung'); break; }
  }
  await new Promise((r) => setTimeout(r, 5000));
  await trang.screenshot({ path: path.join(ra, 'man-cuoi.jpg'), quality: 80, type: 'jpeg' }).catch(() => {});
  await trinh.close();
  may.close();
  // đánh số lại liên tục rồi ghép
  const ds = fs.readdirSync(khungDir).filter((f) => f.endsWith('.jpg')).sort();
  log('xong=' + xong + ', so khung ' + ds.length);
  const tam = path.join(ra, 'tam');
  fs.mkdirSync(tam, { recursive: true });
  ds.forEach((f, i) => fs.renameSync(path.join(khungDir, f), path.join(tam, String(i).padStart(5, '0') + '.jpg')));
  [0.15, 0.35, 0.6, 0.85].forEach((t, j) => {
    const i = Math.floor(ds.length * t);
    if (ds.length) fs.copyFileSync(path.join(tam, String(i).padStart(5, '0') + '.jpg'), path.join(ra, 'anh-' + (j + 1) + '.jpg'));
  });
  if (ds.length > 24) {
    try {
      execFileSync('ffmpeg', ['-y', '-loglevel', 'error', '-framerate', '24', '-i', path.join(tam, '%05d.jpg'),
        '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '23', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', path.join(ra, 'phim.mp4')]);
      log('da ghep phim.mp4 ' + fs.statSync(path.join(ra, 'phim.mp4')).size + ' byte');
    } catch (e) { log('loi ffmpeg: ' + e.message); }
  }
  fs.rmSync(tam, { recursive: true, force: true });
  fs.rmSync(khungDir, { recursive: true, force: true });
  fs.writeFileSync(path.join(ra, 'bang_ghi.txt'), ghi.join('\n') + '\n');
})().catch((e) => { log('loi: ' + (e.stack || e)); fs.writeFileSync(path.join(ra, 'bang_ghi.txt'), ghi.join('\n') + '\n'); process.exit(0); });
