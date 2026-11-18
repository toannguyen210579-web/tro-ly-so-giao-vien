import 'package:flutter_test/flutter_test.dart';
import 'package:tro_ly_so_giao_vien/data/o_chu.dart';

void main() {
  test('Chuẩn hóa chữ ô chữ', () {
    expect(chuanHoaO('Điện Biên Phủ'), 'DIENBIENPHU');
    expect(chuanHoaO('Quê'), 'QUE');
  });

  test('Xếp hàng ngang cho từ khóa thẳng cột', () {
    final o = OChu(id: '1', ten: 't', tuKhoa: 'Quê', hang: [HangO('a', 'Quýt'), HangO('b', 'Trâu'), HangO('c', 'Tre')]);
    expect(o.loi, isEmpty);
    expect(o.viTriKhoa, [0, 3, 2]);
    expect(o.doLech, [3, 0, 1]);
    expect(o.soCot, 7);
  });

  test('Báo lỗi khi đáp án thiếu chữ của từ khóa', () {
    final o = OChu(id: '1', ten: 't', tuKhoa: 'AB', hang: [HangO('a', 'Xoài'), HangO('b', 'Cá')]);
    expect(o.loi.length, 1);
  });
}
