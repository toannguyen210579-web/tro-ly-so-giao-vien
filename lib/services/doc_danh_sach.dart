import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';

/// Đọc danh sách họ tên học sinh từ tệp Excel (.xlsx) hoặc .csv/.txt.
/// Tự tìm cột có tiêu đề "Họ và tên", "Họ tên", "Tên học sinh"; tệp chia "Họ đệm" và "Tên" thì ghép lại.
/// Không có tiêu đề thì lấy cột có nhiều ô dạng họ tên nhất.
/// Trả về danh sách rỗng nếu không đọc được.
Future<List<String>> docDanhSachHocSinh(String duongDan) async {
  final duoi = duongDan.toLowerCase();
  List<List<String>> bang;
  if (duoi.endsWith('.xlsx')) {
    bang = _docXlsx(await File(duongDan).readAsBytes());
  } else {
    final chu = utf8.decode(await File(duongDan).readAsBytes(), allowMalformed: true);
    final ngan = chu.contains('\t') ? '\t' : (chu.contains(';') ? ';' : ',');
    bang = chu.split(RegExp(r'\r?\n')).map((d) => d.split(ngan).map((o) => o.replaceAll('"', '').trim()).toList()).toList();
  }
  return _layHoTen(bang);
}

String _boDau(String s) {
  const co = 'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
  const khong = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
  final b = StringBuffer();
  for (final c in s.toLowerCase().split('')) {
    final i = co.indexOf(c);
    b.write(i >= 0 ? khong[i] : c);
  }
  return b.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

List<String> _layHoTen(List<List<String>> bang) {
  // Tìm dòng tiêu đề trong 15 dòng đầu
  for (var r = 0; r < bang.length && r < 15; r++) {
    final dong = bang[r].map(_boDau).toList();
    int cotHoTen = dong.indexWhere((o) => o == 'ho va ten' || o == 'ho ten' || o == 'ten hoc sinh' || o == 'ho va ten hoc sinh');
    final cotHoDem = dong.indexWhere((o) => o == 'ho dem' || o == 'ho va ten dem' || o == 'ho');
    final cotTen = dong.indexWhere((o) => o == 'ten');
    if (cotHoTen < 0 && cotHoDem >= 0 && cotTen >= 0) {
      return [
        for (final d in bang.skip(r + 1))
          if (_o(d, cotTen).isNotEmpty) '${_o(d, cotHoDem)} ${_o(d, cotTen)}'.trim(),
      ];
    }
    if (cotHoTen >= 0) {
      return [for (final d in bang.skip(r + 1)) if (_laHoTen(_o(d, cotHoTen))) _o(d, cotHoTen)];
    }
  }
  // Không có tiêu đề: chọn cột có nhiều ô giống họ tên nhất
  final soCot = bang.fold<int>(0, (m, d) => d.length > m ? d.length : m);
  var tot = -1, diem = 0;
  for (var c = 0; c < soCot; c++) {
    final n = bang.where((d) => _laHoTen(_o(d, c))).length;
    if (n > diem) {
      diem = n;
      tot = c;
    }
  }
  if (tot < 0) return [];
  return [for (final d in bang) if (_laHoTen(_o(d, tot))) _o(d, tot)];
}

String _o(List<String> d, int c) => c < d.length ? d[c].trim() : '';

bool _laHoTen(String s) {
  if (s.length < 3 || s.length > 60) return false;
  if (RegExp(r'\d').hasMatch(s)) return false;
  final tu = s.split(RegExp(r'\s+'));
  return tu.length >= 2 && tu.length <= 6;
}

/// Đọc trang tính đầu tiên của tệp .xlsx (tệp nén chứa XML).
List<List<String>> _docXlsx(List<int> byte) {
  final kho = ZipDecoder().decodeBytes(byte);
  String doc(String ten) {
    final f = kho.findFile(ten);
    return f == null ? '' : utf8.decode(f.content as List<int>, allowMalformed: true);
  }

  String giaiMa(String s) => s
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&amp;', '&');

  // Chuỗi dùng chung
  final chung = <String>[];
  for (final si in RegExp(r'<si>(.*?)</si>', dotAll: true).allMatches(doc('xl/sharedStrings.xml'))) {
    chung.add(giaiMa(RegExp(r'<t[^>]*>(.*?)</t>', dotAll: true).allMatches(si.group(1)!).map((m) => m.group(1)!).join()));
  }

  var trang = doc('xl/worksheets/sheet1.xml');
  if (trang.isEmpty) {
    final ten = kho.files.map((f) => f.name).where((n) => n.startsWith('xl/worksheets/sheet')).toList()..sort();
    if (ten.isNotEmpty) trang = doc(ten.first);
  }

  int cot(String ref) {
    var n = 0;
    for (final c in RegExp(r'^[A-Z]+').firstMatch(ref)!.group(0)!.codeUnits) {
      n = n * 26 + (c - 64);
    }
    return n - 1;
  }

  final bang = <List<String>>[];
  for (final row in RegExp(r'<row[^>]*>(.*?)</row>', dotAll: true).allMatches(trang)) {
    final dong = <String>[];
    for (final c in RegExp(r'<c ([^>]*?)(?:/>|>(.*?)</c>)', dotAll: true).allMatches(row.group(1)!)) {
      final thuoc = c.group(1)!;
      final ref = RegExp(r'r="([A-Z]+)\d+"').firstMatch(thuoc)?.group(1);
      final kieu = RegExp(r't="(\w+)"').firstMatch(thuoc)?.group(1);
      final than = c.group(2) ?? '';
      var gt = '';
      if (kieu == 'inlineStr') {
        gt = RegExp(r'<t[^>]*>(.*?)</t>', dotAll: true).allMatches(than).map((m) => m.group(1)!).join();
      } else {
        final v = RegExp(r'<v>(.*?)</v>', dotAll: true).firstMatch(than)?.group(1) ?? '';
        gt = kieu == 's' ? (int.tryParse(v) != null && int.parse(v) < chung.length ? chung[int.parse(v)] : '') : v;
      }
      final i = ref == null ? dong.length : cot(ref);
      while (dong.length < i) {
        dong.add('');
      }
      if (dong.length == i) {
        dong.add(giaiMa(gt).trim());
      } else {
        dong[i] = giaiMa(gt).trim();
      }
    }
    bang.add(dong);
  }
  return bang;
}
