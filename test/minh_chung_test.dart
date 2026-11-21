import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tro_ly_so_giao_vien/data/minh_chung.dart';
import 'package:tro_ly_so_giao_vien/services/doc_danh_sach.dart';
import 'package:tro_ly_so_giao_vien/services/tep_xlsx.dart';

MinhChung mc(String nhom, String tieuDe, DateTime ngay, {String ma = '', String ghiChu = '', int anh = 0}) => MinhChung(
      id: tieuDe,
      nhom: nhom,
      tieuDe: tieuDe,
      ngay: ngay,
      ma: ma,
      ghiChu: ghiChu,
      anh: [for (var i = 0; i < anh; i++) 'a$i.jpg'],
    );

void main() {
  test('Tên tệp: không dấu, không khoảng trắng, có số thứ tự và mã', () {
    final m = mc('Thi đua, khen thưởng', 'Giấy khen giáo viên dạy giỏi cấp xã 2025-2026', DateTime(2026, 5, 1), ma: 'H1-1.1-01');
    expect(tenTepMinhChung(3, m), '03_H1-1.1-01_Giay_khen_giao_vien_day_gioi_cap_xa_2025-2026.pdf');
    final khongMa = mc('Khác', 'Ảnh hoạt động "Ngày hội đọc sách" / lớp 6A?', DateTime(2026, 4, 21));
    expect(tenTepMinhChung(12, khongMa), '12_Anh_hoat_dong_Ngay_hoi_doc_sach_lop_6A.pdf');
    final dai = mc('Khác', 'Đ' * 100, DateTime(2026));
    expect(tenTepMinhChung(1, dai).length, lessThanOrEqualTo(3 + 60 + 4));
    expect(RegExp(r'^[A-Za-z0-9._\-]+$').hasMatch(tenTepMinhChung(1, dai)), isTrue);
  });

  test('Xếp đúng thứ tự nộp: theo nhóm, có mã xếp theo mã, rồi ngày cũ trước', () {
    final ds = [
      mc('Khác', 'K', DateTime(2026, 1, 1)),
      mc('Kiểm định chất lượng', 'KD2', DateTime(2026, 1, 1), ma: 'H1-1.2-01'),
      mc('Kiểm định chất lượng', 'KD1', DateTime(2026, 3, 1), ma: 'H1-1.1-02'),
      mc('Chuẩn nghề nghiệp', 'CN mới', DateTime(2026, 6, 1)),
      mc('Chuẩn nghề nghiệp', 'CN cũ', DateTime(2025, 9, 1)),
      mc('Kiểm định chất lượng', 'KD không mã', DateTime(2025, 1, 1)),
    ];
    expect(xepDeNop(ds).map((m) => m.tieuDe), ['CN cũ', 'CN mới', 'KD1', 'KD2', 'KD không mã', 'K']);
  });

  test('Danh mục Excel mở lại đọc đúng chữ có dấu, cột tên tệp khớp tệp PDF', () {
    final ds = xepDeNop([
      mc('Bồi dưỡng, tập huấn', 'Giấy chứng nhận BDTX 2025-2026', DateTime(2026, 6, 15), ghiChu: 'Số 88/GCN-SGDĐT, Sở GD&ĐT', anh: 2),
      mc('Thi đua, khen thưởng', 'Giấy khen <Chiến sĩ thi đua>', DateTime(2026, 5, 30), ma: 'TĐ-01'),
    ]);
    final bang = bangDanhMuc(ds);
    expect(bang.first, ['STT', 'Mã minh chứng', 'Nhóm', 'Tên minh chứng', 'Ngày', 'Số, ký hiệu, nơi ban hành, ghi chú', 'Số ảnh', 'Tên tệp']);
    final xlsx = taoXlsx(bang, tenTrang: 'Danh mục minh chứng', doRong: [6, 16, 22, 48, 12, 40, 8, 44]);
    // Là tệp zip hợp lệ có đủ phần của Excel
    final kho = ZipDecoder().decodeBytes(xlsx);
    for (final ten in ['[Content_Types].xml', 'xl/workbook.xml', 'xl/worksheets/sheet1.xml', 'xl/styles.xml', 'xl/_rels/workbook.xml.rels']) {
      expect(kho.findFile(ten), isNotNull, reason: ten);
    }
    // Để máy kiểm tra mở thử bằng thư viện Excel khác (openpyxl)
    Directory('build').createSync(recursive: true);
    File('build/thu_danh_muc_minh_chung.xlsx').writeAsBytesSync(xlsx);
    final doc = docBangXlsx(xlsx);
    expect(doc.length, 3);
    expect(doc[1], ['1', 'TĐ-01', 'Thi đua, khen thưởng', 'Giấy khen <Chiến sĩ thi đua>', '30/05/2026', '', '0', '01_TD-01_Giay_khen_Chien_si_thi_dua.pdf']);
    expect(doc[2][5], 'Số 88/GCN-SGDĐT, Sở GD&ĐT');
    expect(doc[2][7], tenTepMinhChung(2, ds[1]));
  });

  test('Dữ liệu cũ chưa có mã vẫn đọc được', () {
    final m = MinhChung.fromJson({'id': '1', 'nhom': 'Khác', 'tieu_de': 'A', 'ngay': '2026-01-02T00:00:00.000', 'anh': ['x.jpg']});
    expect(m.ma, '');
    expect(MinhChung.fromJson(m.toJson()).anh, ['x.jpg']);
  });
}
