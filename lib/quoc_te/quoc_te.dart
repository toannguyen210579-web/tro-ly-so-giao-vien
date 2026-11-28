import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ngon_ngu.dart';

/// Bản quốc tế của app: đóng gói với `--dart-define=QUOC_TE=true`.
/// Bản Việt (mặc định) không đổi gì.
const bool quocTe = bool.fromEnvironment('QUOC_TE');

/// Tên tạm của bản quốc tế (chưa chốt tên trên kho ứng dụng).
const tenAppQuocTe = 'Classroom Kit';

/// Thứ tiếng đang dùng. Đổi giá trị là các màn bản quốc tế vẽ lại.
final ValueNotifier<String> tieng = ValueNotifier<String>('en');

/// Chọn tiếng theo máy: đúng mã thì dùng, không có thì tiếng Anh.
String tiengTheoMay(List<Locale> ds) {
  for (final l in ds) {
    if (bangChu.containsKey(l.languageCode)) return l.languageCode;
  }
  return 'en';
}

/// Đọc tiếng đã chọn lần trước; chưa chọn thì theo tiếng của máy.
Future<void> taiTieng() async {
  final p = await SharedPreferences.getInstance();
  final da = p.getString('qt_tieng');
  tieng.value = (da != null && bangChu.containsKey(da))
      ? da
      : tiengTheoMay(WidgetsBinding.instance.platformDispatcher.locales);
}

Future<void> datTieng(String ma) async {
  if (!bangChu.containsKey(ma)) return;
  tieng.value = ma;
  final p = await SharedPreferences.getInstance();
  await p.setString('qt_tieng', ma);
}

/// Lấy chữ theo khóa; thiếu thì lấy tiếng Anh; [n] thay vào chỗ {n}.
String chu(String khoa, {Object? n, String? ma}) {
  final s = bangChu[ma ?? tieng.value]?[khoa] ?? bangChu['en']![khoa] ?? khoa;
  return n == null ? s : s.replaceAll('{n}', '$n');
}

/// Danh sách lớp của bản quốc tế: chỉ lưu trên máy.
class LopQT {
  static Future<List<String>> doc() async {
    final p = await SharedPreferences.getInstance();
    return p.getStringList('qt_lop') ?? <String>[];
  }

  static Future<void> ghi(List<String> ten) async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList('qt_lop', ten);
  }

  /// Tách chữ dán vào thành danh sách tên: mỗi dòng một tên, bỏ dòng trống, bỏ tên trùng.
  static List<String> tach(String s) {
    final kq = <String>[];
    for (final d in const LineSplitter().convert(s)) {
      final t = d.trim();
      if (t.isNotEmpty && !kq.contains(t)) kq.add(t);
    }
    return kq;
  }
}

/// Bảng điểm đội: lưu trên máy.
class DiemDoiQT {
  static Future<List<int>> doc() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString('qt_diem');
    if (s == null) return [0, 0];
    return (jsonDecode(s) as List<dynamic>).map((e) => e as int).toList();
  }

  static Future<void> ghi(List<int> d) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('qt_diem', jsonEncode(d));
  }
}
