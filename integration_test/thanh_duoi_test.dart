// Thử riêng thanh dưới và hai nút mới của Biên bản (26/11/2026): Tài khoản hiện số phiên bản đọc lúc chạy,
// Tin tức mở được, bấm Trang chủ thì về; Biên bản có nút Chụp ảnh ghi chép, Lấy từ tệp dưới ô Ghi chép.
// Không chụp ảnh: máy giả lập hay sập lúc chụp ảnh ngay sau khi chuyển màn.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tro_ly_so_giao_vien/data/tien_ich.dart';
import 'package:tro_ly_so_giao_vien/main.dart' as app;
import 'package:tro_ly_so_giao_vien/screens/dieu_huong.dart';
import 'package:tro_ly_so_giao_vien/screens/tin_kenh.dart';
import 'package:tro_ly_so_giao_vien/screens/trang_chu.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> cho(WidgetTester t, [int ms = 1500]) async {
    for (var i = 0; i < ms ~/ 100; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  void kq(String s) {
    // ignore: avoid_print
    print('KQ $s');
  }

  testWidgets('Thanh dưới, Biên bản', (t) async {
    FlutterError.onError = (d) => kq('loi: ${d.exceptionAsString().split('\n').first}');
    app.main();
    await cho(t, 4000);

    await t.tap(find.text('Tài khoản').last);
    await cho(t, 3000);
    final pb = find.textContaining('0.4.0').evaluate().map((e) => (e.widget as Text).data).join(' | ');
    kq('tai_khoan: phien ban hien "$pb"');
    await t.tap(find.text('Tin tức').last);
    await cho(t, 3000);
    kq('tin_tuc: man tin=${find.byType(ManTin).evaluate().length}, the tin=${find.byType(TheTin).evaluate().length}, '
        'nut Facebook=${find.textContaining('Xem trên Facebook').evaluate().length}');
    await t.tap(find.text('Trang chủ').last);
    await cho(t, 2000);
    kq('ve_trang_chu: ${find.byType(TrangChu).evaluate().isNotEmpty}');

    moTienIch(t.element(find.byType(TrangChu)), dsTienIch.firstWhere((x) => x.ma == 'hop'));
    await cho(t, 2000);
    await t.tap(find.text('Biên bản mới'));
    await cho(t, 2000);
    try {
      await t.scrollUntilVisible(find.text('Lấy từ tệp: ảnh, PDF, Word'), 200, scrollable: find.byType(Scrollable).first);
    } catch (_) {}
    await cho(t, 500);
    kq('bien_ban_nut: chup=${find.text('Chụp ảnh ghi chép').evaluate().length}, lay tu tep=${find.text('Lấy từ tệp: ảnh, PDF, Word').evaluate().length}');
    kq('xong');
  }, timeout: const Timeout(Duration(minutes: 5)));
}
