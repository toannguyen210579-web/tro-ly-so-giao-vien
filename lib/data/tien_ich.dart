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

  const TienIch({
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
  TienIch(ma: 'hop', ten: 'Họp, biên bản', bieuTuong: Icons.mic_none, nhom: NhomTienIch.hanhChinh, tuKhoa: ['họp', 'biên bản', 'ghi âm']),
  TienIch(ma: 'quet', ten: 'Quét PDF', bieuTuong: Icons.document_scanner_outlined, nhom: NhomTienIch.hanhChinh, tuKhoa: ['quét', 'scan', 'pdf'], coTrongBanDau: true),
  TienIch(ma: 'minh_chung', ten: 'Sổ minh chứng', bieuTuong: Icons.fact_check_outlined, nhom: NhomTienIch.hanhChinh, tuKhoa: ['minh chứng', 'thi đua', 'kiểm định']),
  TienIch(ma: 'anh_the', ten: 'Ảnh thẻ', bieuTuong: Icons.badge_outlined, nhom: NhomTienIch.hanhChinh, tuKhoa: ['ảnh thẻ', '3x4', '4x6'], coTrongBanDau: true),
  TienIch(ma: 'doc_to', ten: 'Đọc to', bieuTuong: Icons.volume_up_outlined, nhom: NhomTienIch.hanhChinh, tuKhoa: ['đọc to', 'đọc giúp']),
  TienIch(ma: 'sang_word', ten: 'Ảnh sang Word', bieuTuong: Icons.description_outlined, nhom: NhomTienIch.hanhChinh, tuKhoa: ['word', 'chuyển chữ']),
  TienIch(ma: 'lich', ten: 'Lịch, nhắc hạn', bieuTuong: Icons.event_note_outlined, nhom: NhomTienIch.hanhChinh, tuKhoa: ['lịch', 'nhắc', 'hạn nộp']),
  TienIch(ma: 'luong', ten: 'Tính lương', bieuTuong: Icons.payments_outlined, nhom: NhomTienIch.hanhChinh, tuKhoa: ['lương', 'phụ cấp', 'nâng bậc']),
  // Chuyên môn
  TienIch(ma: 'nhan_xet', ten: 'Nhận xét học sinh', bieuTuong: Icons.assignment_turned_in_outlined, nhom: NhomTienIch.chuyenMon, tuKhoa: ['nhận xét', 'đánh giá', 'điểm trung bình'], coTrongBanDau: true),
  TienIch(ma: 'cham_tn', ten: 'Chấm trắc nghiệm', bieuTuong: Icons.checklist_outlined, nhom: NhomTienIch.chuyenMon, tuKhoa: ['chấm', 'trắc nghiệm']),
  TienIch(ma: 'nhan_ph', ten: 'Nhắn phụ huynh', bieuTuong: Icons.chat_outlined, nhom: NhomTienIch.chuyenMon, tuKhoa: ['phụ huynh', 'nhắn', 'zalo'], coTrongBanDau: true),
  TienIch(ma: 'tao_de', ten: 'Tạo đề từ ảnh', bieuTuong: Icons.photo_camera_outlined, nhom: NhomTienIch.chuyenMon, tuKhoa: ['tạo đề', 'ra đề']),
  TienIch(ma: 'o_chu', ten: 'Ô chữ', bieuTuong: Icons.grid_on_outlined, nhom: NhomTienIch.chuyenMon, tuKhoa: ['ô chữ']),
  TienIch(ma: 'gio_the', ten: 'Giơ thẻ', bieuTuong: Icons.style_outlined, nhom: NhomTienIch.chuyenMon, tuKhoa: ['giơ thẻ']),
  TienIch(ma: 'cong_cu', ten: 'Công cụ trên lớp', bieuTuong: Icons.timer_outlined, nhom: NhomTienIch.chuyenMon, tuKhoa: ['điểm danh', 'gọi tên', 'chia nhóm']),
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
