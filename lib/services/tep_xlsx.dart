import 'dart:convert';

import 'package:archive/archive.dart';

String _xml(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');

String _cot(int i) {
  var s = '';
  var n = i + 1;
  while (n > 0) {
    final r = (n - 1) % 26;
    s = String.fromCharCode(65 + r) + s;
    n = (n - 1) ~/ 26;
  }
  return s;
}

/// Tạo tệp Excel (.xlsx) một trang từ bảng chữ. Dòng đầu in đậm (tiêu đề cột), [doRong] là độ rộng từng cột.
/// Mở được bằng Excel, Google Trang tính, WPS; mọi ô là chữ để giữ nguyên số 0 đầu, ngày tháng.
List<int> taoXlsx(List<List<String>> bang, {String tenTrang = 'Trang1', List<double>? doRong}) {
  final dong = StringBuffer();
  for (var r = 0; r < bang.length; r++) {
    dong.write('<row r="${r + 1}">');
    for (var c = 0; c < bang[r].length; c++) {
      final kieu = r == 0 ? ' s="1"' : ' s="2"';
      dong.write('<c r="${_cot(c)}${r + 1}" t="inlineStr"$kieu><is><t xml:space="preserve">${_xml(bang[r][c])}</t></is></c>');
    }
    dong.write('</row>');
  }
  final cols = doRong == null || doRong.isEmpty
      ? ''
      : '<cols>${[for (var i = 0; i < doRong.length; i++) '<col min="${i + 1}" max="${i + 1}" width="${doRong[i]}" customWidth="1"/>'].join()}</cols>';
  final sheet = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '<sheetViews><sheetView workbookViewId="0"><pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews>'
      '$cols<sheetData>$dong</sheetData></worksheet>';
  final ten = _xml(tenTrang.length > 31 ? tenTrang.substring(0, 31) : tenTrang);
  final workbook = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
      'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
      '<sheets><sheet name="$ten" sheetId="1" r:id="rId1"/></sheets></workbook>';
  // Kiểu 1: tiêu đề đậm, có viền, xuống dòng; kiểu 2: có viền, xuống dòng, canh trên
  const styles = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '<fonts count="2"><font><sz val="12"/><name val="Times New Roman"/></font><font><b/><sz val="12"/><name val="Times New Roman"/></font></fonts>'
      '<fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills>'
      '<borders count="2"><border><left/><right/><top/><bottom/><diagonal/></border>'
      '<border><left style="thin"/><right style="thin"/><top style="thin"/><bottom style="thin"/><diagonal/></border></borders>'
      '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
      '<cellXfs count="3"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
      '<xf numFmtId="49" fontId="1" fillId="0" borderId="1" xfId="0" applyFont="1" applyBorder="1" applyAlignment="1"><alignment horizontal="center" vertical="center" wrapText="1"/></xf>'
      '<xf numFmtId="49" fontId="0" fillId="0" borderId="1" xfId="0" applyBorder="1" applyAlignment="1"><alignment vertical="top" wrapText="1"/></xf></cellXfs>'
      '</styleSheet>';
  const types = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
      '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
      '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
      '</Types>';
  const rels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
      '</Relationships>';
  const wbRels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>'
      '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
      '</Relationships>';
  final a = Archive();
  void them(String ten, String noiDung) {
    final bytes = utf8.encode(noiDung);
    a.addFile(ArchiveFile(ten, bytes.length, bytes));
  }

  them('[Content_Types].xml', types);
  them('_rels/.rels', rels);
  them('xl/workbook.xml', workbook);
  them('xl/_rels/workbook.xml.rels', wbRels);
  them('xl/styles.xml', styles);
  them('xl/worksheets/sheet1.xml', sheet);
  final List<int>? z = ZipEncoder().encode(a);
  return z ?? <int>[];
}
