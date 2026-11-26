import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tro_ly_so_giao_vien/screens/thanh_duoi.dart';
import 'package:tro_ly_so_giao_vien/screens/tin_kenh.dart';

// Máy giả lập Android mất kết nối ngay sau khi bấm Tin tức ở thanh dưới (26/11/2026, 3 lần liền):
// thử riêng phần điều hướng, dựng màn Tin tức, để biết có vòng lặp dựng màn hay lỗi giao diện không.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Bấm Tin tức ở thanh dưới mở màn Tin tức, bấm Trang chủ thì về', (t) async {
    await t.pumpWidget(const MaterialApp(
      home: Scaffold(body: Center(child: Text('Trang đầu')), bottomNavigationBar: ThanhDuoi(chon: nutTrangChu)),
    ));
    await t.tap(find.text('Tin tức'));
    for (var i = 0; i < 30; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
    for (var i = 0; i < 30; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(ManTin), findsOneWidget);
    expect(t.takeException(), isNull);
    // Màn Tin tức có thẻ tin từ tệp mẫu (không có mạng trong phép thử)
    expect(find.byType(TheTin).evaluate().isNotEmpty || find.text('Chưa có tin nào.').evaluate().isNotEmpty, true);
    await t.tap(find.text('Trang chủ').last);
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(ManTin), findsNothing);
    expect(find.text('Trang đầu'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 90)));

  testWidgets('Màn Tin tức dựng được, cuộn được hết danh sách', (t) async {
    await t.pumpWidget(const MaterialApp(home: ManTin()));
    // Tải tin (mạng bị chặn trong phép thử, lấy tệp mẫu): xen kẽ chờ thật và vẽ khung
    for (var i = 0; i < 20 && find.byType(ListView).evaluate().isEmpty; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(t.takeException(), isNull);
    final soThe = find.byType(TheTin).evaluate().length;
    // ignore: avoid_print
    print('KQ man_tin: $soThe the tin');
    await t.drag(find.byType(ListView), const Offset(0, -4000));
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(t.takeException(), isNull);
  }, timeout: const Timeout(Duration(seconds: 90)));
}
