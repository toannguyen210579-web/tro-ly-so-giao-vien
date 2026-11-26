import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Đánh giá, xếp loại chất lượng viên chức theo Nghị định 233/2026/NĐ-CP (hiệu lực 01/7/2026, thay NĐ 90/2020).
/// - Điều 10: tiêu chí chung tối đa 30 điểm (Phụ lục I, 3 nhóm).
/// - Điều 11: kết quả thực hiện nhiệm vụ tối đa 70 điểm: số lượng, chất lượng, tiến độ.
/// - Điều 12: Xuất sắc từ 90; Tốt 70 đến dưới 90; Hoàn thành 50 đến dưới 70; dưới 50 Không hoàn thành.
///   Điểm năm tính từ điểm tháng hoặc quý; điểm từng tiêu chí do quy chế đơn vị quyết định.
/// - Điều 14: làm việc chưa đủ 06 tháng không xếp loại; kỷ luật về thực hiện nhiệm vụ, suy thoái: Không hoàn thành.

const tenNhomChung = [
  'Phẩm chất chính trị, đạo đức, ý thức kỷ luật',
  'Năng lực chuyên môn, trách nhiệm, thái độ phục vụ, phối hợp',
  'Đổi mới, sáng tạo, dám nghĩ, dám làm, dám chịu trách nhiệm',
];

const tenThanhPhanNv = ['Số lượng', 'Chất lượng', 'Tiến độ'];

/// Mức khối lượng việc hoàn thành (tỷ lệ phần trăm).
const mucKhoiLuong = <(String, double)>[('Đủ', 1), ('Phần lớn', 0.75), ('Một nửa', 0.5), ('Ít', 0.25), ('Không làm', 0)];

/// Mức chất lượng (chốt điểm mẫu 24/11/2026: Tốt 100%, Đạt 80%, Chưa đạt 0%).
const mucChatLuong = <(String, double)>[('Tốt', 1), ('Đạt', 0.8), ('Chưa đạt', 0)];

/// Mức tiến độ (Đúng hạn 100%, Trễ 60%, Không làm 0%).
const mucTienDo = <(String, double)>[('Đúng hạn', 1), ('Trễ hạn', 0.6), ('Không làm', 0)];

const mucXepLoai = ['Hoàn thành xuất sắc nhiệm vụ', 'Hoàn thành tốt nhiệm vụ', 'Hoàn thành nhiệm vụ', 'Không hoàn thành nhiệm vụ'];

/// Số thứ tự mức xếp loại theo điểm (Điều 12): 0 xuất sắc, 1 tốt, 2 hoàn thành, 3 không hoàn thành.
int mucTheoDiem(double d) {
  if (d >= 90) return 0;
  if (d >= 70) return 1;
  if (d >= 50) return 2;
  return 3;
}

/// Viết số điểm gọn: 85, 85,5, 85,25 (dấu phẩy thập phân).
String soDiem(double d) {
  final r = (d * 100).round() / 100;
  var s = r.toStringAsFixed(2);
  s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  return s.replaceAll('.', ',');
}

/// Quy chế chấm điểm của trường. Mặc định là điểm mẫu; thầy cô sửa theo quy chế trường mình.
class QuyCheDanhGia {
  /// true: theo dõi theo quý; false: theo tháng (mặc định).
  bool theoQuy;

  /// true: năm học (tháng 9 đến tháng 5); false: năm công tác (tháng 1 đến tháng 12).
  bool namHoc;

  /// Điểm tối đa ba nhóm tiêu chí chung (cộng 30).
  List<double> chung;

  /// Điểm tối đa số lượng, chất lượng, tiến độ (cộng 70).
  List<double> nhiemVu;

  QuyCheDanhGia({this.theoQuy = false, this.namHoc = true, List<double>? chung, List<double>? nhiemVu})
      : chung = chung ?? [10, 12, 8],
        nhiemVu = nhiemVu ?? [25, 30, 15];

  double get tongChung => chung.fold(0, (a, b) => a + b);
  double get tongNhiemVu => nhiemVu.fold(0, (a, b) => a + b);

  /// Lời báo khi điểm tối đa không khớp Nghị định (chung 30, nhiệm vụ 70); rỗng là hợp lệ.
  String get loiDiem {
    final l = <String>[];
    if ((tongChung - 30).abs() > 0.001) l.add('Ba nhóm tiêu chí chung phải cộng đủ 30 điểm (đang ${soDiem(tongChung)}).');
    if ((tongNhiemVu - 70).abs() > 0.001) l.add('Số lượng, chất lượng, tiến độ phải cộng đủ 70 điểm (đang ${soDiem(tongNhiemVu)}).');
    return l.join(' ');
  }

