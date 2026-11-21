import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tro_ly_so_giao_vien/services/van_ban_dang.dart';

void main() {
  final cb = ThongTinChiBo(capTren: 'Đảng bộ xã Hòa Thắng', chiBo: 'Chi bộ Trường THCS Lê Lợi', diaDanh: 'Hòa Thắng', biThu: 'Nguyễn Thị Lan');
  final sh = SinhHoatChiBo(
    ngay: DateTime(2026, 2, 5),
    gioBatDau: '14 giờ 00',
    gioKetThuc: '16 giờ 30',
    diaDiem: 'phòng họp nhà trường',
    chuTri: 'Nguyễn Thị Lan',
    thuKy: 'Trần Văn Bình',
    tongSo: 15,
    coMat: 14,
    vangCoLyDo: 'đồng chí Hoa (ốm)',
    thongTin: 'Quán triệt Thông tư 89/2026/TT-BGDĐT về đánh giá học sinh.',
    ketQua: 'Hoàn thành kiểm tra giữa kỳ II.\nTổ chức tốt hoạt động mừng Đảng.',
    thaoLuan: 'Đồng chí Bình: đề nghị tăng phụ đạo học sinh yếu.',
    phuongHuong: 'Ôn tập cho học sinh lớp 9.\nPhát động thi đua chào mừng 8/3.',
    ketLuan: 'Chi bộ thống nhất các nhiệm vụ đề ra.',
    tanThanh: 14,
  );

  test('Ngày tháng theo Hướng dẫn 05: ngày dưới 10 và tháng dưới 3 thêm số 0', () {
    expect(ngayDang('Hòa Thắng', DateTime(2026, 2, 5)), 'Hòa Thắng, ngày 05 tháng 02 năm 2026');
    expect(ngayDang('Hòa Thắng', DateTime(2026, 9, 12)), 'Hòa Thắng, ngày 12 tháng 9 năm 2026');
  });

  test('Biên bản và nghị quyết chi bộ: đủ phần, tệp Word mở được', () {
    final bb = bienBanChiBo(cb, sh, so: '05');
    expect(bb.soKyHieu, 'Số 05-BB/CB');
    expect(bb.kyTrai!.chucVu, 'THƯ KÝ');
    expect(bb.noiDung.map((d) => d.chu).join('\n'), contains('vắng: 1 đồng chí'));
    final nq = nghiQuyetChiBo(cb, sh, so: '05');
    expect(nq.trichYeu, 'về lãnh đạo thực hiện nhiệm vụ tháng 3 năm 2026');
    expect(nq.kyPhai.quyenHan, 'T/M CHI BỘ');
    expect(nq.noiNhan.last, 'Lưu chi bộ');

    Directory('build').createSync(recursive: true);
    for (final (ten, vb) in [('thu_bien_ban_chi_bo', bb), ('thu_nghi_quyet_chi_bo', nq)]) {
      final byte = taoDocxDang(vb);
      File('build/$ten.docx').writeAsBytesSync(byte);
      final z = ZipDecoder().decodeBytes(byte);
      final doc = utf8.decode(z.findFile('word/document.xml')!.content as List<int>);
      expect(doc, contains('ĐẢNG CỘNG SẢN VIỆT NAM'));
      expect(doc, contains('w:left="1701"'));
      expect(doc, contains('w:lineRule="exact"'));
      expect(z.findFile('word/header1.xml'), isNotNull);
    }
  });

  test('Đảng phí theo Quy định 01-QĐ/TW năm 2026', () {
    expect(tinhDangPhi(NhomDangPhi.coBhxh, soTien: 8500000), 85000);
    expect(tinhDangPhi(NhomDangPhi.huuTri, soTien: 7000000), 35000);
    expect(tinhDangPhi(NhomDangPhi.hocSinh), 5000);
    expect(tinhDangPhi(NhomDangPhi.chuaDenTuoiHuu, vung: 1, nam: 2026), 15930);
    expect(tinhDangPhi(NhomDangPhi.chuaDenTuoiHuu, vung: 1, nam: 2028), 26550);
    expect(tinhDangPhi(NhomDangPhi.duTuoiChuaHuu, vung: 4, nam: 2026), 7400);
    expect(tinhDangPhi(NhomDangPhi.huuTri, soTien: 7000000, giamMotNua: true), 17500);
    expect(tienVN(85000), '85.000 đồng');
  });

  test('Lịch họp chi bộ hằng tháng', () {
    final ds = lichHopChiBo(31, 14, 0, tu: DateTime(2026, 11, 21, 18));
    expect(ds.length, 12);
    expect(ds.first, DateTime(2026, 11, 30, 14));
    expect(ds[1], DateTime(2026, 12, 31, 14));
    expect(ds[3], DateTime(2027, 2, 28, 14));
    final qua = lichHopChiBo(5, 14, 0, tu: DateTime(2026, 11, 21, 18));
    expect(qua.first, DateTime(2026, 12, 5, 14));
    expect(qua.length, 12);
  });
}
