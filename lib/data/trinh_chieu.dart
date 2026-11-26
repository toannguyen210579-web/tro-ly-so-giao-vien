import 'dart:convert';

/// Tạo bài trình chiếu (26/11/2026): AI đọc giáo án (kế hoạch bài dạy) rồi dựng dàn trang chiếu theo đúng các hoạt
/// động của giáo án; app tự dựng tệp PowerPoint (.pptx) và PDF trên máy.
///
/// Khung kế hoạch bài dạy theo cấp học (người dùng dặn mỗi cấp có quy định soạn giáo án riêng):
/// - THCS, THPT: Phụ lục IV Công văn 5512/BGDĐT-GDTrH ngày 18/12/2020 (vẫn dùng năm học 2025-2026): Mục tiêu (kiến thức,
///   năng lực, phẩm chất); Thiết bị dạy học và học liệu; Tiến trình dạy học gồm Hoạt động 1 Xác định vấn đề/Mở đầu,
///   Hoạt động 2 Hình thành kiến thức mới, Hoạt động 3 Luyện tập, Hoạt động 4 Vận dụng; mỗi hoạt động có Mục tiêu,
///   Nội dung, Sản phẩm, Tổ chức thực hiện.
/// - Tiểu học: Phụ lục 3 Công văn 2345/BGDĐT-GDTH ngày 07/6/2021: Yêu cầu cần đạt; Đồ dùng dạy học; Các hoạt động dạy học
///   chủ yếu gồm Mở đầu (khởi động, kết nối), Hình thành kiến thức mới (khám phá), Luyện tập, thực hành, Vận dụng,
///   trải nghiệm; Điều chỉnh sau bài dạy.
/// - Mầm non: không có mẫu chung của Bộ; theo giáo án của trường: Mục đích yêu cầu, Chuẩn bị, Tiến hành (gây hứng thú,
///   hoạt động chính, kết thúc).
/// Từ năm học 2025-2026 giáo án phổ thông còn tích hợp năng lực số (Thông tư 02/2025/TT-BGDĐT, Công văn 3456/BGDĐT-GDPT):
/// giáo án có ghi thì bài chiếu giữ ý đó.

const capHocTrinhChieu = ['Mầm non', 'Tiểu học', 'THCS', 'THPT'];

/// Số trang chiếu thầy cô chọn (khoảng).
const soTrangTrinhChieu = [8, 12, 16];

class MauTrinhChieu {
  final String ma;
  final String ten;
  final int chinh; // màu dải tiêu đề, nền bìa (RRGGBB)
  final int dam; // dải dưới bìa
  final int nhat; // nhãn hoạt động, gạch nhấn
  const MauTrinhChieu(this.ma, this.ten, this.chinh, this.dam, this.nhat);

  String hex(int c) => c.toRadixString(16).padLeft(6, '0').toUpperCase();
}

const mauTrinhChieu = [
  MauTrinhChieu('xanh_duong', 'Xanh dương', 0x1F5FBF, 0x17488F, 0xFFD66B),
  MauTrinhChieu('xanh_la', 'Xanh lá', 0x1E7A57, 0x155C41, 0xFFE08A),
  MauTrinhChieu('tim', 'Tím', 0x5B3FA8, 0x432E80, 0xFFD66B),
];

/// Một trang chiếu. [loai]: bia (bìa), muc_tieu, hoat_dong, cau_hoi, tong_ket.
class TrangChieu {
  String loai;
  String hoatDong;
  String tieuDe;
  List<String> y;
  String ghiChu;
  TrangChieu({required this.loai, this.hoatDong = '', required this.tieuDe, this.y = const [], this.ghiChu = ''});

  bool get laBia => loai == 'bia';

  static TrangChieu? tuJson(Object? o) {
    if (o is! Map) return null;
    String chu(Object? v) => v == null ? '' : v.toString().trim();
    final y = o['y'] is List ? [for (final v in o['y'] as List) chu(v)].where((s) => s.isNotEmpty).toList() : <String>[];
    final td = chu(o['tieu_de']);
    if (td.isEmpty && y.isEmpty) return null;
    return TrangChieu(
      loai: chu(o['loai']).isEmpty ? 'hoat_dong' : chu(o['loai']),
      hoatDong: chu(o['hoat_dong']),
      tieuDe: td,
      y: y,
      ghiChu: chu(o['ghi_chu']),
    );
  }
}

class BaiChieu {
  String tieuDe;
  String mon;
  String lop;
  List<TrangChieu> trang;
  BaiChieu({required this.tieuDe, this.mon = '', this.lop = '', required this.trang});

  /// Đọc câu trả lời của AI (JSON; có khi kèm ```json hoặc vài chữ trước, sau). Không đọc được thì trả về null.
  static BaiChieu? tuTraLoi(String s) {
    final dau = s.indexOf('{');
    final cuoi = s.lastIndexOf('}');
    if (dau < 0 || cuoi <= dau) return null;
    Object? j;
    try {
      j = jsonDecode(s.substring(dau, cuoi + 1));
    } catch (_) {
      // Câu trả lời bị cắt giữa chừng (bài dài quá): giữ các trang đã đủ, bỏ trang dở cuối cùng
      for (var k = cuoi, lan = 0; k > dau && lan < 40; k = s.lastIndexOf('}', k - 1), lan++) {
        try {
          j = jsonDecode('${s.substring(dau, k + 1)}]}');
          break;
        } catch (_) {}
      }
    }
    if (j is! Map) return null;
    final ds = j['trang'] is List ? [for (final o in j['trang'] as List) TrangChieu.tuJson(o)].whereType<TrangChieu>().toList() : <TrangChieu>[];
    if (ds.isEmpty) return null;
    final td = (j['tieu_de'] ?? '').toString().trim();
    return BaiChieu(
      tieuDe: td.isEmpty ? ds.first.tieuDe : td,
      mon: (j['mon'] ?? '').toString().trim(),
      lop: (j['lop'] ?? '').toString().trim(),
      trang: ds,
    );
  }
}

/// Dòng đầu yêu cầu gửi máy chủ (nội dung giáo án đặt sau dòng '---').
String yeuCauTrinhChieu({required String capHoc, required int soTrang, String noiDung = ''}) {
  final dau = 'Cấp học: $capHoc. Số trang chiếu: khoảng $soTrang.';
  return noiDung.trim().isEmpty ? dau : '$dau\n---\n${noiDung.trim()}';
}

/// Cỡ chữ nội dung (phần trăm điểm, như PowerPoint: 2800 = 28 pt) theo độ dài các ý: ít chữ thì chữ to cho máy chiếu.
int coChuNoiDung(List<String> y) {
  final n = y.fold<int>(0, (t, s) => t + s.length) + 25 * y.length;
  if (n <= 140) return 3200;
  if (n <= 260) return 2800;
  if (n <= 380) return 2400;
  if (n <= 520) return 2000;
  return 1800;
}
