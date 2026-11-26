# Dựng ảnh cửa hàng (24/11/2026)

- `ghep_anh1.py`: ghép ảnh chụp trang chủ mới (nhánh anh-xem-app, xem_95_thanh_duoi.png) vào khung máy của `cua-hang/anh/man_hinh_01.png`, thêm thanh trạng thái, vạch vuốt.
- `tao_anh_co.py W H ten`: dựng 8 ảnh iPhone từ 8 ảnh 1080×1920 (giãn hai dải nền). App Store bắt buộc cỡ 6,3 inch: `1206 2622 iphone_63` → `cua-hang/anh-iphone/`. Cỡ 6,9 inch (1320×2868) là tùy chọn.
- `dung_anh_ipad.py chup.png man_hinh_0X.png "Dòng 1" "Dòng 2" ra.png`: dựng ảnh iPad 13 inch 2064×2752 từ ảnh chụp ở cỡ iPad (workflow `xem_ipad.yml`, nhánh anh-xem-ipad) → `cua-hang/anh-ipad/`. Phông Be Vietnam Pro (Google Fonts).
- Đường dẫn trong các tập lệnh là đường dẫn máy dựng ảnh của Claude; sửa lại khi chạy chỗ khác.
- `anh_noi_bat.py man_hinh_01.png chup.png ra.png thu_muc_phong`: dựng ảnh nổi bật Google Play 1024×500 (26/11/2026: khung máy trang chủ lấy từ ảnh số 1, máy thứ hai là ảnh chụp Nhận xét học sinh xem_42_nhan_xet_ai.png). Không ghi giá, "Miễn phí", xếp hạng (quy định Google Play).
