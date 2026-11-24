import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'o_chu.dart';
import 'o_chu_ngay_kho.dart';

/// Ô chữ mỗi ngày: mỗi ngày một ô lấy từ kho soạn sẵn (o_chu_ngay_kho.dart), tự giải bằng cách gõ đáp án.
/// Phần tính toán (có kiểm thử); màn hình ở screens/o_chu_moi_ngay.dart.

String _hai(int n) => n.toString().padLeft(2, '0');

/// Mã ngày dạng 20261124, dùng làm khóa lưu kết quả.
String maNgay(DateTime d) => '${d.year}${_hai(d.month)}${_hai(d.day)}';

const tenThu = ['Thứ hai', 'Thứ ba', 'Thứ tư', 'Thứ năm', 'Thứ sáu', 'Thứ bảy', 'Chủ nhật'];

/// "Thứ ba, 24/11/2026".
String ngayDayDu(DateTime d) => '${tenThu[d.weekday - 1]}, ${_hai(d.day)}/${_hai(d.month)}/${d.year}';

final _moc = DateTime.utc(2026, 1, 1);

/// Số thứ tự trong kho của ô chữ ngày [d]; hết kho thì quay vòng.
int soOChuCuaNgay(DateTime d) => DateTime.utc(d.year, d.month, d.day).difference(_moc).inDays % khoOChuNgay.length;

OChu oChuCuaNgay(DateTime d) {
  final (ten, khoa, hang) = khoOChuNgay[soOChuCuaNgay(d)];
  return OChu(id: 'ngay_${maNgay(d)}', ten: ten, tuKhoa: khoa, hang: [for (final (h, a) in hang) HangO(h, a)]);
}

const _soBangChu = ['KHONG', 'MOT', 'HAI', 'BA', 'BON', 'NAM', 'SAU', 'BAY', 'TAM', 'CHIN', 'MUOI'];

/// Gõ có dấu hay không dấu, hoa hay thường, viết số (9) hay viết chữ (chín) đều được.
bool khopDapAn(String go, String dapAn) {
  var g = chuanHoaO(go);
  if (g.isEmpty) return false;
  final so = int.tryParse(g);
  if (so != null && so >= 0 && so < _soBangChu.length) g = _soBangChu[so];
  return g == chuanHoaO(dapAn);
}

/// Trạng thái một hàng.
class TrangThaiHang {
  static const chua = 0; // chưa giải
  static const dungNgay = 1; // đúng ngay lần đầu
  static const dungSauSai = 2; // đúng sau khi trả lời sai
  static const xemDapAn = 3; // bấm xem đáp án
  static const boQua = 4; // không cần giải vì đã đoán ra từ khóa
}

/// Tiến độ giải ô chữ của một ngày, lưu trên máy để thoát ra vào lại vẫn chơi tiếp.
class TienDoNgay {
  final String ngay;
  final List<int> hang;
  final List<int> sai;
  int saiKhoa;
  bool doanKhoa;
  int batDau;
  int? xong;

  TienDoNgay({required this.ngay, required this.hang, required this.sai, this.saiKhoa = 0, this.doanKhoa = false, required this.batDau, this.xong});

  factory TienDoNgay.moi(String ngay, int soHang, DateTime luc) =>
      TienDoNgay(ngay: ngay, hang: List.filled(soHang, TrangThaiHang.chua), sai: List.filled(soHang, 0), batDau: luc.millisecondsSinceEpoch);

  bool get daXong => xong != null;
  bool get daBatDauGiai => hang.any((t) => t != TrangThaiHang.chua) || tongSai > 0;
  int get tongSai => sai.fold(0, (a, b) => a + b) + saiKhoa;
  int get soHangGiai => hang.where((t) => t == TrangThaiHang.dungNgay || t == TrangThaiHang.dungSauSai).length;
  int get soHangDaMo => hang.where((t) => t != TrangThaiHang.chua).length;
  Duration get thoiGian {
    final ms = (xong ?? batDau) - batDau;
    return Duration(milliseconds: ms < 0 ? 0 : ms);
  }

  void _kiemXong(DateTime luc) {
    if (xong == null && hang.every((t) => t != TrangThaiHang.chua)) xong = luc.millisecondsSinceEpoch;
  }

  /// Ghi nhận câu trả lời cho hàng [i]; trả về true nếu đúng.
  bool traLoi(OChu o, int i, String go, DateTime luc) {
    if (daXong || hang[i] != TrangThaiHang.chua || chuanHoaO(go).isEmpty) return false;
    if (khopDapAn(go, o.hang[i].dapAn)) {
      hang[i] = sai[i] == 0 ? TrangThaiHang.dungNgay : TrangThaiHang.dungSauSai;
      _kiemXong(luc);
      return true;
    }
    sai[i]++;
    return false;
  }

  void moDapAn(int i, DateTime luc) {
    if (daXong || hang[i] != TrangThaiHang.chua) return;
    hang[i] = TrangThaiHang.xemDapAn;
    _kiemXong(luc);
  }

