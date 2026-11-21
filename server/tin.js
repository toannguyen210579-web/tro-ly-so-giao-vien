// Danh sách tin, clip của kênh Việt Nam Tiêu Điểm cho mục Tin trong app (GET /tin).
// Thêm clip mới: thêm một mục vào đầu danh sách rồi đẩy mã, máy chủ tự triển khai; app nhận ngay, không cần cập nhật app.
// anh_bia: "asset:assets/tin/…" (ảnh có sẵn trong app) hoặc đường dẫn https, ví dụ ảnh đặt trong kho:
//   https://raw.githubusercontent.com/toannguyen210579-web/tro-ly-so-giao-vien/noi-may-chu/assets/tin/<tên>.jpg
// link_facebook: đường dẫn bài đăng trên trang kênh; video: đường dẫn tệp mp4 để phát trong app.
// Tin tức từ báo, cổng thông tin (không phải clip của kênh): thêm "nguon" (tên báo) và "link" (bài gốc);
//   tom_tat tự viết ngắn, không chép nguyên văn bài báo; anh_bia để "" (không dùng ảnh của báo).
export const TIN = [
 {
  "id": "17-11_giao-vien-hop-dong-thuong-tet",
  "ngay": "2026-11-17",
  "tit": "Giáo viên hợp đồng có được thưởng Tết?",
  "tom_tat": "Có, nếu thầy cô được xếp lương theo bảng lương nhà nước. Căn cứ là Điều 2 Nghị định 161: người làm việc theo hợp đồng lao động ở trường công lập, xếp lương theo Nghị định 204, thuộc diện hưởng tiền thưởng. Nhiều trường chưa chia vì Thông tư 66 của Bộ Tài chính không tính người hợp đồng khi cấp kinh phí quỹ thưởng; trường tự bố trí từ dự toán và nguồn thu hợp pháp. Hợp đồng có lương tự thỏa thuận thì không thuộc diện này.",
  "anh_bia": "asset:assets/tin/17-11_giao-vien-hop-dong-thuong-tet.jpg",
  "link_facebook": null,
  "video": null
 },
 {
  "id": "17-11_day-vuot-dinh-muc-tra-them-bao-nhieu",
  "ngay": "2026-11-17",
  "tit": "Dạy vượt định mức được trả thêm bao nhiêu?",
  "tom_tat": "Mỗi tiết dạy thêm được trả bằng 150% tiền một tiết dạy, theo Thông tư 21/2025 của Bộ Giáo dục và Đào tạo. Tiền một tiết tính từ tổng lương 12 tháng, gồm cả phụ cấp. Ví dụ kênh tự tính: giáo viên THCS hệ số 3,33, định mức 19 tiết/tuần, chưa tính phụ cấp, mỗi tiết dạy thêm khoảng 153 nghìn đồng. Mỗi giáo viên dạy thêm tối đa 200 tiết một năm học.",
  "anh_bia": "asset:assets/tin/17-11_day-vuot-dinh-muc-tra-them-bao-nhieu.jpg",
  "link_facebook": null,
  "video": null
 },
 {
  "id": "17-11_thuong-tet-giao-vien-nghi-dinh-161",
  "ngay": "2026-11-17",
  "tit": "Thưởng Tết giáo viên tính thế nào?",
  "tom_tat": "Quỹ thưởng bằng 10% quỹ lương cả năm, theo Nghị định 161 của Chính phủ, hiệu lực từ 1/7. Quỹ tính trên tiền lương theo hệ số, không tính phụ cấp. Tiền thưởng chia theo kết quả xếp loại cả năm, không nhất thiết theo hệ số lương. Mỗi trường tự ban hành quy chế tiền thưởng và phải công khai; tiền dùng không hết thì nộp lại ngân sách.",
  "anh_bia": "asset:assets/tin/17-11_thuong-tet-giao-vien-nghi-dinh-161.jpg",
  "link_facebook": null,
  "video": null
 },
 {
  "id": "16-11_thong-tu-93-hoi-dap-bang-dai-hoc-len-hang-ii",
  "ngay": "2026-11-16",
  "tit": "Có bằng đại học sau, có lên hạng II mới không?",
  "tom_tat": "Theo Thông tư 93, phải từng giữ hạng II cũ. Tiểu học và THCS, hạng II mới có hệ số từ 4,00 đến 6,38, cần đủ 9 năm dạy có đóng BHXH và hai năm học gần nhất hoàn thành tốt nhiệm vụ; không đủ thì xếp hạng III, giữ hệ số. Bằng đại học năm 2023, đang hạng III, chưa từng giữ hạng II cũ thì vẫn phải xét thăng hạng. Việc bổ nhiệm phải xong trước 31/12.",
  "anh_bia": "asset:assets/tin/16-11_thong-tu-93-hoi-dap-bang-dai-hoc-len-hang-ii.jpg",
  "link_facebook": null,
  "video": null
 },
 {
  "id": "15-11_tphcm-1427-giao-vien-nghi-viec",
  "ngay": "2026-11-15",
  "tit": "Vì sao hơn 1.400 giáo viên TP.HCM nghỉ việc?",
  "tom_tat": "Năm học vừa qua, 1.427 giáo viên TP.HCM nghỉ việc, chuyển việc; năm học này tính đến tháng 11 thêm 576 người. Báo cáo nêu hai lý do: thu nhập của một bộ phận giáo viên chưa tương xứng chi phí nhà ở, sinh hoạt, và việc sắp xếp trường làm thay đổi nơi làm việc. Thành phố đang thiếu 8.185 giáo viên, dự kiến tuyển 6.789 người trong tháng 11 và 12.",
  "anh_bia": "asset:assets/tin/15-11_tphcm-1427-giao-vien-nghi-viec.jpg",
  "link_facebook": null,
  "video": null
 }
];
