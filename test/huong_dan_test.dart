import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tro_ly_so_giao_vien/data/huong_dan.dart';
import 'package:tro_ly_so_giao_vien/data/tien_ich.dart';
import 'package:tro_ly_so_giao_vien/screens/cau_giup_viec.dart';

void main() {
  test('Mọi tiện ích và Hỏi Trợ lý đều có hướng dẫn, không mục nào rỗng', () {
    for (final ma in [...dsTienIch.map((t) => t.ma), 'hoi']) {
      expect(huongDan[ma], isNotNull, reason: ma);
      expect(huongDan[ma]!.length, greaterThanOrEqualTo(2), reason: ma);
      for (final m in huongDan[ma]!) {
        expect(m.buoc, isNotEmpty, reason: '$ma ${m.tieuDe}');
      }
    }
  });

  test('Hướng dẫn không còn nhắc Phòng GD&ĐT là nơi nhận', () {
    for (final e in huongDan.entries) {
      for (final m in e.value) {
        for (final b in m.buoc) {
          if (b.contains('Phòng GD')) expect(b, contains('không còn Phòng GD'), reason: e.key);
          expect(b.contains('cấp huyện'), false, reason: e.key);
        }
      }
    }
  });

  testWidgets('Bấm "Hướng dẫn sử dụng" mở trang hướng dẫn đầy đủ', (t) async {
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: CauGiupViec('cham_tn'))));
    await t.tap(find.text('Hướng dẫn sử dụng'));
    await t.pumpAndSettle();
    expect(find.text('Hướng dẫn: Chấm trắc nghiệm'), findsOneWidget);
    expect(find.text('Tạo bài kiểm tra'), findsOneWidget);
    await t.pageBack();
    await t.pumpAndSettle();
    expect(find.text('Hướng dẫn sử dụng'), findsOneWidget);
  });
}
