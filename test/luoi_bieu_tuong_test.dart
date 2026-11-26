import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tro_ly_so_giao_vien/screens/bieu_tuong.dart';
import 'package:tro_ly_so_giao_vien/screens/xem_them.dart';

// Thầy cô báo 24/11/2026: màn Tất cả tiện ích biểu tượng cao thấp không đều, chữ to bị che, dòng chữ chạy rối mắt.
void main() {
  for (final coChu in [1.0, 1.35, 1.6]) {
    testWidgets('Tất cả tiện ích, cỡ chữ x$coChu: biểu tượng cùng hàng thẳng nhau, không tràn chữ', (t) async {
      t.view.physicalSize = const Size(390 * 3, 1600 * 3);
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      await t.pumpWidget(MaterialApp(
        builder: (c, child) =>
            MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(coChu)), child: child!),
        home: const XemThem(),
      ));
      await t.pump();
      // Lỗi tràn chữ (RenderFlex overflowed) làm phép thử hỏng ngay
      expect(t.takeException(), isNull);
      final bt = find.byType(BieuTuongNoi);
      expect(bt, findsWidgets);
      // 4 ô đầu cùng một hàng: mép trên của biểu tượng phải bằng nhau
      final tren = [for (var i = 0; i < 4; i++) t.getTopLeft(bt.at(i)).dy];
      for (final y in tren) {
        expect(y, closeTo(tren.first, 0.5));
      }
    });
  }

  testWidgets('Chiều cao ô tăng theo cỡ chữ của máy', (t) async {
    late double nho, to;
    await t.pumpWidget(MaterialApp(home: Builder(builder: (c) {
      nho = chieuCaoOTienIch(c);
      return const SizedBox();
    })));
    await t.pumpWidget(MaterialApp(
      builder: (c, child) => MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(1.6)), child: child!),
      home: Builder(builder: (c) {
        to = chieuCaoOTienIch(c);
        return const SizedBox();
      }),
    ));
    expect(to, greaterThan(nho + 10));
  });
}
