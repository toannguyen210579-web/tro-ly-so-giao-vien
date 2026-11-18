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

/// Tách chữ nhận được thành đoạn: dòng trống ngăn đoạn, các dòng liền nhau trong một đoạn được nối lại.
List<String> tachDoan(String chu) {
  final kq = <String>[];
  for (final khoi in chu.split(RegExp(r'\n\s*\n'))) {
    final t = khoi.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).join(' ');
    if (t.isNotEmpty) kq.add(t);
  }
  return kq;
}
