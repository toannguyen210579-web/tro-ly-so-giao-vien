import 'dart:convert';

import 'package:archive/archive.dart';

/// Tệp Word văn bản Đảng theo thể thức Hướng dẫn 05-HD/VPTW ngày 27/5/2026 của Văn phòng Trung ương:
/// Times New Roman; lề trên 20, dưới 20, trái 30, phải 15 mm; dãn dòng đúng 20pt; cách đoạn 6pt;
/// đầu đoạn lùi 10 mm; số trang giữa lề trên, ẩn ở trang 1.

String _xml(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');

/// Một đoạn chữ trong văn bản
class DoanDang {
  final String chu;
  final bool dam;
  final bool nghieng;
  final bool giua;
  final bool thutDau;
  final int co; // nửa điểm (28 = cỡ 14)
  const DoanDang(this.chu, {this.dam = false, this.nghieng = false, this.giua = false, this.thutDau = true, this.co = 28});
}

/// Khối ký: quyền hạn (đậm), chức vụ (không đậm), họ tên (đậm)
class KhoiKy {
  final String quyenHan;
  final String chucVu;
  final String hoTen;
  const KhoiKy({this.quyenHan = '', required this.chucVu, required this.hoTen});
}

class VanBanDang {
  final String capTren; // ĐẢNG BỘ ... (cấp trên trực tiếp)
  final String coQuan; // CHI BỘ ...
  final String soKyHieu; // Số 05-NQ/CB (để trống thì ghi "Số    -NQ/CB")
  final String diaDanhNgay; // Đắk Lắk, ngày 05 tháng 02 năm 2026
  final String tenLoai; // NGHỊ QUYẾT, BIÊN BẢN
  final String trichYeu; // về ..., sinh hoạt chi bộ tháng ...
  final List<DoanDang> noiDung;
  final KhoiKy kyPhai;
  final KhoiKy? kyTrai; // biên bản: thư ký bên trái
  final List<String> noiNhan; // để trống thì không có phần nơi nhận
  const VanBanDang({
    required this.capTren,
    required this.coQuan,
    required this.soKyHieu,
    required this.diaDanhNgay,
    required this.tenLoai,
    required this.trichYeu,
    required this.noiDung,
    required this.kyPhai,
    this.kyTrai,
    this.noiNhan = const [],
  });
}

/// "Đắk Lắk, ngày 05 tháng 02 năm 2026": ngày dưới 10 và tháng dưới 3 thêm số 0
String ngayDang(String diaDanh, DateTime d) {
  final ngay = d.day < 10 ? '0${d.day}' : '${d.day}';
  final thang = d.month < 3 ? '0${d.month}' : '${d.month}';
  return '$diaDanh, ngày $ngay tháng $thang năm ${d.year}';
}

const _font = '<w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman" w:cs="Times New Roman"/>';

String _r(String t, {bool dam = false, bool nghieng = false, bool gach = false, int co = 28}) =>
    '<w:r><w:rPr>$_font${dam ? '<w:b/>' : ''}${nghieng ? '<w:i/>' : ''}${gach ? '<w:u w:val="single"/>' : ''}'
    '<w:sz w:val="$co"/><w:szCs w:val="$co"/></w:rPr><w:t xml:space="preserve">${_xml(t)}</w:t></w:r>';

String _p(String runs, {String jc = 'both', bool thut = false, int sau = 120, int dong = 400}) =>
    '<w:p><w:pPr><w:jc w:val="$jc"/><w:spacing w:before="0" w:after="$sau" w:line="$dong" w:lineRule="exact"/>'
    '${thut ? '<w:ind w:firstLine="567"/>' : ''}</w:pPr>$runs</w:p>';

String _o(String noiDung, int rong) =>
    '<w:tc><w:tcPr><w:tcW w:w="$rong" w:type="dxa"/></w:tcPr>$noiDung</w:tc>';

String _bang(List<String> o, List<int> rong) {
  final cot = rong.map((w) => '<w:gridCol w:w="$w"/>').join();
  final hang = [for (var i = 0; i < o.length; i++) _o(o[i], rong[i])].join();
  return '<w:tbl><w:tblPr><w:tblW w:w="${rong.reduce((a, b) => a + b)}" w:type="dxa"/><w:tblLayout w:type="fixed"/>'
      '<w:tblBorders><w:top w:val="nil"/><w:left w:val="nil"/><w:bottom w:val="nil"/><w:right w:val="nil"/>'
      '<w:insideH w:val="nil"/><w:insideV w:val="nil"/></w:tblBorders>'
      '<w:tblCellMar><w:left w:w="0" w:type="dxa"/><w:right w:w="0" w:type="dxa"/></w:tblCellMar></w:tblPr>'
      '<w:tblGrid>$cot</w:tblGrid><w:tr>$hang</w:tr></w:tbl>';
}

String _ky(KhoiKy k) {
  final b = StringBuffer();
  if (k.quyenHan.isNotEmpty) b.write(_p(_r(k.quyenHan.toUpperCase(), dam: true), jc: 'center', sau: 0, dong: 320));
  b.write(_p(_r(k.chucVu.toUpperCase()), jc: 'center', sau: 0, dong: 320));
  for (var i = 0; i < 4; i++) {
    b.write(_p('', jc: 'center', sau: 0, dong: 320));
  }
  b.write(_p(_r(k.hoTen, dam: true), jc: 'center', sau: 0, dong: 320));
  return b.toString();
}

/// Vùng trình bày rộng 165 mm (210 - 30 - 15) = 9356 twip
const _rongTrang = 9356;

List<int> taoDocxDang(VanBanDang v) {
  final b = StringBuffer();
  // Khối đầu: trái tên cơ quan, phải tiêu đề Đảng
  final trai = StringBuffer()
    ..write(_p(_r(v.capTren.toUpperCase()), jc: 'center', sau: 0, dong: 320))
    ..write(_p(_r(v.coQuan.toUpperCase(), dam: true), jc: 'center', sau: 0, dong: 320))
    ..write(_p(_r('*'), jc: 'center', sau: 0, dong: 320))
    ..write(_p(_r(v.soKyHieu), jc: 'center', sau: 0, dong: 320));
  final phai = StringBuffer()
    ..write(_p(_r('ĐẢNG CỘNG SẢN VIỆT NAM', dam: true, gach: true, co: 30), jc: 'center', sau: 120, dong: 320))
    ..write(_p(_r(v.diaDanhNgay, nghieng: true), jc: 'center', sau: 0, dong: 320));
  b.write(_bang([trai.toString(), phai.toString()], [4000, _rongTrang - 4000]));
  b.write(_p('', sau: 0, dong: 320));
  // Tên loại, trích yếu, 5 gạch nối
  b.write(_p(_r(v.tenLoai.toUpperCase(), dam: true, co: 32), jc: 'center', sau: 0, dong: 360));
  if (v.trichYeu.isNotEmpty) b.write(_p(_r(v.trichYeu, dam: true), jc: 'center', sau: 0, dong: 360));
  b.write(_p(_r('-----'), jc: 'center', sau: 120, dong: 360));
  // Nội dung
  for (final d in v.noiDung) {
    b.write(_p(_r(d.chu, dam: d.dam, nghieng: d.nghieng, co: d.co), jc: d.giua ? 'center' : 'both', thut: d.thutDau && !d.giua));
  }
  b.write(_p('', sau: 0, dong: 320));
  // Khối ký và nơi nhận
  if (v.kyTrai != null) {
    // Biên bản: người chủ trì bên phải, thư ký bên trái
    b.write(_bang([_ky(v.kyTrai!), _ky(v.kyPhai)], [_rongTrang ~/ 2, _rongTrang - _rongTrang ~/ 2]));
  } else {
    final nn = StringBuffer();
    if (v.noiNhan.isNotEmpty) {
      nn.write(_p(_r('Nơi nhận:', gach: true), jc: 'left', sau: 0, dong: 280));
      for (var i = 0; i < v.noiNhan.length; i++) {
        final cuoi = i == v.noiNhan.length - 1;
        var dong = v.noiNhan[i].trim().replaceAll(RegExp(r'[;.]$'), '');
        nn.write(_p(_r('- $dong${cuoi ? '.' : ';'}', co: 24), jc: 'left', sau: 0, dong: 280));
      }
    }
    b.write(_bang([nn.toString().isEmpty ? _p('') : nn.toString(), _ky(v.kyPhai)], [4600, _rongTrang - 4600]));
  }

  // Số trang giữa lề trên, ẩn ở trang 1
  const header = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<w:hdr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:p><w:pPr><w:jc w:val="center"/></w:pPr>'
      '<w:r><w:rPr>$_font<w:sz w:val="28"/></w:rPr><w:fldChar w:fldCharType="begin"/></w:r>'
      '<w:r><w:rPr>$_font<w:sz w:val="28"/></w:rPr><w:instrText xml:space="preserve"> PAGE </w:instrText></w:r>'
      '<w:r><w:rPr>$_font<w:sz w:val="28"/></w:rPr><w:fldChar w:fldCharType="end"/></w:r></w:p></w:hdr>';
  const headerTrong = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<w:hdr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:p/></w:hdr>';
  final document = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '
      'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><w:body>$b'
      '<w:sectPr><w:headerReference w:type="default" r:id="rId2"/><w:headerReference w:type="first" r:id="rId3"/>'
      '<w:pgSz w:w="11906" w:h="16838"/>'
      '<w:pgMar w:top="1134" w:right="851" w:bottom="1134" w:left="1701" w:header="567" w:footer="567" w:gutter="0"/>'
      '<w:titlePg/></w:sectPr></w:body></w:document>';
  const types = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
      '<Override PartName="/word/header1.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.header+xml"/>'
      '<Override PartName="/word/header2.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.header+xml"/>'
      '</Types>';
  const rels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
      '</Relationships>';
  const docRels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/header" Target="header1.xml"/>'
      '<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/header" Target="header2.xml"/>'
      '</Relationships>';
  final a = Archive();
  void them(String ten, String s) {
    final bytes = utf8.encode(s);
    a.addFile(ArchiveFile(ten, bytes.length, bytes));
  }

  them('[Content_Types].xml', types);
  them('_rels/.rels', rels);
  them('word/_rels/document.xml.rels', docRels);
  them('word/document.xml', document);
  them('word/header1.xml', header);
  them('word/header2.xml', headerTrong);
  final List<int>? z = ZipEncoder().encode(a);
  return z ?? <int>[];
}

/// Thông tin chi bộ dùng chung cho các văn bản (lưu trên máy)
class ThongTinChiBo {
  String capTren; // ví dụ: Đảng bộ xã Hòa Thắng
  String chiBo; // ví dụ: Chi bộ Trường THCS Lê Lợi
  String diaDanh;
  String biThu;
  String phoBiThu;
  ThongTinChiBo({this.capTren = '', this.chiBo = '', this.diaDanh = '', this.biThu = '', this.phoBiThu = ''});

  Map<String, dynamic> toJson() => {'ct': capTren, 'cb': chiBo, 'dd': diaDanh, 'bt': biThu, 'pbt': phoBiThu};
  factory ThongTinChiBo.fromJson(Map<String, dynamic> j) => ThongTinChiBo(
        capTren: j['ct'] as String? ?? '',
        chiBo: j['cb'] as String? ?? '',
        diaDanh: j['dd'] as String? ?? '',
        biThu: j['bt'] as String? ?? '',
        phoBiThu: j['pbt'] as String? ?? '',
      );
  bool get du => capTren.trim().isNotEmpty && chiBo.trim().isNotEmpty && diaDanh.trim().isNotEmpty;
}

/// Dữ liệu một buổi sinh hoạt chi bộ thường kỳ
class SinhHoatChiBo {
  DateTime ngay;
  String gioBatDau;
  String gioKetThuc;
  String diaDiem;
  String chuTri;
  String chucVuChuTri;
  String thuKy;
  int tongSo;
  int coMat;
  String vangCoLyDo; // tên, lý do
  String vangKhongLyDo;
  String thongTin; // 1. thông tin thời sự, văn bản cấp trên
  String ketQua; // 2. kết quả tháng
  String thaoLuan; // 3. ý kiến thảo luận
  String phuongHuong; // 4. phương hướng, nhiệm vụ tháng tới
  String ketLuan; // 5. kết luận
  int tanThanh;
  SinhHoatChiBo({
    required this.ngay,
    this.gioBatDau = '',
    this.gioKetThuc = '',
    this.diaDiem = '',
    this.chuTri = '',
    this.chucVuChuTri = 'Bí thư Chi bộ',
    this.thuKy = '',
    this.tongSo = 0,
    this.coMat = 0,
    this.vangCoLyDo = '',
    this.vangKhongLyDo = '',
    this.thongTin = '',
    this.ketQua = '',
    this.thaoLuan = '',
    this.phuongHuong = '',
    this.ketLuan = '',
    this.tanThanh = 0,
  });

  int get vang => (tongSo - coMat).clamp(0, 9999);
  String get thangNam => 'tháng ${ngay.month} năm ${ngay.year}';
  DateTime get thangSau => DateTime(ngay.year, ngay.month + 1, 1);
}

List<DoanDang> _dong(String chu) =>
    chu.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).map((l) => DoanDang(l)).toList();

