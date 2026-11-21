import 'package:flutter/material.dart';

enum NhomTienIch { hanhChinh, chuyenMon }

/// Một tiện ích trong app.
class TienIch {
  final String ma;
  final String ten;
  final IconData bieuTuong;
  final NhomTienIch nhom;

  /// Có trong bản đầu hay chưa. Tiện ích chưa có sẽ mở màn "Sắp có".
  final bool coTrongBanDau;

  /// Từ khóa để ô "Thầy cô cần làm gì?" mở thẳng tiện ích này.
  final List<String> tuKhoa;

  /// Một câu ngắn nói công dụng, chạy chữ dưới tên tiện ích.
  final String moTa;

  /// Một câu nói rõ tiện ích làm hộ việc gì, không bắt nhập thêm (hiện ở đầu màn tiện ích).
  final String giupGi;

  const TienIch({
    required this.moTa,
    required this.giupGi,
    required this.ma,
    required this.ten,
    required this.bieuTuong,
    required this.nhom,
    required this.tuKhoa,
    this.coTrongBanDau = false,
  });
}

const dsTienIch = <TienIch>[
  // Hành chính
  TienIch(ma: 'hop', giupGi: 'Ghi nhanh trong lúc họp, app tự trình bày thành biên bản PDF, không phải gõ lại.', moTa: 'Ghi diễn biến cuộc họp, mỗi ý kiến một dòng, rồi xuất biên bản PDF đúng mẫu', ten: 'Họp, biên bản', bieuTuong: Icons.mic_none, nhom: NhomTienIch.hanhChinh, tuKhoa: ['họp', 'biên bản', 'ghi âm'], coTrongBanDau: true),
  TienIch(ma: 'quet', giupGi: 'Chụp là có tệp PDF gửi Zalo, không cần ra tiệm photo, không cần máy quét.', moTa: 'Chụp giấy tờ, app tự làm phẳng trang, gộp nhiều trang thành PDF gửi Zalo', ten: 'Quét PDF', bieuTuong: Icons.document_scanner_outlined, nhom: NhomTienIch.hanhChinh, tuKhoa: ['quét', 'scan', 'pdf'], coTrongBanDau: true),
  TienIch(ma: 'minh_chung', giupGi: 'Chụp lưu giấy khen ngay khi nhận, đến kỳ nộp hồ sơ chỉ cần bấm xuất PDF.', moTa: 'Chụp lưu giấy khen, ảnh hoạt động theo nhóm, đến kỳ nộp hồ sơ bấm xuất PDF', ten: 'Sổ minh chứng', bieuTuong: Icons.fact_check_outlined, nhom: NhomTienIch.hanhChinh, tuKhoa: ['minh chứng', 'thi đua', 'kiểm định'], coTrongBanDau: true),
  TienIch(ma: 'anh_the', giupGi: 'Tự chụp, tự đổi nền, ra tiệm in là xong, không phải đi chụp ảnh.', moTa: 'Chụp ảnh, tự tách nền xanh hoặc trắng, in ảnh 3x4, 4x6 trên giấy 10x15', ten: 'Ảnh thẻ', bieuTuong: Icons.badge_outlined, nhom: NhomTienIch.hanhChinh, tuKhoa: ['ảnh thẻ', '3x4', '4x6'], coTrongBanDau: true),
  TienIch(ma: 'doc_to', giupGi: 'Nói thay gõ, nghe thay đọc, dùng cho việc thầy cô đang làm, không tạo thêm tệp nào phải quản lý.', moTa: 'Dán văn bản để máy đọc thành tiếng, bấm micro để lời nói thành chữ', ten: 'Giọng nói ⇄ Văn bản', bieuTuong: Icons.record_voice_over_outlined, nhom: NhomTienIch.hanhChinh, tuKhoa: ['đọc to', 'đọc giúp', 'giọng nói', 'nói thành chữ', 'văn bản thành giọng'], coTrongBanDau: true),
  TienIch(ma: 'sang_word', giupGi: 'Biến ảnh chụp văn bản thành tệp Word sửa được, không phải gõ lại.', moTa: 'Chụp hoặc chọn ảnh văn bản, app nhận chữ thành tệp Word sửa được, không phải gõ lại', ten: 'Ảnh sang Word', bieuTuong: Icons.description_outlined, nhom: NhomTienIch.hanhChinh, tuKhoa: ['word', 'chuyển chữ', 'nhận chữ'], coTrongBanDau: true),
  TienIch(ma: 'lich', giupGi: 'Nhắc trước hạn nộp hồ sơ, không phải tự nhớ.', moTa: 'Ghi lịch công tác, nhắc trước hạn nộp hồ sơ, việc sắp đến hạn hiện ở trang chủ', ten: 'Lịch, nhắc hạn', bieuTuong: Icons.event_note_outlined, nhom: NhomTienIch.hanhChinh, tuKhoa: ['lịch', 'nhắc', 'hạn nộp'], coTrongBanDau: true),
  TienIch(ma: 'luong', giupGi: 'Biết ngay lương, phụ cấp, ngày nâng bậc, không phải tự tra bảng hệ số.', moTa: 'Nhập hạng, bậc, năm công tác, app tính lương, phụ cấp, ngày nâng bậc', ten: 'Tính lương', bieuTuong: Icons.payments_outlined, nhom: NhomTienIch.hanhChinh, tuKhoa: ['lương', 'phụ cấp', 'nâng bậc'], coTrongBanDau: true),
  // Chuyên môn
  TienIch(ma: 'nhan_xet', giupGi: 'Không nhập lại: soạn nhận xét nhanh ở đây, chép hoặc xuất Excel để đưa vào phần mềm trường đang dùng.', moTa: 'Nhận xét theo Thông tư 22, 27 (sửa đổi bởi Thông tư 89/2026) cho cả lớp, tính điểm trung bình môn', ten: 'Nhận xét học sinh', bieuTuong: Icons.assignment_turned_in_outlined, nhom: NhomTienIch.chuyenMon, tuKhoa: ['nhận xét', 'đánh giá', 'điểm trung bình'], coTrongBanDau: true),
  TienIch(ma: 'cham_tn', giupGi: 'Chấm thay cây bút đỏ, bảng điểm chép thẳng sang Excel, không phải cộng tay.', moTa: 'Nhập đáp án từng mã đề, chạm hoặc gõ nhanh bài làm, app tự chấm, thống kê', ten: 'Chấm trắc nghiệm', bieuTuong: Icons.checklist_outlined, nhom: NhomTienIch.chuyenMon, tuKhoa: ['chấm', 'trắc nghiệm'], coTrongBanDau: true),
  TienIch(ma: 'nhan_ph', giupGi: 'Có sẵn lời nhắn lịch sự, bấm gửi sang Zalo, không phải nghĩ câu chữ.', moTa: 'Tin mẫu mời họp, báo nghỉ, trao đổi khác để gửi qua Zalo', ten: 'Nhắn phụ huynh', bieuTuong: Icons.chat_outlined, nhom: NhomTienIch.chuyenMon, tuKhoa: ['phụ huynh', 'nhắn', 'zalo'], coTrongBanDau: true),
  TienIch(ma: 'tao_de', giupGi: 'Chụp đề là có đáp án, thang điểm để thầy cô xem lại, không phải giải từ đầu.', moTa: 'Chụp đề, AI làm lời giải từng bước, đáp án, thang điểm, ra đề tương tự', ten: 'Giải đề, soạn đáp án', bieuTuong: Icons.photo_camera_outlined, nhom: NhomTienIch.chuyenMon, tuKhoa: ['giải đề', 'giải bài', 'soạn đáp án', 'tạo đề', 'ra đề', 'đề tương tự'], coTrongBanDau: true),
  TienIch(ma: 'o_chu', giupGi: 'Có sẵn trò ôn bài trên điện thoại, không phải chuẩn bị đồ dùng.', moTa: 'Tạo ô chữ ôn bài từ từ khóa của bài học, chiếu lên lớp', ten: 'Ô chữ', bieuTuong: Icons.grid_on_outlined, nhom: NhomTienIch.chuyenMon, tuKhoa: ['ô chữ'], coTrongBanDau: true),
  TienIch(ma: 'gio_the', giupGi: 'Cả lớp giơ thẻ, điện thoại quét một lượt là biết đáp án, không phải đếm tay.', moTa: 'In thẻ QR cho cả lớp, các em xoay thẻ chọn A, B, C, D, chụp một tấm là biết đáp án', ten: 'Giơ thẻ', bieuTuong: Icons.style_outlined, nhom: NhomTienIch.chuyenMon, tuKhoa: ['giơ thẻ', 'plickers', 'khảo sát nhanh'], coTrongBanDau: true),
  TienIch(ma: 'cong_cu', giupGi: 'Điểm danh, gọi tên, chia nhóm ngay trên điện thoại, không phải chuẩn bị đồ dùng.', moTa: 'Điểm danh, gọi tên ngẫu nhiên, chia nhóm, đồng hồ bấm giờ trên lớp', ten: 'Công cụ trên lớp', bieuTuong: Icons.timer_outlined, nhom: NhomTienIch.chuyenMon, tuKhoa: ['điểm danh', 'gọi tên', 'chia nhóm'], coTrongBanDau: true),
];

/// Ba tiện ích nổi bật mỗi nhóm trên trang chủ (theo bản thiết kế đã chốt).
const noiBatHanhChinh = ['hop', 'doc_to', 'quet', 'minh_chung'];
const noiBatChuyenMon = ['nhan_xet', 'cham_tn', 'nhan_ph'];

/// Câu giải thích cho Hỏi Trợ lý (không nằm trong danh sách tiện ích).
const giupGiHoiTroLy = 'Hỏi nhanh mọi việc, từ chế độ, văn bản đến chuyện thường ngày.';

TienIch timTheoMa(String ma) => dsTienIch.firstWhere((t) => t.ma == ma);

/// Tìm tiện ích khớp với câu thầy cô gõ. Không khớp thì trả về null,
/// khi đó câu được chuyển sang Hỏi Trợ lý.
TienIch? timTheoCau(String cau) {
  final c = cau.toLowerCase();
  for (final t in dsTienIch) {
    for (final k in t.tuKhoa) {
      if (c.contains(k)) return t;
    }
  }
  return null;
}
