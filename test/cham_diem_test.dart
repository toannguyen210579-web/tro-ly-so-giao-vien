import 'package:flutter_test/flutter_test.dart';
import 'package:tro_ly_so_giao_vien/data/cham_diem.dart';
import 'package:tro_ly_so_giao_vien/services/tep_pdf.dart';

void main() {
  test('Gõ nhanh đáp án nhiều kiểu đều ra cùng một dãy', () {
    expect(chuanHoaDapAn('abcd', 4), 'ABCD');
    expect(chuanHoaDapAn('A B C D', 4), 'ABCD');
    expect(chuanHoaDapAn('1234', 4), 'ABCD');
    expect(chuanHoaDapAn('1A 2B 3C 4D', 4), 'ABCD');
    expect(chuanHoaDapAn('1.A 2.B', 4), 'AB--');
    expect(chuanHoaDapAn('AB-D', 4), 'AB-D');
    expect(chuanHoaDapAn('ABCDA', 4), 'ABCD');
  });

  test('Tính điểm thang 10, bỏ câu không có đáp án', () {
    expect(soCauDung('ABCD', 'ABCA'), 3);
    expect(diemThang10('ABCD', 'ABCA'), 7.5);
    expect(diemThang10('ABC-', 'ABCD'), 10);
    expect(diemThang10('ABC', 'BBB'), 3.33);
    expect(hienDiem(7.5), '7,5');
    expect(hienDiem(10), '10');
  });

  test('Tên tệp bỏ dấu', () {
    expect(tenTep('Họp tổ Toán tháng 11'), 'hop_to_toan_thang_11');
  });

  test('Lấy đáp án trắc nghiệm từ lời giải AI', () {
    expect(layDapAnTuLoiGiai('Lời giải…\nĐÁP ÁN TRẮC NGHIỆM: 1A 2C 3. B 5d'), 'ACB-D');
    expect(layDapAnTuLoiGiai('Không có trắc nghiệm'), isNull);
  });
}
