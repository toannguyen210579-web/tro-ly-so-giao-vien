// Chạy thử app thật trên máy Android giả lập: mở từng tiện ích, hỏi Trợ lý, đọc to bằng giọng cài sẵn.
// Kết quả in ra dòng "KQ ..." và ảnh chụp từng màn hình.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tro_ly_so_giao_vien/data/tien_ich.dart';
import 'package:tro_ly_so_giao_vien/main.dart' as app;
import 'package:tro_ly_so_giao_vien/screens/dieu_huong.dart';
import 'package:tro_ly_so_giao_vien/screens/trang_chu.dart';
import 'package:tro_ly_so_giao_vien/services/giong_may.dart';

void main() {
  final b = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> cho(WidgetTester t, [int ms = 1500]) async {
    for (var i = 0; i < ms ~/ 100; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> chup(WidgetTester t, String ten) async {
    await cho(t, 600);
    await b.takeScreenshot(ten);
  }

  testWidgets('Chạy thử toàn bộ app', (t) async {
    final loi = <String>[];
    FlutterError.onError = (d) => loi.add(d.exceptionAsString().split('\n').first);
    app.main();
    await cho(t, 3000);
    await b.convertFlutterSurfaceToImage();
    await chup(t, '00_trang_chu');

    // 1. Mở từng tiện ích
    for (final ti in dsTienIch) {
      final truoc = loi.length;
      final ctx = t.element(find.byType(TrangChu));
      final dongHo = Stopwatch()..start();
      moTienIch(ctx, ti);
      await cho(t, 2500);
      await chup(t, 'ti_${ti.ma}');
      // ignore: avoid_print
      print('KQ mo ${ti.ma} (${ti.ten}): ${loi.length == truoc ? "on" : "LOI ${loi.sublist(truoc).join(" | ")}"}, ${dongHo.elapsedMilliseconds} ms');
      Navigator.of(t.element(find.byType(Scaffold).last)).pop();
      await cho(t, 800);
    }

    // 2. Hỏi Trợ lý
    await t.tap(find.text('Hỏi Trợ lý').last);
    await cho(t, 1500);
    await t.enterText(find.byType(TextField).first, 'Hôm nay là thứ mấy? Còn mấy ngày đến Tết Dương lịch?');
    final dh = Stopwatch()..start();
    await t.tap(find.byIcon(Icons.arrow_upward));
    var coTraLoi = false;
    for (var i = 0; i < 60 && !coTraLoi; i++) {
      await cho(t, 500);
      coTraLoi = find.textContaining('2026').evaluate().length + find.textContaining('ngày').evaluate().length > 1;
    }
    await chup(t, '20_hoi_tro_ly');
    // ignore: avoid_print
    print('KQ hoi_tro_ly: ${coTraLoi ? "co tra loi" : "CHUA THAY TRA LOI"} sau ${dh.elapsedMilliseconds} ms');
    await t.tap(find.text('Trang chủ').last);
    await cho(t, 1000);

    // 3. Giọng đọc cài sẵn: tải về, tạo tiếng
    final d1 = Stopwatch()..start();
    try {
      var moc = 0;
      await GiongMay.taiVe(tienDo: (x) {
        if (x * 10 >= moc) {
          // ignore: avoid_print
          print('KQ tai_giong: ${(x * 100).round()}% sau ${d1.elapsedMilliseconds} ms');
          moc = (x * 10).floor() + 1;
        }
      });
      // ignore: avoid_print
      print('KQ tai_giong: xong sau ${d1.elapsedMilliseconds} ms, san sang=${await GiongMay.sanSang()}');
      final tam = await getTemporaryDirectory();
      final d2 = Stopwatch()..start();
      final f = await GiongMay.tao('Kính gửi quý phụ huynh em Nguyễn Văn An. Nhà trường kính mời quý phụ huynh dự họp lúc bảy giờ sáng Chủ nhật.',
          duongRa: '${tam.path}/thu.wav');
      final n = await f.length();
      // ignore: avoid_print
      print('KQ tao_tieng: ${n > 20000 ? "on" : "LOI"} ${n} byte (khoang ${(n / 44100).toStringAsFixed(1)} giay), mat ${d2.elapsedMilliseconds} ms');
    } catch (e) {
      // ignore: avoid_print
      print('KQ giong_may: LOI $e');
    }

    // 4. Màn Đọc to: dán chữ, bấm Đọc to
    moTienIch(t.element(find.byType(TrangChu)), dsTienIch.firstWhere((x) => x.ma == 'doc_to'));
    await cho(t, 2000);
    await t.enterText(find.byType(TextField).first, 'Kính gửi quý phụ huynh. Nhà trường thông báo lịch họp phụ huynh cuối học kỳ một.');
    await t.tap(find.text('Đọc to'));
    await cho(t, 8000);
    await chup(t, '30_doc_to_dang_doc');
    // ignore: avoid_print
    print('KQ doc_to: ${find.textContaining('Dừng').evaluate().isNotEmpty ? "dang doc" : "khong thay nut Dung"}; loi: ${loi.isEmpty ? "khong" : loi.toSet().join(" | ")}');
  }, timeout: const Timeout(Duration(minutes: 25)));
}
