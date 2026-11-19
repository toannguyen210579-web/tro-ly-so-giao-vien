import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tro_ly_so_giao_vien/services/doc_danh_sach.dart';
import 'package:tro_ly_so_giao_vien/services/van_phong_cu.dart';

void main() {
  test('Đọc chữ tiếng Việt từ tệp Word .doc', () {
    final chu = docChuDoc(File('test/tep_mau/de_kiem_tra.doc').readAsBytesSync());
    expect(chu, contains('ĐỀ KIỂM TRA GIỮA KỲ I - TOÁN 7'));
    expect(chu, contains('Câu 2. Tìm x biết 2x − 7 = 15.'));
  });

  test('Đọc bảng tiếng Việt từ tệp Excel .xls', () {
    final bang = docBangXls(File('test/tep_mau/danh_sach.xls').readAsBytesSync());
    expect(bang.first, ['STT', 'Họ và tên', 'Ngày sinh']);
    expect(bang[1], ['1', 'Nguyễn Văn An', '2013']);
    expect(layHoTenTuBang(bang), ['Nguyễn Văn An', 'Y Đức Niê', "H'Hen Mlô"]);
  });

  test('Tệp không phải Office báo lỗi dễ hiểu', () {
    expect(() => docChuDoc(File('test/tep_mau/danh_sach.xls').readAsBytesSync()), throwsA(isA<LoiTepCu>()));
    expect(() => docBangXls(File('pubspec.yaml').readAsBytesSync()), throwsA(isA<LoiTepCu>()));
  });
}