  Map<String, dynamic> toJson() => {'quy': theoQuy, 'nh': namHoc, 'c': chung, 'nv': nhiemVu};

  factory QuyCheDanhGia.fromJson(Map<String, dynamic> j) => QuyCheDanhGia(
        theoQuy: j['quy'] as bool? ?? false,
        namHoc: j['nh'] as bool? ?? true,
        chung: _ds(j['c'], 3),
        nhiemVu: _ds(j['nv'], 3),
      );
}

List<double>? _ds(dynamic v, int n) {
  if (v is! List || v.length != n) return null;
  return [for (final x in v) (x as num).toDouble()];
}

/// Một việc được giao trong kỳ.
class ViecGiao {
  String ten;
  int khoiLuong; // chỉ số trong mucKhoiLuong
  int chatLuong; // chỉ số trong mucChatLuong
  int tienDo; // chỉ số trong mucTienDo

  ViecGiao({required this.ten, this.khoiLuong = 0, this.chatLuong = 0, this.tienDo = 0});

  Map<String, dynamic> toJson() => {'t': ten, 'k': khoiLuong, 'c': chatLuong, 'd': tienDo};

  factory ViecGiao.fromJson(Map<String, dynamic> j) => ViecGiao(
        ten: j['t'] as String? ?? '',
        khoiLuong: (j['k'] as int? ?? 0).clamp(0, mucKhoiLuong.length - 1),
        chatLuong: (j['c'] as int? ?? 0).clamp(0, mucChatLuong.length - 1),
        tienDo: (j['d'] as int? ?? 0).clamp(0, mucTienDo.length - 1),
      );
}

/// Một kỳ theo dõi, đánh giá (một tháng hoặc một quý).
class KyDanhGia {
  /// Khóa kỳ: "2026-09" (tháng) hoặc "2026-Q1" (quý thứ nhất của năm học bắt đầu 2026, hoặc quý 1 năm 2026).
  final String ma;

  /// Điểm tự chấm ba nhóm tiêu chí chung. Null là chưa chấm.
  List<double>? chung;
  List<ViecGiao> viec;

  /// Điểm trường xác nhận (nếu có); khi có thì dùng thay điểm tự chấm.
  double? diemTruong;
  String ghiChu;

  KyDanhGia({required this.ma, this.chung, List<ViecGiao>? viec, this.diemTruong, this.ghiChu = ''}) : viec = viec ?? [];

  bool get daCham => chung != null || viec.isNotEmpty || diemTruong != null;

  double diemChung() => (chung ?? const []).fold(0.0, (a, b) => a + b);

  /// Ba điểm thành phần nhiệm vụ: trung bình mức của các việc nhân điểm tối đa. Chưa có việc nào: 0.
  List<double> diemNhiemVu(QuyCheDanhGia q) {
    if (viec.isEmpty) return [0, 0, 0];
    double tb(double Function(ViecGiao) f) => viec.map(f).fold(0.0, (a, b) => a + b) / viec.length;
    return [
      q.nhiemVu[0] * tb((v) => mucKhoiLuong[v.khoiLuong].$2),
      q.nhiemVu[1] * tb((v) => mucChatLuong[v.chatLuong].$2),
      q.nhiemVu[2] * tb((v) => mucTienDo[v.tienDo].$2),
    ];
  }

  double diemTuCham(QuyCheDanhGia q) => diemChung() + diemNhiemVu(q).fold(0.0, (a, b) => a + b);

  /// Điểm dùng để tính năm: ưu tiên điểm trường xác nhận.
  double diem(QuyCheDanhGia q) => diemTruong ?? diemTuCham(q);

  Map<String, dynamic> toJson() => {
        'ma': ma,
        if (chung != null) 'c': chung,
        'v': [for (final v in viec) v.toJson()],
        if (diemTruong != null) 'dt': diemTruong,
        'gc': ghiChu,
      };

  factory KyDanhGia.fromJson(Map<String, dynamic> j) => KyDanhGia(
        ma: j['ma'] as String,
        chung: _ds(j['c'], 3),
        viec: [for (final v in (j['v'] as List? ?? const [])) ViecGiao.fromJson(Map<String, dynamic>.from(v as Map))],
        diemTruong: (j['dt'] as num?)?.toDouble(),
        ghiChu: j['gc'] as String? ?? '',
      );
}

/// Một kỳ trong năm: mã, tên hiển thị, tháng đầu và tháng cuối (để lấy việc từ Lịch nhắc hạn).
class MocKy {
  final String ma;
  final String ten;
  final DateTime tu;
  final DateTime den; // ngày đầu của tháng kế sau kỳ
  const MocKy(this.ma, this.ten, this.tu, this.den);
}

