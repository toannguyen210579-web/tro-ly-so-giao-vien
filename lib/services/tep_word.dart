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

/// Tệp Word biên bản cuộc họp (thầy cô yêu cầu 24/11/2026: bấm Lưu biên bản là có tệp Word để sửa tiếp):
/// đầu văn bản hai cột không kẻ (tên đơn vị bên trái; quốc hiệu, tiêu ngữ, địa danh ngày tháng bên phải),
/// tên biên bản ở giữa, các đoạn nội dung, chữ ký hai bên. [doan]: (nội dung, in đậm).
List<int> taoDocxBienBan({
  required String donViTren,
  required String donVi,
  required String ngayThang,
  required String tieuDe,
  required List<String> phuDe,
  required List<(String, bool)> doan,
  required List<(String, String)> kyTen,
}) {
  const rongTrang = 9354;
  String run(String t, {bool dam = false, bool nghieng = false, int co = 26}) =>
      '<w:r><w:rPr><w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman" w:cs="Times New Roman"/>'
      '${dam ? '<w:b/>' : ''}${nghieng ? '<w:i/>' : ''}<w:sz w:val="$co"/><w:szCs w:val="$co"/></w:rPr>'
      '<w:t xml:space="preserve">${_xml(t)}</w:t></w:r>';
  String p(String t, {String jc = 'both', bool dam = false, bool nghieng = false, int co = 26, int sau = 80, int truoc = 0}) =>
      '<w:p><w:pPr><w:jc w:val="$jc"/><w:spacing w:before="$truoc" w:after="$sau" w:line="300" w:lineRule="auto"/></w:pPr>'
      '${run(t, dam: dam, nghieng: nghieng, co: co)}</w:p>';
  // Đường kẻ ngắn dưới tên đơn vị, dưới tiêu ngữ: đoạn trống có viền dưới, thụt hai bên
  String gach(int thut) => '<w:p><w:pPr><w:pBdr><w:bottom w:val="single" w:sz="6" w:space="1" w:color="000000"/></w:pBdr>'
      '<w:spacing w:before="0" w:after="120"/><w:ind w:left="$thut" w:right="$thut"/></w:pPr></w:p>';
  String o(int rong, String noiDung) =>
      '<w:tc><w:tcPr><w:tcW w:w="$rong" w:type="dxa"/></w:tcPr>$noiDung</w:tc>';
  const khongVien = '<w:tblBorders><w:top w:val="nil"/><w:left w:val="nil"/><w:bottom w:val="nil"/><w:right w:val="nil"/>'
      '<w:insideH w:val="nil"/><w:insideV w:val="nil"/></w:tblBorders>';
  String bang(List<int> cot, List<String> cacO) => '<w:tbl><w:tblPr><w:tblW w:w="$rongTrang" w:type="dxa"/>$khongVien'
      '<w:tblLayout w:type="fixed"/></w:tblPr><w:tblGrid>${cot.map((w) => '<w:gridCol w:w="$w"/>').join()}</w:tblGrid>'
      '<w:tr>${[for (var i = 0; i < cot.length; i++) o(cot[i], cacO[i])].join()}</w:tr></w:tbl>';

  final trai = StringBuffer();
  if (donViTren.isNotEmpty) trai.write(p(donViTren.toUpperCase(), jc: 'center', co: 25, sau: 0));
  trai
    ..write(p(donVi.toUpperCase(), jc: 'center', dam: true, co: 25, sau: 0))
    ..write(gach(1100));
  final phai = StringBuffer()
    ..write(p('CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM', jc: 'center', dam: true, co: 25, sau: 0))
    ..write(p('Độc lập - Tự do - Hạnh phúc', jc: 'center', dam: true, sau: 0))
    ..write(gach(1300))
    ..write(p(ngayThang, jc: 'center', nghieng: true, sau: 0));
  final b = StringBuffer()..write(bang([3900, rongTrang - 3900], [trai.toString(), phai.toString()]));
  b.write(p(tieuDe, jc: 'center', dam: true, co: 28, truoc: 240, sau: 0));
  for (final d in phuDe) {
    b.write(p(d, jc: 'center', dam: true, sau: 0));
  }
  b.write(p('', sau: 120));
  for (final (t, dam) in doan) {
    b.write(p(t, dam: dam));
  }
  b.write(p('', sau: 120));
  final rong = rongTrang ~/ kyTen.length;
  b.write(bang([for (final _ in kyTen) rong], [
    for (final (chuc, ten) in kyTen)
      p(chuc, jc: 'center', dam: true, sau: 0) +
          p('(Ký, ghi rõ họ tên)', jc: 'center', nghieng: true, co: 22, sau: 1300) +
          p(ten, jc: 'center', dam: true, sau: 0),
  ]));
  return _dongGoiDocx(b.toString());
}

