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
    FlutterError.onError = (d) {
      loi.add(d.exceptionAsString().split('\n').first);
      // ignore: avoid_print
      print('KQ chi_tiet_loi: ${d.exceptionAsString().split('\n').first} | ${d.informationCollector?.call().take(2).join(' / ')}');
      // ignore: avoid_print
      print('KQ ngan_xep: ${(d.stack?.toString() ?? '').split('\n').where((x) => x.trim().isNotEmpty).take(10).join(' <- ')}');
    };
    app.main();
    await cho(t, 3000);
    await b.convertFlutterSurfaceToImage();
    await chup(t, '00_trang_chu');

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
      }).timeout(const Duration(minutes: 6));
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
    // Hỏi Trợ lý mở thành màn riêng đè lên trang chủ: quay lại như nút trở về
    Navigator.of(t.element(find.byType(Scaffold).last)).pop();
    await cho(t, 1000);

    // 4. Màn Đọc to: dán chữ, bấm Đọc to
    moTienIch(t.element(find.byType(TrangChu)), dsTienIch.firstWhere((x) => x.ma == 'doc_to'));
    await cho(t, 2000);
    await t.enterText(find.byType(TextField).first, 'Kính gửi quý phụ huynh. Nhà trường thông báo lịch họp phụ huynh cuối học kỳ một.');
    final dd = Stopwatch()..start();
    // Nút có thể nằm dưới mép màn hình: cuộn tới rồi mới bấm, và báo nếu bấm trượt
    final nut = find.widgetWithText(FilledButton, 'Đọc to');
    // ignore: avoid_print
    print('KQ doc_to_nut: tim thay ${nut.evaluate().length} nut');
    // Bàn phím đang mở sau khi gõ chữ che mất nút (nút bị coi là ngoài màn hình, bấm báo "No element"): đóng bàn phím trước
    FocusManager.instance.primaryFocus?.unfocus();
    await cho(t, 1000);
    await t.ensureVisible(nut.first);
    // Không dùng pumpAndSettle: màn có chữ chạy, hoạt cảnh không bao giờ dừng nên phép thử bị treo đến hết giờ
    await cho(t, 600);
    // ignore: avoid_print
    print('KQ doc_to_nut_truoc_bam: ${nut.evaluate().length} nut');
    await t.tap(nut.first, warnIfMissed: true);
    int? batDau, ketThuc;
    for (var i = 0; i < 60; i++) {
      await cho(t, 300);
      final dangDoc = find.textContaining('Dừng').evaluate().isNotEmpty;
      if (dangDoc && batDau == null) {
        batDau = dd.elapsedMilliseconds;
        await chup(t, '30_doc_to_dang_doc');
      }
      if (!dangDoc && batDau != null) {
        ketThuc = dd.elapsedMilliseconds;
        break;
      }
    }
    final baoLoi = find.byType(SnackBar).evaluate().map((e) => ((e.widget as SnackBar).content as Text?)?.data ?? '').join(' | ');
    // ignore: avoid_print
    print('KQ doc_to: ${batDau == null ? "KHONG DOC" : "bat dau doc sau $batDau ms${ketThuc == null ? ", van dang doc" : ", doc xong sau $ketThuc ms"}"}; '
        'thong bao: ${baoLoi.isEmpty ? "khong" : baoLoi}; loi: ${loi.isEmpty ? "khong" : loi.toSet().join(" | ")}');
    Navigator.of(t.element(find.byType(Scaffold).last)).pop();
    await cho(t, 1000);

    // 5. Các lỗi thầy cô báo ngày 24/11/2026 (bản 0.4.0 (6)): bấm thật từng nút đã sửa
    Future<void> mo(String ma) async {
      moTienIch(t.element(find.byType(TrangChu)), dsTienIch.firstWhere((x) => x.ma == ma));
      await cho(t, 2000);
    }

    // Về trang chủ: đóng mọi hộp, trang đang mở trên bộ điều hướng gốc
    Future<void> veTrangChu() async {
      final nav = t.state<NavigatorState>(find.byType(Navigator).first);
      for (var i = 0; i < 6 && nav.canPop(); i++) {
        nav.pop();
        await cho(t, 700);
      }
    }

    Future<bool> doiChu(String chu, {int giay = 20}) async {
      for (var i = 0; i < giay * 4; i++) {
        if (find.textContaining(chu).evaluate().isNotEmpty) return true;
        await cho(t, 250);
      }
      return false;
    }

    Future<void> bamChu(String chu) async {
      FocusManager.instance.primaryFocus?.unfocus();
      await cho(t, 500);
      // Ưu tiên chữ nằm trên nút (tránh bấm nhầm vào lời hướng dẫn có cùng chữ)
      final nut = find.byWidgetPredicate((w) => w is ButtonStyleButton || w is FloatingActionButton || w is ListTile);
      var f = find.descendant(of: nut, matching: find.text(chu));
      if (f.evaluate().isEmpty) f = find.descendant(of: nut, matching: find.textContaining(chu));
      if (f.evaluate().isEmpty) f = find.text(chu);
      if (f.evaluate().isEmpty) {
        try {
          await t.scrollUntilVisible(f, 300, scrollable: find.byType(Scrollable).first);
        } catch (_) {}
      }
      await t.ensureVisible(f.first);
      await cho(t, 300);
      await t.tap(f.first, warnIfMissed: true);
      await cho(t, 800);
    }

    String thongBao() =>
        find.byType(SnackBar).evaluate().map((e) => ((e.widget as SnackBar).content as Text?)?.data ?? '').join(' | ');

    Future<void> buoc(String ten, Future<void> Function() viec) async {
      final truoc = loi.length;
      try {
        await viec();
      } catch (e) {
        // ignore: avoid_print
        print('KQ $ten: LOI PHEP THU ${e.toString().split('\n').first}');
      }
      if (loi.length > truoc) {
        // ignore: avoid_print
        print('KQ $ten: LOI APP ${loi.sublist(truoc).toSet().join(' | ')}');
      }
      await veTrangChu();
    }

    // Lỗi 4: Tính lương xuất bảng lương ra văn bản (Word và PDF)
    await buoc('tinh_luong', () async {
      await mo('luong');
      for (final kieu in ['Tệp Word', 'Tệp PDF']) {
        await bamChu('Xuất bảng lương ra văn bản');
        await bamChu(kieu);
        final ok = await doiChu('Đã xuất bảng lương');
        await chup(t, 'sua_luong_${kieu == 'Tệp Word' ? 'word' : 'pdf'}');
        // ignore: avoid_print
        print('KQ tinh_luong_xuat ${kieu == 'Tệp Word' ? 'word' : 'pdf'}: ${ok ? "co hop Da xuat" : "KHONG THAY"}; thong bao: ${thongBao()}');
        if (ok) await bamChu('Xong');
      }
    });

    // Lỗi 10: Giơ thẻ, In bộ thẻ có phản hồi; Xuất Excel, Chép bảng bấm được khi chưa có kết quả
    await buoc('gio_the', () async {
      await mo('gio_the');
      final dh = Stopwatch()..start();
      await bamChu('In bộ thẻ');
      final ok = await doiChu('Đã tạo bộ', giay: 30);
      await chup(t, 'sua_gio_the_in');
      // ignore: avoid_print
      print('KQ gio_the_in: ${ok ? "co hop Da tao bo the sau ${dh.elapsedMilliseconds} ms" : "KHONG THAY"}; '
          'nut In ngay: ${find.textContaining('In ngay').evaluate().length}; thong bao: ${thongBao()}');
      if (ok) await bamChu('Xong');
      await bamChu('Xuất Excel');
      // ignore: avoid_print
      print('KQ gio_the_excel_chua_co_kq: ${thongBao()}');
      await chup(t, 'sua_gio_the_excel');
    });

    // Lỗi 5: Lịch nhắc, Thêm việc là trang riêng có nút quay lại
    await buoc('lich', () async {
      await mo('lich');
      await bamChu('Thêm việc');
      await cho(t, 1000);
      final coTrang = find.text('Thêm việc có hạn').evaluate().isNotEmpty;
      final coQuayLai = find.byType(BackButton).evaluate().isNotEmpty;
      await chup(t, 'sua_lich_them');
      await t.enterText(find.widgetWithText(TextField, 'Việc cần làm'), 'Nộp sổ điểm học kỳ I');
      await bamChu('Lưu');
      final daLuu = await doiChu('Nộp sổ điểm học kỳ I', giay: 5);
      await chup(t, 'sua_lich_ds');
      // ignore: avoid_print
      print('KQ lich_them_viec: trang rieng=$coTrang, nut quay lai=$coQuayLai, luu=$daLuu');
    });

    // Lỗi 6: Công tác Đảng có biểu tượng kiểu app
    await buoc('dang', () async {
      await mo('dang');
      await chup(t, 'sua_dang');
      // ignore: avoid_print
      print('KQ dang_bieu_tuong: ${['Lịch họp chi bộ', 'Tính đảng phí', 'Dịch vụ công của Đảng', 'Sổ tay đảng viên', 'Hỏi công tác Đảng'].where((x) => find.text(x).evaluate().isNotEmpty).length}/5 o');
    });

    // Lỗi 2: Quét giấy tờ có nút chọn ảnh, tải tệp
    await buoc('quet', () async {
      await mo('quet');
      await chup(t, 'sua_quet');
      // ignore: avoid_print
      print('KQ quet_nut: chon anh=${find.text('Chọn ảnh có sẵn').evaluate().length}, tai tep=${find.text('Tải tệp PDF, ảnh').evaluate().length}');
    });

    // Lỗi 3: Thêm minh chứng có nút tải tệp
    await buoc('minh_chung', () async {
      await mo('minh_chung');
      await bamChu('Thêm minh chứng');
      await chup(t, 'sua_minh_chung');
      // ignore: avoid_print
      print('KQ minh_chung_nut: tai tep=${find.text('Tải tệp PDF').evaluate().length}');
    });

    // Lỗi 7: Nhắn phụ huynh có nút micro, lời giải thích Nhờ AI
    await buoc('nhan_ph', () async {
      await mo('nhan_ph');
      await chup(t, 'sua_nhan_ph');
      // ignore: avoid_print
      print('KQ nhan_ph: nut micro=${find.byIcon(Icons.mic_rounded).evaluate().length}, '
          'giai thich=${find.textContaining('Thầy cô chỉ cần nói').evaluate().length}');
    });

    // Lỗi 9: Ô chữ mẫu, nút Chơi lại hiện rõ trên nền tối
    await buoc('o_chu', () async {
      await mo('o_chu');
      await bamChu('Chơi');
      await bamChu('Mở từ khóa');
      await chup(t, 'sua_o_chu');
      // ignore: avoid_print
      print('KQ o_chu: nut Choi lai=${find.text('Chơi lại').evaluate().length}');
    });

    // Lỗi 8: Giải đề Toán 9, đo thời gian có kết quả
    await buoc('giai_de', () async {
      await mo('tao_de');
      await t.enterText(find.widgetWithText(TextField, 'Hoặc gõ, dán đề vào đây'),
          'Câu 1. Giải hệ phương trình x + y = 5 và 2x − y = 1.\nCâu 2. Cho phương trình x² − 2(m + 1)x + m² + 3 = 0. '
          'Tìm m để phương trình có hai nghiệm phân biệt.\nCâu 3. Cho tam giác ABC vuông tại A, AB = 6 cm, AC = 8 cm. Tính BC và đường cao AH.');
      final dh = Stopwatch()..start();
      await bamChu('Giải, soạn đáp án');
      await cho(t, 3000);
      await chup(t, 'sua_giai_de_cho');
      final ok = await doiChu('Kết quả (sửa được)', giay: 150);
      await chup(t, 'sua_giai_de_xong');
      // ignore: avoid_print
      print('KQ giai_de: ${ok ? "co ket qua sau ${dh.elapsedMilliseconds} ms" : "CHUA CO sau ${dh.elapsedMilliseconds} ms"}; thong bao: ${thongBao()}');
    });

    // ignore: avoid_print
    print('KQ tong_loi_app: ${loi.isEmpty ? "khong" : loi.toSet().join(" | ")}');
  }, timeout: const Timeout(Duration(minutes: 40)));
}
