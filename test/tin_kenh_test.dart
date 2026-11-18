import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tro_ly_so_giao_vien/data/tin_kenh.dart';

void main() {
  test('Tin mẫu đọc được và ảnh bìa có trong app', () {
    final ds = (jsonDecode(File('assets/tin/tin_mau.json').readAsStringSync()) as List)
        .map((e) => TinKenh.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    expect(ds.length, greaterThanOrEqualTo(3));
    for (final t in ds) {
      expect(t.tit, isNotEmpty);
      expect(t.anhDongGoi, isTrue);
      expect(File(t.duongDanAnh).existsSync(), isTrue, reason: t.duongDanAnh);
      expect(t.linkFacebook, isNull);
    }
  });
}