String _haiSo(int n) => n < 10 ? '0$n' : '$n';

/// Biên bản sinh hoạt chi bộ thường kỳ
VanBanDang bienBanChiBo(ThongTinChiBo cb, SinhHoatChiBo s, {String so = ''}) {
  final d = s.ngay;
  final nd = <DoanDang>[
    DoanDang('Vào lúc ${s.gioBatDau.isEmpty ? '...' : s.gioBatDau}, ngày ${_haiSo(d.day)} tháng ${d.month < 3 ? _haiSo(d.month) : d.month} năm ${d.year}, '
        'tại ${s.diaDiem.isEmpty ? '...' : s.diaDiem}, ${cb.chiBo} tổ chức sinh hoạt chi bộ thường kỳ ${s.thangNam}.'),
    DoanDang('Chủ trì: đồng chí ${s.chuTri.isEmpty ? '...' : s.chuTri}, ${s.chucVuChuTri}.'),
    DoanDang('Thư ký: đồng chí ${s.thuKy.isEmpty ? '...' : s.thuKy}.'),
    DoanDang('Tổng số đảng viên của chi bộ: ${s.tongSo} đồng chí; có mặt: ${s.coMat} đồng chí; vắng: ${s.vang} đồng chí'
        '${s.vang > 0 ? ' (có lý do: ${s.vangCoLyDo.isEmpty ? '0' : s.vangCoLyDo}; không có lý do: ${s.vangKhongLyDo.isEmpty ? '0' : s.vangKhongLyDo})' : ''}.'),
    const DoanDang('NỘI DUNG SINH HOẠT', dam: true, giua: true),
    const DoanDang('1. Thông tin thời sự, quán triệt văn bản của cấp trên', dam: true),
    ..._dong(s.thongTin),
    DoanDang('2. Đánh giá kết quả thực hiện nhiệm vụ ${s.thangNam}', dam: true),
    ..._dong(s.ketQua),
    const DoanDang('3. Ý kiến thảo luận của đảng viên', dam: true),
    ..._dong(s.thaoLuan),
    DoanDang('4. Phương hướng, nhiệm vụ tháng ${s.thangSau.month} năm ${s.thangSau.year}', dam: true),
    ..._dong(s.phuongHuong),
    const DoanDang('5. Kết luận của đồng chí chủ trì', dam: true),
    ..._dong(s.ketLuan),
    DoanDang('Biểu quyết thông qua: ${s.tanThanh}/${s.coMat} đảng viên có mặt tán thành '
        '(đạt ${s.coMat == 0 ? 0 : (s.tanThanh * 100 / s.coMat).round()}%).'),
    DoanDang('Buổi sinh hoạt kết thúc vào lúc ${s.gioKetThuc.isEmpty ? '...' : s.gioKetThuc} cùng ngày. '
        'Biên bản đã được đọc lại cho chi bộ nghe và thống nhất thông qua.'),
  ];
  return VanBanDang(
    capTren: cb.capTren,
    coQuan: cb.chiBo,
    soKyHieu: 'Số ${so.isEmpty ? '     ' : so}-BB/CB',
    diaDanhNgay: ngayDang(cb.diaDanh, d),
    tenLoai: 'BIÊN BẢN',
    trichYeu: 'sinh hoạt chi bộ thường kỳ ${s.thangNam}',
    noiDung: nd,
    kyTrai: KhoiKy(chucVu: 'THƯ KÝ', hoTen: s.thuKy),
    kyPhai: KhoiKy(chucVu: 'CHỦ TRÌ', hoTen: s.chuTri),
  );
}

