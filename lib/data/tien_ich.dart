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

  const TienIch({
    required this.moTa,
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
  TienIch(ma: 'hop', moTa: 'Ghi ý kiến cuộc họp, xuất biên bản đúng mẫu', ten: 'Họp, biên bản', bieuTuong: Icons.mic_none, nhom: NhomTienIch.hanhChinh, tuKhoa: ['họp', 'biên bản', 'ghi âm'], coTrongBanDau: true),
  TienIch(ma: 'quet', moTa: 'Chụp giấy tờ, tự làm phẳng, gộp thành PDF', ten: 'Quét PDF', bieuTuong: Icons.document_scanner_outlined, nhom: NhomTienIch.hanhChinh, tuKhoa: ['quét', 'scan', 'pdf'], coTrongBanDau: true),
  TienIch(ma: 'minh_chung', moTa: 'Lưu giấy khen, ảnh hoạt động, xuất hồ sơ PDF', ten: 'Sổ minh chứng', bieuTuong: Icons.fact_check_outlined, nhom: NhomTienIch.hanhChinh, tuKhoa: ['minh chứng', 'thi đua', 'kiểm định'], coTrongBanDau: true),
  TienIch(ma: 'anh_the', moTa: 'Tách nền, in ảnh 3x4, 4x6 ngay trên máy', ten: 'Ảnh thẻ', bieuTuong: Icons.badge_outlined, nhom: NhomTienIch.hanhChinh, tuKhoa: ['ảnh thẻ', '3x4', '4x6'], coTrongBanDau: true),
  TienIch(ma: 'doc_to', moTa: 'Đọc văn bản thành tiếng, nói thành chữ', ten: 'Giọng nói ⇄ Văn bản', bieuTuong: Icons.record_voice_over_outlined, nhom: NhomTienIch.hanhChinh, tuKhoa: ['đọc to', 'đọc giúp', 'giọng nói', 'nói thành chữ', 'văn bản thành giọng'], coTrongBanDau: true),
  TienIch(ma: 'sang_word', moTa: 'Chuyển ảnh, PDF thành tệp Word sửa được', ten: 'Ảnh sang Word', bieuTuong: Icons.description_outlined, nhom: NhomTienIch.hanhChinh, tuKhoa: ['word', 'chuyển chữ']),
  TienIch(ma: 'lich', moTa: 'Ghi lịch công tác, nhắc hạn nộp hồ sơ', ten: 'Lịch, nhắc hạn', bieuTuong: Icons.event_note_outlined, nhom: NhomTienIch.hanhChinh, tuKhoa: ['lịch', 'nhắc', 'hạn nộp']),
  TienIch(ma: 'luong', moTa: 'Tính lương, phụ cấp, ngày nâng bậc', ten: 'Tính lương', bieuTuong: Icons.payments_outlined, nhom: NhomTienIch.hanhChinh, tuKhoa: ['lương', 'phụ cấp', 'nâng bậc']),
  // Chuyên môn
  TienIch(ma: 'nhan_xet', moTa: 'Viết nhận xét theo TT 22, TT 27, tính điểm TB', ten: 'Nhận xét học sinh', bieuTuong: Icons.assignment_turned_in_outlined, nhom: NhomTienIch.chuyenMon, tuKhoa: ['nhận xét', 'đánh giá', 'điểm trung bình'], coTrongBanDau: true),
  TienIch(ma: 'cham_tn', moTa: 'Nhập đáp án, chấm điểm, thống kê cả lớp', ten: 'Chấm trắc nghiệm', bieuTuong: Icons.checklist_outlined, nhom: NhomTienIch.chuyenMon, tuKhoa: ['chấm', 'trắc nghiệm'], coTrongBanDau: true),
  TienIch(ma: 'nhan_ph', moTa: 'Tin mẫu mời họp, báo nghỉ, gửi qua Zalo', ten: 'Nhắn phụ huynh', bieuTuong: Icons.chat_outlined, nhom: NhomTienIch.chuyenMon, tuKhoa: ['phụ huynh', 'nhắn', 'zalo'], coTrongBanDau: true),
  TienIch(ma: 'tao_de', moTa: 'Chụp sách, tạo câu hỏi kiểm tra', ten: 'Tạo đề từ ảnh', bieuTuong: Icons.photo_camera_outlined, nhom: NhomTienIch.chuyenMon, tuKhoa: ['tạo đề', 'ra đề']),
  TienIch(ma: 'o_chu', moTa: 'Tạo ô chữ ôn bài trên lớp', ten: 'Ô chữ', bieuTuong: Icons.grid_on_outlined, nhom: NhomTienIch.chuyenMon, tuKhoa: ['ô chữ']),
  TienIch(ma: 'gio_the', moTa: 'Học sinh giơ thẻ, máy quét đáp án cả lớp', ten: 'Giơ thẻ', bieuTuong: Icons.style_outlined, nhom: NhomTienIch.chuyenMon, tuKhoa: ['giơ thẻ']),
  TienIch(ma: 'cong_cu', moTa: 'Điểm danh, gọi tên ngẫu nhiên, chia nhóm', ten: 'Công cụ trên lớp', bieuTuong: Icons.timer_outlined, nhom: NhomTienIch.chuyenMon, tuKhoa: ['điểm danh', 'gọi tên', 'chia nhóm']),
];

/// Ba tiện ích nổi bật mỗi nhóm trên trang chủ (theo bản thiết kế đã chốt).
const noiBatHanhChinh = ['hop', 'quet', 'minh_chung'];
const noiBatChuyenMon = ['nhan_xet', 'cham_tn', 'nhan_ph'];

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