/// Năm đánh giá chứa ngày [d]: năm học bắt đầu tháng 9 (tháng 6 đến 8 tính vào năm học vừa xong), hoặc năm công tác.
int namDanhGia(QuyCheDanhGia q, DateTime d) => q.namHoc ? (d.month >= 9 ? d.year : d.year - 1) : d.year;

String tenNam(QuyCheDanhGia q, int nam) => q.namHoc ? 'Năm học $nam-${nam + 1}' : 'Năm $nam';

/// Các kỳ của một năm đánh giá. Năm học: tháng 9 đến tháng 5 (9 tháng) hoặc 3 quý (9-11, 12-2, 3-5).
/// Năm công tác: tháng 1 đến 12 hoặc 4 quý.
List<MocKy> cacKy(QuyCheDanhGia q, int nam) {
  final thang = q.namHoc
      ? [for (var i = 0; i < 9; i++) DateTime(nam, 9 + i)]
      : [for (var i = 0; i < 12; i++) DateTime(nam, 1 + i)];
  String hai(int n) => n.toString().padLeft(2, '0');
  if (!q.theoQuy) {
    return [
      for (final t in thang) MocKy('${t.year}-${hai(t.month)}', 'Tháng ${t.month}/${t.year}', t, DateTime(t.year, t.month + 1)),
    ];
  }
  final ds = <MocKy>[];
  for (var i = 0; i < thang.length; i += 3) {
    final a = thang[i];
    final b = thang[i + 2];
    ds.add(MocKy('$nam-Q${i ~/ 3 + 1}', 'Quý ${i ~/ 3 + 1} (tháng ${a.month}–${b.month})', a, DateTime(b.year, b.month + 1)));
  }
  return ds;
}

/// Tổng hợp năm.
class TongHopNam {
  final int soKyDaCham;
  final int soKy;
  final double binhQuan; // 0 khi chưa chấm kỳ nào
  final double binhQuanChung;
  final double binhQuanNhiemVu;

  /// Điểm bình quân cần đạt ở các kỳ còn lại để chạm 90 (null khi không còn kỳ nào hoặc đã chắc chắn, hoặc không thể).
  final double? canDatXuatSac;
  final double? canDatTot;

  const TongHopNam(this.soKyDaCham, this.soKy, this.binhQuan, this.binhQuanChung, this.binhQuanNhiemVu, this.canDatXuatSac, this.canDatTot);

  int get muc => mucTheoDiem(binhQuan);
}

double? _canDat(double tong, int daCham, int conLai, double nguong) {
  if (conLai <= 0) return null;
  final can = (nguong * (daCham + conLai) - tong) / conLai;
  if (can <= 0 || can > 100) return null;
  return can;
}

TongHopNam tongHop(QuyCheDanhGia q, List<MocKy> moc, Map<String, KyDanhGia> ky) {
  final da = [for (final m in moc) if (ky[m.ma]?.daCham ?? false) ky[m.ma]!];
  if (da.isEmpty) return TongHopNam(0, moc.length, 0, 0, 0, null, null);
  final tong = da.fold(0.0, (a, k) => a + k.diem(q));
  // Hai phần của phiếu phải cộng đúng bằng tổng: kỳ có điểm trường xác nhận thì chia điểm đó theo tỷ lệ
  // tiêu chí chung, nhiệm vụ của điểm tự chấm (chưa tự chấm chi tiết thì chia theo khung 30/70).
  double chung = 0, nv = 0;
  for (final k in da) {
    final c = k.diemChung();
    final n = k.diemNhiemVu(q).fold(0.0, (x, y) => x + y);
    final d = k.diem(q);
    if (c + n > 0) {
      chung += d * c / (c + n);
      nv += d * n / (c + n);
    } else {
      chung += d * 0.3;
      nv += d * 0.7;
    }
  }
  chung /= da.length;
  nv /= da.length;
  final conLai = moc.length - da.length;
  return TongHopNam(da.length, moc.length, tong / da.length, chung, nv, _canDat(tong, da.length, conLai, 90), _canDat(tong, da.length, conLai, 70));
}

/// Điều kiện riêng ảnh hưởng mức xếp loại (Điều 12 khoản 4, Điều 14).
class DieuKienNam {
  bool chuaDu6Thang;
  bool biKyLuat;
  bool suyThoai;
  DieuKienNam({this.chuaDu6Thang = false, this.biKyLuat = false, this.suyThoai = false});

  Map<String, dynamic> toJson() => {'6t': chuaDu6Thang, 'kl': biKyLuat, 'st': suyThoai};
  factory DieuKienNam.fromJson(Map<String, dynamic> j) =>
      DieuKienNam(chuaDu6Thang: j['6t'] as bool? ?? false, biKyLuat: j['kl'] as bool? ?? false, suyThoai: j['st'] as bool? ?? false);
}

