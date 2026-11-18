import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;

/// Phông chữ có dấu tiếng Việt cho tệp PDF (đóng gói sẵn trong app).
class PhongPdf {
  static pw.ThemeData? _theme;

  static Future<pw.ThemeData> theme() async {
    if (_theme != null) return _theme!;
    Future<pw.Font> tai(String ten) async => pw.Font.ttf(await rootBundle.load('assets/fonts/$ten'));
    _theme = pw.ThemeData.withFont(
      base: await tai('DejaVuSerif.ttf'),
      bold: await tai('DejaVuSerif-Bold.ttf'),
      italic: await tai('DejaVuSerif-Italic.ttf'),
    );
    return _theme!;
  }
}

/// Thư mục con trong vùng lưu của app.
Future<Directory> thuMucApp(String ten) async {
  final goc = await getApplicationDocumentsDirectory();
  final d = Directory('${goc.path}/$ten');
  if (!await d.exists()) await d.create(recursive: true);
  return d;
}

String hai(int n) => n.toString().padLeft(2, '0');

String ngayVN(DateTime d) => '${hai(d.day)}/${hai(d.month)}/${d.year}';

String dauThoiGian(DateTime d) =>
    '${d.year}${hai(d.month)}${hai(d.day)}_${hai(d.hour)}${hai(d.minute)}${hai(d.second)}';

/// Bỏ dấu và ký tự lạ để làm tên tệp.
String tenTep(String s) {
  const co = 'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
  const khong = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
  final b = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    final i = co.indexOf(ch);
    b.write(i >= 0 ? khong[i] : ch);
  }
  return b
      .toString()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
}
