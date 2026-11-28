# Máy chủ chơi online của Sky Raid

Cloudflare Worker `sky-raid-online` (https://sky-raid-online.toannguyen210579.workers.dev), tách riêng khỏi máy chủ app `tro-ly-gv`.

- `worker.js`: bảng xếp hạng (`/score`, `/top`), ghép trận nhanh (`/quick`), tạo phòng riêng (`/create`), phòng chơi WebSocket (`/ws?room=MÃ&pid=...&name=...&jet=...`), `/health`, `/peek`.
- `public/index.html`: bản game dựng sẵn để chơi trực tiếp ở địa chỉ gốc (cùng nguồn với máy chủ).
- `thu.mjs`: bộ thử, chạy `node thu.mjs [địa chỉ]`; mã người chơi thử bắt đầu bằng `zztest` nên không vào bảng xếp hạng thật.
- Thử trên máy: `npx wrangler@4.165.0 dev --port 8787` rồi `node thu.mjs`.
- Triển khai: đẩy thay đổi trong `may-chu-game/` lên nhánh `noi-may-chu`, workflow `trien_khai_may_chu_game.yml` tự đưa lên và ghi kết quả vào nhánh `sky-raid-ket-qua`.
- Gói miễn phí Cloudflare: 100.000 yêu cầu Durable Objects mỗi ngày (tin WebSocket tính 20 tin = 1 yêu cầu), 13.000 GB-giây mỗi ngày.
