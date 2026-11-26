// Thử riêng: mở app, bấm Tin tức ở thanh dưới ngay từ đầu (máy giả lập mất kết nối ở bước này, 26/11/2026).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tro_ly_so_giao_vien/main.dart' as app;
import 'package:tro_ly_so_giao_vien/screens/tin_kenh.dart';

void main() {
  final b = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> cho(WidgetTester t, [int ms = 1500]) async {
    for (var i = 0; i < ms ~/ 100; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('Mở Tin tức', (t) async {
    FlutterError.onError = (d) {
      // ignore: avoid_print
      print('KQ loi: ${d.exceptionAsString().split('\n').first}');
    };
    app.main();
    await cho(t, 4000);
    await b.convertFlutterSurfaceToImage();
    await cho(t, 500);
    await b.takeScreenshot('tin_00_trang_chu');
    // ignore: avoid_print
    print('KQ tin_bat_dau: thay ${find.text('Tin tức').evaluate().length} chu Tin tuc');
    await t.tap(find.text('Tin tức').last);
    for (var i = 1; i <= 30; i++) {
      await t.pump(const Duration(milliseconds: 100));
      // ignore: avoid_print
      if (i % 5 == 0) print('KQ tin_khung $i: ManTin=${find.byType(ManTin).evaluate().length}, the=${find.byType(TheTin).evaluate().length}');
    }
    await b.takeScreenshot('tin_01_man_tin');
    // ignore: avoid_print
    print('KQ tin_xong');
  }, timeout: const Timeout(Duration(minutes: 5)));
}