/// Nghị quyết chi bộ tháng
VanBanDang nghiQuyetChiBo(ThongTinChiBo cb, SinhHoatChiBo s, {String so = ''}) {
  final d = s.ngay;
  final ts = s.thangSau;
  final nd = <DoanDang>[
    DoanDang('Ngày ${_haiSo(d.day)} tháng ${d.month < 3 ? _haiSo(d.month) : d.month} năm ${d.year}, ${cb.chiBo} họp đánh giá kết quả '
        'thực hiện nhiệm vụ ${s.thangNam}, đề ra phương hướng, nhiệm vụ tháng ${ts.month} năm ${ts.year}. '
        'Có ${s.coMat}/${s.tongSo} đảng viên dự họp.'),
    const DoanDang('Chi bộ quyết nghị:', dam: true),
    DoanDang('I. KẾT QUẢ THỰC HIỆN NHIỆM VỤ ${s.thangNam.toUpperCase()}', dam: true),
    ..._dong(s.ketQua),
    DoanDang('II. PHƯƠNG HƯỚNG, NHIỆM VỤ THÁNG ${ts.month} NĂM ${ts.year}', dam: true),
    ..._dong(s.phuongHuong),
    const DoanDang('III. TỔ CHỨC THỰC HIỆN', dam: true),
    DoanDang('Các đồng chí đảng viên trong chi bộ căn cứ nghị quyết này tổ chức thực hiện. '
        'Đồng chí Bí thư Chi bộ chỉ đạo, kiểm tra việc thực hiện; báo cáo kết quả tại buổi sinh hoạt chi bộ tháng ${ts.month} năm ${ts.year}.'),
    DoanDang('Nghị quyết được ${s.tanThanh}/${s.coMat} đảng viên có mặt tán thành '
        '(đạt ${s.coMat == 0 ? 0 : (s.tanThanh * 100 / s.coMat).round()}%).'),
  ];
  return VanBanDang(
    capTren: cb.capTren,
    coQuan: cb.chiBo,
    soKyHieu: 'Số ${so.isEmpty ? '     ' : so}-NQ/CB',
    diaDanhNgay: ngayDang(cb.diaDanh, d),
    tenLoai: 'NGHỊ QUYẾT',
    trichYeu: 'về lãnh đạo thực hiện nhiệm vụ tháng ${ts.month} năm ${ts.year}',
    noiDung: nd,
    kyPhai: KhoiKy(quyenHan: 'T/M CHI BỘ', chucVu: 'BÍ THƯ', hoTen: cb.biThu.isEmpty ? s.chuTri : cb.biThu),
    noiNhan: ['${cb.capTren} (b/c)', 'Đảng viên trong chi bộ', 'Lưu chi bộ'],
  );
}