/// Phiếu xếp loại chất lượng viên chức theo mẫu Phụ lục II Nghị định 233/2026/NĐ-CP.
/// [mucTu]: mức viên chức tự xếp loại (0 xuất sắc ... 3 không hoàn thành; null là chưa đánh dấu).
/// Mục III, IV và chữ ký cấp có thẩm quyền để trống cho nhà trường điền.
List<int> taoDocxPhieuXepLoai({
  required String coQuanTren,
  required String donVi,
  required String nam,
  required String hoTen,
  required String chucDanh,
  required String donViCongTac,
  required String diemChung,
  required String diemNhiemVu,
  required String tongDiem,
  required String uuDiem,
  required String hanChe,
  required List<String> mucXepLoai,
  required int? mucTu,
}) {
  const rongTrang = 9354;
  String run(String t, {bool dam = false, bool nghieng = false, int co = 26}) =>
      '<w:r><w:rPr><w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman" w:cs="Times New Roman" w:eastAsia="Times New Roman"/>'
      '${dam ? '<w:b/>' : ''}${nghieng ? '<w:i/>' : ''}<w:sz w:val="$co"/><w:szCs w:val="$co"/></w:rPr>'
      '<w:t xml:space="preserve">${_xml(t)}</w:t></w:r>';
  String p(String t, {String jc = 'both', bool dam = false, bool nghieng = false, int co = 26, int sau = 80, int truoc = 0, int thut = 0}) =>
      '<w:p><w:pPr><w:jc w:val="$jc"/><w:spacing w:before="$truoc" w:after="$sau" w:line="300" w:lineRule="auto"/>'
      '${thut > 0 ? '<w:ind w:left="$thut"/>' : ''}</w:pPr>${run(t, dam: dam, nghieng: nghieng, co: co)}</w:p>';
  // Đoạn có nhãn đậm, nội dung thường
  String pNhan(String nhan, String noiDung, {int thut = 0}) =>
      '<w:p><w:pPr><w:jc w:val="both"/><w:spacing w:before="0" w:after="80" w:line="300" w:lineRule="auto"/>'
      '${thut > 0 ? '<w:ind w:left="$thut"/>' : ''}</w:pPr>${run(nhan, dam: true)}${run(noiDung)}</w:p>';
  String gach(int thut) => '<w:p><w:pPr><w:pBdr><w:bottom w:val="single" w:sz="6" w:space="1" w:color="000000"/></w:pBdr>'
      '<w:spacing w:before="0" w:after="120"/><w:ind w:left="$thut" w:right="$thut"/></w:pPr></w:p>';
  const khongVien = '<w:tblBorders><w:top w:val="nil"/><w:left w:val="nil"/><w:bottom w:val="nil"/><w:right w:val="nil"/>'
      '<w:insideH w:val="nil"/><w:insideV w:val="nil"/></w:tblBorders>';
  String bang(List<int> cot, List<String> cacO) => '<w:tbl><w:tblPr><w:tblW w:w="$rongTrang" w:type="dxa"/>$khongVien'
      '<w:tblLayout w:type="fixed"/></w:tblPr><w:tblGrid>${cot.map((w) => '<w:gridCol w:w="$w"/>').join()}</w:tblGrid>'
      '<w:tr>${[for (var i = 0; i < cot.length; i++) '<w:tc><w:tcPr><w:tcW w:w="${cot[i]}" w:type="dxa"/></w:tcPr>${cacO[i]}</w:tc>'].join()}</w:tr></w:tbl>';
  String dongCham(int soDong) => [for (var i = 0; i < soDong; i++) p('.' * 110, sau: 40, co: 24)].join();
  String doanHoacCham(String t, int soDong) {
    final ds = t.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    return ds.isEmpty ? dongCham(soDong) : ds.map((e) => p(e, thut: 360)).join();
  }

  final trai = StringBuffer();
  if (coQuanTren.trim().isNotEmpty) trai.write(p(coQuanTren.trim().toUpperCase(), jc: 'center', co: 25, sau: 0));
  trai
    ..write(p((donVi.trim().isEmpty ? 'TÊN CƠ QUAN, TỔ CHỨC, ĐƠN VỊ' : donVi.trim()).toUpperCase(), jc: 'center', dam: true, co: 25, sau: 0))
    ..write(gach(1100));
  final phai = StringBuffer()
    ..write(p('CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM', jc: 'center', dam: true, co: 25, sau: 0))
    ..write(p('Độc lập - Tự do - Hạnh phúc', jc: 'center', dam: true, sau: 0))
    ..write(gach(1300));
  final b = StringBuffer()..write(bang([3900, rongTrang - 3900], [trai.toString(), phai.toString()]));
  b
    ..write(p('PHIẾU XẾP LOẠI CHẤT LƯỢNG VIÊN CHỨC', jc: 'center', dam: true, co: 28, truoc: 240, sau: 0))
    ..write(p(nam, jc: 'center', dam: true, sau: 200))
    ..write(pNhan('Họ và tên: ', hoTen.isEmpty ? '.' * 70 : hoTen))
    ..write(pNhan('Chức vụ, chức danh: ', chucDanh.isEmpty ? '.' * 60 : chucDanh))
    ..write(pNhan('Đơn vị công tác: ', donViCongTac.isEmpty ? '.' * 64 : donViCongTac))
    ..write(p('I. TỔNG HỢP KẾT QUẢ THEO DÕI, ĐÁNH GIÁ', dam: true, truoc: 120))
    ..write(pNhan('1. Kết quả theo dõi, đánh giá theo tiêu chí chung (tối đa 30 điểm): ', diemChung))
    ..write(pNhan('2. Kết quả theo dõi, đánh giá theo tiêu chí kết quả thực hiện nhiệm vụ (tối đa 70 điểm): ', diemNhiemVu))
    ..write(pNhan('3. Tổng điểm theo dõi, đánh giá trong năm: ', tongDiem))
    ..write(p('4. Ưu điểm:', dam: true))
    ..write(doanHoacCham(uuDiem, 4))
    ..write(p('5. Hạn chế:', dam: true))
    ..write(doanHoacCham(hanChe, 4))
    ..write(p('II. VIÊN CHỨC TỰ ĐÁNH GIÁ, XẾP LOẠI CHẤT LƯỢNG', dam: true, truoc: 120));
  for (var i = 0; i < mucXepLoai.length; i++) {
    b.write(p('${mucTu == i ? '☒' : '☐'} ${mucXepLoai[i]}', thut: 360, sau: 40));
  }
  b.write(p('III. KẾT QUẢ XẾP LOẠI CHẤT LƯỢNG VIÊN CHỨC CỦA CẤP CÓ THẨM QUYỀN', dam: true, truoc: 120));
  for (final m in mucXepLoai) {
    b.write(p('☐ $m', thut: 360, sau: 40));
  }
  b
    ..write(p('IV. Ý KIẾN NHẬN XÉT CỦA CẤP CÓ THẨM QUYỀN VÀ ĐỀ XUẤT PHƯƠNG ÁN XỬ LÝ(1)', dam: true, truoc: 120))
    ..write(dongCham(4))
    ..write(p('', sau: 120));
  String ky(String chuc, String ten) =>
      p('......, ngày .... tháng .... năm ......', jc: 'center', nghieng: true, sau: 0) +
      p(chuc, jc: 'center', dam: true, sau: 0) +
      p('(Ký tên, ghi rõ họ tên)', jc: 'center', nghieng: true, co: 22, sau: 1300) +
      p(ten, jc: 'center', dam: true, sau: 0);
  b
    ..write(bang([rongTrang ~/ 2, rongTrang - rongTrang ~/ 2], [ky('VIÊN CHỨC TỰ XẾP LOẠI', hoTen), ky('CẤP CÓ THẨM QUYỀN XẾP LOẠI', '')]))
    ..write(p('', sau: 120))
    ..write(p('(1) Việc đề xuất phương án xử lý căn cứ quy định tại Điều 16 Nghị định số 233/2026/NĐ-CP.', nghieng: true, co: 22));
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
