# Dựng ảnh cửa hàng (24/11/2026)

- `ghep_anh1.py`: ghép ảnh chụp trang chủ mới (nhánh anh-xem-app, xem_95_thanh_duoi.png) vào khung máy của `cua-hang/anh/man_hinh_01.png`, thêm thanh trạng thái, vạch vuốt.
- `tao_anh_co.py W H ten`: dựng 8 ảnh iPhone từ 8 ảnh 1080×1920 (giãn hai dải nền). App Store bắt buộc cỡ 6,3 inch: `1206 2622 iphone_63` → `cua-hang/anh-iphone/`. Cỡ 6,9 inch (1320×2868) là tùy chọn.
- `dung_anh_ipad.py chup.png man_hinh_0X.png "Dòng 1" "Dòng 2" ra.png`: dựng ảnh iPad 13 inch 2064×2752 từ ảnh chụp ở cỡ iPad (workflow `xem_ipad.yml`, nhánh anh-xem-ipad) → `cua-hang/anh-ipad/`. Phông Be Vietnam Pro (Google Fonts).
- Đường dẫn trong các tập lệnh là đường dẫn máy dựng ảnh của Claude; sửa lại khi chạy chỗ khác.
- `anh_noi_bat.py man_hinh_01.png chup.png ra.png thu_muc_phong`: dựng ảnh nổi bật Google Play 1024×500 (26/11/2026: khung máy trang chủ lấy từ ảnh số 1, máy thứ hai là ảnh chụp Nhận xét học sinh xem_42_nhan_xet_ai.png). Không ghi giá, "Miễn phí", xếp hạng (quy định Google Play).

- `dung_anh_iphone.py man_hinh_cu.png anh_chup.png ra.png ["Dòng 1" "Dòng 2"]` (26/11/2026): dựng lại ảnh 1080×1920 từ ảnh chụp mới (nhánh anh-xem-app-1, anh-xem-app-2 khi chạy xem_app.yml riêng từng nhóm bước bằng ô buoc, hau_to), giữ nền, khung máy, chữ của ảnh cũ; có hai dòng chữ thì vẽ tiêu đề mới. Ảnh trang chủ (xem_95_thanh_duoi.png) cắt 63 điểm ảnh dải xám ở đầu trước khi ghép; ảnh iPad trang chủ chép hàng 48 lên che dải xám. Sau đó giãn 1206×2622 theo mốc 91, 313, 405 cho mọi ảnh → `cua-hang/anh-iphone/`.
- Bộ ảnh 26/11/2026 (bản 0.4.0 (12)): 9 ảnh, thêm ảnh 9 "Giáo án có sẵn thành / bài trình chiếu" (nền lấy từ man_hinh_05). App Store nhận tối đa 10 ảnh mỗi loại; Google Play tối đa 8 ảnh điện thoại, khi làm hồ sơ Play chọn 8 ảnh.