/// Mức tự xếp loại: null là không xếp loại (chưa đủ 6 tháng).
int? mucTuXepLoai(double binhQuan, DieuKienNam dk) {
  if (dk.chuaDu6Thang) return null;
  if (dk.biKyLuat || dk.suyThoai) return 3;
  return mucTheoDiem(binhQuan);
}

/// Phần phiếu năm thầy cô tự điền (Phụ lục II).
class PhieuNam {
  String hoTen;
  String chucDanh;
  String donVi;
  String coQuanTren;
  String uuDiem;
  String hanChe;
  DieuKienNam dieuKien;

  PhieuNam({this.hoTen = '', this.chucDanh = 'Giáo viên', this.donVi = '', this.coQuanTren = '', this.uuDiem = '', this.hanChe = '', DieuKienNam? dieuKien})
      : dieuKien = dieuKien ?? DieuKienNam();

  Map<String, dynamic> toJson() =>
      {'ht': hoTen, 'cd': chucDanh, 'dv': donVi, 'ct': coQuanTren, 'ud': uuDiem, 'hc': hanChe, 'dk': dieuKien.toJson()};

  factory PhieuNam.fromJson(Map<String, dynamic> j) => PhieuNam(
        hoTen: j['ht'] as String? ?? '',
        chucDanh: j['cd'] as String? ?? 'Giáo viên',
        donVi: j['dv'] as String? ?? '',
        coQuanTren: j['ct'] as String? ?? '',
        uuDiem: j['ud'] as String? ?? '',
        hanChe: j['hc'] as String? ?? '',
        dieuKien: j['dk'] is Map ? DieuKienNam.fromJson(Map<String, dynamic>.from(j['dk'] as Map)) : null,
      );
}

/// Lưu trên máy.
class KhoDanhGia {
  static const _qc = 'dg_quy_che';
  static const _ky = 'dg_ky';
  static String _phieu(int nam) => 'dg_phieu_$nam';

  static Future<QuyCheDanhGia> docQuyChe() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_qc);
    if (s == null) return QuyCheDanhGia();
    try {
      return QuyCheDanhGia.fromJson(Map<String, dynamic>.from(jsonDecode(s) as Map));
    } catch (_) {
      return QuyCheDanhGia();
    }
  }

  static Future<void> ghiQuyChe(QuyCheDanhGia q) async =>
      (await SharedPreferences.getInstance()).setString(_qc, jsonEncode(q.toJson()));

  static Future<Map<String, KyDanhGia>> docKy() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_ky);
    if (s == null) return {};
    try {
      final ds = jsonDecode(s) as List;
      return {for (final e in ds) (e as Map)['ma'] as String: KyDanhGia.fromJson(Map<String, dynamic>.from(e))};
    } catch (_) {
      return {};
    }
  }

  static Future<void> ghiKy(Map<String, KyDanhGia> ky) async => (await SharedPreferences.getInstance())
      .setString(_ky, jsonEncode([for (final k in ky.values) if (k.daCham) k.toJson()]));

  static Future<PhieuNam?> docPhieu(int nam) async {
    final s = (await SharedPreferences.getInstance()).getString(_phieu(nam));
    if (s == null) return null;
    try {
      return PhieuNam.fromJson(Map<String, dynamic>.from(jsonDecode(s) as Map));
    } catch (_) {
      return null;
    }
  }

  static Future<void> ghiPhieu(int nam, PhieuNam ph) async =>
      (await SharedPreferences.getInstance()).setString(_phieu(nam), jsonEncode(ph.toJson()));
}

/// Nội dung gửi AI để viết nháp Ưu điểm, Hạn chế: chỉ các việc và mức đã chấm, không có họ tên.
String cauHoiUuHanChe(QuyCheDanhGia q, List<MocKy> moc, Map<String, KyDanhGia> ky, String chucDanh) {
  final b = StringBuffer('Chức danh: ${chucDanh.isEmpty ? 'Giáo viên' : chucDanh}.\n');
  for (final m in moc) {
    final k = ky[m.ma];
    if (k == null || !k.daCham) continue;
    b.writeln('${m.ten}: ${soDiem(k.diem(q))} điểm.');
    for (final v in k.viec) {
      b.writeln('- ${v.ten}: khối lượng ${mucKhoiLuong[v.khoiLuong].$1}, chất lượng ${mucChatLuong[v.chatLuong].$1}, tiến độ ${mucTienDo[v.tienDo].$1}.');
    }
    if (k.ghiChu.trim().isNotEmpty) b.writeln('Ghi chú: ${k.ghiChu.trim()}');
  }
  final s = b.toString();
  return s.length > 3800 ? s.substring(0, 3800) : s;
}