  /// Đoán từ khóa hàng dọc; đúng thì xong luôn, các hàng chưa giải không cần giải nữa.
  bool doanTuKhoa(OChu o, String go, DateTime luc) {
    if (daXong || chuanHoaO(go).isEmpty) return false;
    if (khopDapAn(go, o.tuKhoa)) {
      doanKhoa = true;
      for (var i = 0; i < hang.length; i++) {
        if (hang[i] == TrangThaiHang.chua) hang[i] = TrangThaiHang.boQua;
      }
      _kiemXong(luc);
      return true;
    }
    saiKhoa++;
    return false;
  }

  /// Hàng chưa giải kế tiếp sau [tu] (quay vòng), không còn thì null.
  int? hangKeTiep(int tu) {
    for (var k = 1; k <= hang.length; k++) {
      final i = (tu + k) % hang.length;
      if (hang[i] == TrangThaiHang.chua) return i;
    }
    return null;
  }

  Map<String, dynamic> toJson() =>
      {'ngay': ngay, 'hang': hang, 'sai': sai, 'saiKhoa': saiKhoa, 'doanKhoa': doanKhoa, 'batDau': batDau, if (xong != null) 'xong': xong};

  factory TienDoNgay.fromJson(Map<String, dynamic> j) => TienDoNgay(
        ngay: j['ngay'] as String? ?? '',
        hang: [for (final v in (j['hang'] as List<dynamic>? ?? [])) (v as num).toInt()],
        sai: [for (final v in (j['sai'] as List<dynamic>? ?? [])) (v as num).toInt()],
        saiKhoa: (j['saiKhoa'] as num?)?.toInt() ?? 0,
        doanKhoa: j['doanKhoa'] as bool? ?? false,
        batDau: (j['batDau'] as num?)?.toInt() ?? 0,
        xong: (j['xong'] as num?)?.toInt(),
      );
}

/// "3 phút 05 giây", "45 giây".
String thoiGianVN(Duration d) {
  final g = d.inSeconds;
  return g < 60 ? '$g giây' : '${g ~/ 60} phút ${_hai(g % 60)} giây';
}

/// Số ngày giải liền nhau tính đến hôm nay (hôm nay chưa giải thì tính đến hôm qua).
int chuoiNgay(Iterable<String> ngayXong, DateTime homNay) {
  final s = ngayXong.toSet();
  var d = DateTime(homNay.year, homNay.month, homNay.day);
  if (!s.contains(maNgay(d))) d = DateTime(d.year, d.month, d.day - 1);
  var n = 0;
  while (s.contains(maNgay(d))) {
    n++;
    d = DateTime(d.year, d.month, d.day - 1);
  }
  return n;
}

/// Kết quả để chia sẻ, không lộ đáp án: mỗi hàng một ô màu.
String vanBanChiaSe(TienDoNgay t, OChu o, DateTime ngay, int chuoi) {
  String mau(int v) => switch (v) {
        TrangThaiHang.dungNgay => '🟩',
        TrangThaiHang.dungSauSai => '🟨',
        TrangThaiHang.boQua => '⬛',
        _ => '⬜',
      };
  final b = StringBuffer()
    ..writeln('Ô chữ mỗi ngày ${_hai(ngay.day)}/${_hai(ngay.month)}/${ngay.year} · ${o.ten}')
    ..writeln('${t.hang.map(mau).join()}${t.doanKhoa ? ' 🔑' : ''}')
    ..writeln('Giải đúng ${t.soHangGiai}/${o.hang.length} hàng${t.doanKhoa ? ', đoán ra từ khóa' : ''}'
        '${t.tongSai == 0 ? ', không sai lần nào' : ', sai ${t.tongSai} lần'}, ${thoiGianVN(t.thoiGian)}.');
  if (chuoi > 1) b.writeln('Chuỗi $chuoi ngày liền.');
  b.write('Chơi trên app Trợ lý số Giáo viên - Một chạm');
  return b.toString();
}

/// Lưu tiến độ, danh sách ngày đã giải xong (để tính chuỗi ngày) ngay trên máy.
class LuuOChuNgay {
  static const _khoaXong = 'o_chu_ngay_xong';
  static String _khoa(String ngay) => 'o_chu_ngay_$ngay';

  static Future<TienDoNgay?> doc(String ngay) async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_khoa(ngay));
    if (s == null) return null;
    try {
      return TienDoNgay.fromJson(Map<String, dynamic>.from(jsonDecode(s) as Map));
    } catch (_) {
      return null;
    }
  }

  static Future<List<String>> ngayDaXong() async => (await SharedPreferences.getInstance()).getStringList(_khoaXong) ?? [];

  static Future<void> ghi(TienDoNgay t) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_khoa(t.ngay), jsonEncode(t.toJson()));
    if (t.daXong) {
      final ds = p.getStringList(_khoaXong) ?? [];
      if (!ds.contains(t.ngay)) {
        ds.add(t.ngay);
        // Giữ khoảng một năm gần nhất là đủ tính chuỗi ngày
        await p.setStringList(_khoaXong, ds.length > 400 ? ds.sublist(ds.length - 400) : ds);
      }
    }
    // Bỏ tiến độ của các ngày cũ (chỉ giữ ngày đang chơi), danh sách ngày xong vẫn còn
    for (final k in p.getKeys().toList()) {
      if (k.startsWith('o_chu_ngay_') && k != _khoaXong && k != _khoa(t.ngay)) await p.remove(k);
    }
  }
}
