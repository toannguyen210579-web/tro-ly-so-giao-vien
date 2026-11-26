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

/// Chỉ chạy các bước này (cách nhau dấu phẩy, --dart-define=BUOC=...); để trống là chạy hết.
const _chiBuoc = String.fromEnvironment('BUOC');

void main() {
  final b = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> cho(WidgetTester t, [int ms = 1500]) async {
    for (var i = 0; i < ms ~/ 100; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> chup(WidgetTester t, String ten) async {
    // Bàn phím đang mở thì hạ trước khi chụp: chụp lúc bàn phím đổi cỡ màn hình làm máy giả lập mất kết nối (24/11/2026)
    if (FocusManager.instance.primaryFocus?.hasPrimaryFocus ?? false) {
      FocusManager.instance.primaryFocus?.unfocus();
      await cho(t, 1000);
    }
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

    // Thanh dưới (Tin tức, Tài khoản) thử riêng ở thanh_duoi_test.dart: trong phép thử dài này, mở màn có thanh dưới
    // từ thanh dưới thì máy giả lập sập vài giây sau (26/11/2026, 6 lần); thử riêng thì chạy bình thường.

    // Chạy riêng vài bước (ô buoc của workflow): bỏ phần đầu (giọng đọc, mở từng tiện ích, Hỏi Trợ lý, Đọc to)
    if (_chiBuoc.isEmpty) {
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
    // Nút gửi chỉ hiện khi ô hỏi có chữ: chờ vẽ lại rồi mới bấm
    await cho(t, 600);
    // ignore: avoid_print
    print('KQ hoi_nut_gui: ${find.byIcon(Icons.arrow_upward).evaluate().length} nut, micro ${find.byIcon(Icons.mic_rounded).evaluate().length + find.byIcon(Icons.mic_none).evaluate().length}');
    final dh = Stopwatch()..start();
    await t.tap(find.byIcon(Icons.arrow_upward).first);
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

    }

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
      if (_chiBuoc.isNotEmpty && !_chiBuoc.split(',').contains(ten)) return;
      // ignore: avoid_print
      print('KQ bat_dau $ten');
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
      // Xong khi nút Giải hiện lại (hết chờ); ô kết quả nằm dưới màn hình nên không tìm theo chữ của ô
      var ok = false;
      for (var i = 0; i < 640 && !ok; i++) {
        await cho(t, 250);
        ok = find.text('Giải, soạn đáp án').evaluate().isNotEmpty;
      }
      ok = ok && find.textContaining('Bản do AI làm').evaluate().isNotEmpty;
      await chup(t, 'sua_giai_de_xong');
      // ignore: avoid_print
      print('KQ giai_de: ${ok ? "co ket qua sau ${dh.elapsedMilliseconds} ms" : "CHUA CO sau ${dh.elapsedMilliseconds} ms"}; thong bao: ${thongBao()}');
    });

    // Đợt 2, 3 (26/11/2026): Hỏi Trợ lý có nút ?, thanh dưới, Tin tức, phiên bản, Biên bản, Dịch tài liệu
    await buoc('hoi_huong_dan', () async {
      await t.tap(find.text('Hỏi Trợ lý').last);
      await cho(t, 1500);
      final soO = find.byType(TextField).evaluate().length;
      final coNut = find.byKey(const Key('nut_huong_dan')).evaluate().isNotEmpty;
      if (coNut) {
        await t.tap(find.byKey(const Key('nut_huong_dan')));
        await cho(t, 1500);
      }
      final coHd = find.textContaining('Điểm mạnh').evaluate().isNotEmpty;
      await chup(t, 'moi_hoi_huong_dan');
      // ignore: avoid_print
      print('KQ hoi_huong_dan: o hoi=$soO, nut ?=$coNut, trang huong dan=${coHd ? "co" : "KHONG"}');
    });

    await buoc('bien_ban', () async {
      await mo('hop');
      await bamChu('Biên bản mới');
      await cho(t, 1500);
      final nChup = find.text('Chụp ảnh ghi chép').evaluate().length;
      final nTep = find.text('Lấy từ tệp: ảnh, PDF, Word').evaluate().length;
      Future<void> nhap(String nhan, String chu) async {
        final f = find.widgetWithText(TextField, nhan);
        if (f.evaluate().isEmpty) {
          try {
            await t.scrollUntilVisible(f, 300, scrollable: find.byType(Scrollable).first);
          } catch (_) {}
        }
        await t.ensureVisible(f.first);
        await cho(t, 300);
        await t.enterText(f.first, chu);
        await cho(t, 300);
      }

      await nhap('Về việc', 'đánh giá hoạt động chuyên môn tháng 11');
      await nhap('Ghi chép', 'Cô Lan: tổ đã dạy đủ chương trình.\nThầy Hùng: cần thêm tiết phụ đạo cho lớp 9.');
      // Hai nút lấy ghi chép nằm ngay dưới ô Ghi chép: đếm lại khi đã cuộn tới
      FocusManager.instance.primaryFocus?.unfocus();
      await cho(t, 800);
      try {
        await t.scrollUntilVisible(find.text('Lấy từ tệp: ảnh, PDF, Word'), 200, scrollable: find.byType(Scrollable).first);
      } catch (_) {}
      // ignore: avoid_print
      print('KQ bien_ban_nut_duoi_o_ghi_chep: chup=${find.text('Chụp ảnh ghi chép').evaluate().length}, lay tu tep=${find.text('Lấy từ tệp: ảnh, PDF, Word').evaluate().length}');
      await bamChu('Lưu biên bản');
      final ok = await doiChu('Đã lưu biên bản', giay: 20);
      final moXem = find.text('Mở xem').evaluate().length;
      final luuMay = find.text('Lưu vào máy').evaluate().length;
      await chup(t, 'moi_bien_ban_da_luu');
      // ignore: avoid_print
      print('KQ bien_ban: nut chup=$nChup, nut lay tu tep=$nTep, hop Da luu=${ok ? "co" : "KHONG"}, Mo xem=$moXem, Luu vao may=$luuMay; thong bao: ${thongBao()}');
      if (ok) await bamChu('Xong');
    });

    await buoc('dich', () async {
      await mo('dich');
      await t.enterText(find.byType(TextField).first,
          'Dear parents, the school will hold a parent-teacher meeting next Sunday at 7 a.m. Please attend on time.');
      final dh = Stopwatch()..start();
      await bamChu('Dịch');
      final ok = await doiChu('Bản dịch (', giay: 90);
      await chup(t, 'moi_dich');
      final coViet = find.textContaining('phụ huynh').evaluate().isNotEmpty || find.textContaining('Phụ huynh').evaluate().isNotEmpty;
      // ignore: avoid_print
      print('KQ dich: ${ok ? "co ban dich sau ${dh.elapsedMilliseconds} ms" : "CHUA CO sau ${dh.elapsedMilliseconds} ms"}, co chu "phu huynh"=$coViet; thong bao: ${thongBao()}');
      if (ok) {
        await bamChu('Lưu bản dịch (Word, PDF)');
        final luu = await doiChu('Đã lưu', giay: 20);
          // ignore: avoid_print
        print('KQ dich_luu: ${luu ? "co hop Da luu" : "KHONG THAY"}; thong bao: ${thongBao()}');
        if (luu) await bamChu('Xong');
      }
    });

    // Tạo bài trình chiếu (26/11/2026): gọi máy chủ thật, lưu PowerPoint + PDF trên máy (phông Be Vietnam Pro trong app)
    await buoc('trinh_chieu', () async {
      await mo('trinh_chieu');
      await t.enterText(
          find.byKey(const Key('tc_o_chu')),
          'KẾ HOẠCH BÀI DẠY. Môn Khoa học tự nhiên 6. Bài 9: Sự đa dạng của chất. '
          'I. Mục tiêu: nêu được sự đa dạng của chất; trình bày được một số đặc điểm cơ bản ba thể của chất. '
          'III. Tiến trình. Hoạt động 1 Mở đầu: GV cho HS quan sát ảnh cốc nước, khối đá, hơi nước bốc lên; hỏi: ba vật này có gì giống nhau? '
          'Hoạt động 2 Hình thành kiến thức: 2.1 Chất có ở xung quanh ta: vật thể tự nhiên (cây, đá), vật thể nhân tạo (bàn, ghế), vật sống, vật không sống. '
          '2.2 Ba thể của chất: rắn (hình dạng cố định, khó nén), lỏng (hình dạng theo vật chứa, khó nén), khí (dễ nén, không có hình dạng cố định). '
          'Hoạt động 3 Luyện tập: Câu 1. Kể tên 3 vật thể tự nhiên. Câu 2. Nước đá ở thể nào? Đáp án: Câu 2 thể rắn. '
          'Hoạt động 4 Vận dụng: vì sao bơm được không khí vào quả bóng? Đáp án: chất khí dễ nén.');
      final dh = Stopwatch()..start();
      await bamChu('Tạo bài trình chiếu');
      final ok = await doiChu(' trang)', giay: 120);
      await chup(t, 'moi_trinh_chieu');
      // ignore: avoid_print
      print('KQ trinh_chieu: ${ok ? "co bai sau ${dh.elapsedMilliseconds} ms" : "CHUA CO sau ${dh.elapsedMilliseconds} ms"}; thong bao: ${thongBao()}');
      if (ok) {
        await bamChu('Lưu bài trình chiếu (PowerPoint, PDF)');
        final luu = await doiChu('Đã lưu bài trình chiếu', giay: 30);
        await chup(t, 'moi_trinh_chieu_da_luu');
        // ignore: avoid_print
        print('KQ trinh_chieu_luu: ${luu ? "co hop Da luu" : "KHONG THAY"}; thong bao: ${thongBao()}');
        if (luu) await bamChu('Xong');
      }
    });

    // ignore: avoid_print
    print('KQ tong_loi_app: ${loi.isEmpty ? "khong" : loi.toSet().join(" | ")}');
  }, timeout: const Timeout(Duration(minutes: 40)));
}
