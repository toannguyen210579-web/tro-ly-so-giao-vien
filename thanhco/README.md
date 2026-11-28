# Gióng Phá Thành bản Unity (nhánh làm việc)

- `nguon.enc`: mã nguồn dự án Unity 6 (6000.0.17f1) đã mã hóa AES-256 (khóa ở bí mật kho `THANHCO_KEY`).
- `tai_tai_nguyen.py`: máy dựng tự tải ảnh vật liệu thật CC0 (Poly Haven, ambientCG qua kho zuujis-cc0) và mô hình KayKit Adventurers (CC0).
- Workflow `thanhco_dong_goi.yml`: giải mã, tải tài nguyên, đóng gói WebGL bằng GameCI, đẩy bản dựng lên nhánh `thanh-co-ban-dung`.
  Cần 4 bí mật: `THANHCO_KEY`, `UNITY_LICENSE` (nội dung tệp Unity_lic.ulf của giấy phép Personal), `UNITY_EMAIL`, `UNITY_PASSWORD`.
- Kết quả, báo cáo: nhánh `thanh-co-ket-qua`.
