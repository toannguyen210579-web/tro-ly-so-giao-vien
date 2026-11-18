import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tro_ly_so_giao_vien/screens/cong_cu_tren_lop.dart';

void main() {
  test('Chia nhóm đều, không sót em nào', () {
    final ten = List.generate(23, (i) => 'HS$i');
    final n = chiaNhom(ten, 4, Random(1));
    expect(n.length, 4);
    expect(n.expand((e) => e).toSet().length, 23);
    final c = n.map((e) => e.length).toList()..sort();
    expect(c.last - c.first, lessThanOrEqualTo(1));
  });
}
