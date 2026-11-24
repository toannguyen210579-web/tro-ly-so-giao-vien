import 'dart:convert';

import 'package:archive/archive.dart';

String _xml(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

/// Tạo tệp Word (.docx) đơn giản từ các đoạn văn: phông Times New Roman 13, lề theo văn bản hành chính.
List<int> taoDocx(List<String> doan, {String? tieuDe}) {
  final b = StringBuffer();
  String p(String t, {bool dam = false, bool giua = false, int co = 26}) =>
      '<w:p><w:pPr>${giua ? '<w:jc w:val="center"/>' : '<w:jc w:val="both"/>'}<w:spacing w:after="120" w:line="300" w:lineRule="auto"/></w:pPr>'
      '<w:r><w:rPr><w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman" w:cs="Times New Roman"/>'
      '${dam ? '<w:b/>' : ''}<w:sz w:val="$co"/><w:szCs w:val="$co"/></w:rPr>'
      '<w:t xml:space="preserve">${_xml(t)}</w:t></w:r></w:p>';
  if (tieuDe != null && tieuDe.trim().isNotEmpty) b.write(p(tieuDe.trim(), dam: true, giua: true, co: 28));
  for (final d in doan) {
    b.write(p(d));
  }
  final document = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>$b'
      '<w:sectPr><w:pgSz w:w="11906" w:h="16838"/>'
      '<w:pgMar w:top="1134" w:right="851" w:bottom="1134" w:left="1701" w:header="720" w:footer="720" w:gutter="0"/></w:sectPr>'
      '</w:body></w:document>';
  const types = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
      '</Types>';
  const rels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
      '</Relationships>';
  final a = Archive();
  void them(String ten, String noiDung) {
    final bytes = utf8.encode(noiDung);
    a.addFile(ArchiveFile(ten, bytes.length, bytes));
  }

  them('[Content_Types].xml', types);
  them('_rels/.rels', rels);
  them('word/document.xml', document);
  // Chạy được với cả archive 3.x (trả về kiểu có thể null) và 4.x.
  final List<int>? z = ZipEncoder().encode(a);
  return z ?? <int>[];
}

/// Tạo tệp Word có tiêu đề, các dòng đầu, một bảng kẻ ô và các dòng cuối (dùng cho bảng lương).
/// [doRong]: độ rộng từng cột theo phần nghìn bề ngang trang (tổng 1000). [canPhai]: cột căn phải (số tiền).
/// [dongDam]: số thứ tự dòng in đậm (0 là dòng tiêu đề cột, luôn đậm).
List<int> taoDocxBang({
  required String tieuDe,
  String? phuDe,
  List<String> dongDau = const [],
  required List<List<String>> bang,
  required List<int> doRong,
  Set<int> canPhai = const {},
  Set<int> dongDam = const {},
  List<String> dongCuoi = const [],
}) {
  const rongTrang = 9354; // A4 trừ lề trái 3 cm, lề phải 1,5 cm (đơn vị 1/20 điểm)
  final cot = [for (final r in doRong) (rongTrang * r / 1000).round()];
  String run(String t, {bool dam = false, bool nghieng = false, int co = 26}) =>
      '<w:r><w:rPr><w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman" w:cs="Times New Roman"/>'
      '${dam ? '<w:b/>' : ''}${nghieng ? '<w:i/>' : ''}<w:sz w:val="$co"/><w:szCs w:val="$co"/></w:rPr>'
      '<w:t xml:space="preserve">${_xml(t)}</w:t></w:r>';
  String p(String t, {String jc = 'both', bool dam = false, bool nghieng = false, int co = 26, int sau = 120}) =>
      '<w:p><w:pPr><w:jc w:val="$jc"/><w:spacing w:before="0" w:after="$sau" w:line="276" w:lineRule="auto"/></w:pPr>'
      '${run(t, dam: dam, nghieng: nghieng, co: co)}</w:p>';
  final b = StringBuffer()
    ..write(p(tieuDe, jc: 'center', dam: true, co: 28, sau: phuDe == null ? 200 : 60));
  if (phuDe != null) b.write(p(phuDe, jc: 'center', nghieng: true, co: 24, sau: 200));
  for (final d in dongDau) {
    b.write(p(d, jc: 'left', sau: 60));
  }
  const vien = '<w:top w:val="single" w:sz="4" w:space="0" w:color="000000"/>'
      '<w:left w:val="single" w:sz="4" w:space="0" w:color="000000"/>'
      '<w:bottom w:val="single" w:sz="4" w:space="0" w:color="000000"/>'
      '<w:right w:val="single" w:sz="4" w:space="0" w:color="000000"/>'
      '<w:insideH w:val="single" w:sz="4" w:space="0" w:color="000000"/>'
      '<w:insideV w:val="single" w:sz="4" w:space="0" w:color="000000"/>';
  b.write('<w:p><w:pPr><w:spacing w:before="0" w:after="60"/></w:pPr></w:p>');
  b.write('<w:tbl><w:tblPr><w:tblW w:w="$rongTrang" w:type="dxa"/><w:tblBorders>$vien</w:tblBorders>'
      '<w:tblLayout w:type="fixed"/><w:tblCellMar><w:left w:w="80" w:type="dxa"/><w:right w:w="80" w:type="dxa"/></w:tblCellMar></w:tblPr>');
  b.write('<w:tblGrid>${cot.map((w) => '<w:gridCol w:w="$w"/>').join()}</w:tblGrid>');
  for (var i = 0; i < bang.length; i++) {
    b.write('<w:tr>');
    for (var j = 0; j < cot.length; j++) {
      final t = j < bang[i].length ? bang[i][j] : '';
      final jc = i == 0 ? 'center' : (canPhai.contains(j) ? 'right' : 'left');
      b.write('<w:tc><w:tcPr><w:tcW w:w="${cot[j]}" w:type="dxa"/><w:vAlign w:val="center"/></w:tcPr>'
          '<w:p><w:pPr><w:jc w:val="$jc"/><w:spacing w:before="40" w:after="40"/></w:pPr>'
          '${run(t, dam: i == 0 || dongDam.contains(i))}</w:p></w:tc>');
    }
    b.write('</w:tr>');
  }
  b.write('</w:tbl>');
  b.write('<w:p><w:pPr><w:spacing w:before="0" w:after="60"/></w:pPr></w:p>');
  for (final d in dongCuoi) {
    b.write(p(d, nghieng: true, co: 24, sau: 60));
  }
  return _dongGoiDocx(b.toString());
}

/// Gói phần thân văn bản thành tệp .docx (A4, lề văn bản hành chính).
List<int> _dongGoiDocx(String than) {
  final document = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>$than'
      '<w:sectPr><w:pgSz w:w="11906" w:h="16838"/>'
      '<w:pgMar w:top="1134" w:right="851" w:bottom="1134" w:left="1701" w:header="720" w:footer="720" w:gutter="0"/></w:sectPr>'
      '</w:body></w:document>';
  const types = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
      '</Types>';
  const rels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
      '</Relationships>';
  final a = Archive();
  void them(String ten, String noiDung) {
    final bytes = utf8.encode(noiDung);
    a.addFile(ArchiveFile(ten, bytes.length, bytes));
  }

  them('[Content_Types].xml', types);
  them('_rels/.rels', rels);
  them('word/document.xml', document);
  final List<int>? z = ZipEncoder().encode(a);
  return z ?? <int>[];
}

/// Tách chữ nhận được thành đoạn: dòng trống ngăn đoạn, các dòng liền nhau trong một đoạn được nối lại.
List<String> tachDoan(String chu) {
  final kq = <String>[];
  for (final khoi in chu.split(RegExp(r'\n\s*\n'))) {
    final t = khoi.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).join(' ');
    if (t.isNotEmpty) kq.add(t);
  }
  return kq;
}
