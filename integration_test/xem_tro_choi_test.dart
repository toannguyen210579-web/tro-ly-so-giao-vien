// Chụp màn hình Ô chữ mỗi ngày và Thử thách cả lớp để người dùng xem mà không cần cài app.
// Dữ liệu mẫu (lớp 7A) là dữ liệu tự đặt. Ảnh lưu vào anh_chay_thu/xem_*.png.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tro_ly_so_giao_vien/data/o_chu_moi_ngay.dart';
import 'package:tro_ly_so_giao_vien/data/thu_thach.dart';
import 'package:tro_ly_so_giao_vien/data/tien_ich.dart';
import 'package:tro_ly_so_giao_vien/main.dart' as app;
import 'package:tro_ly_so_giao_vien/screens/dieu_huong.dart';
import 'package:tro_ly_so_giao_vien/screens/nhan_xet.dart';
import 'package:tro_ly_so_giao_vien/screens/trang_chu.dart';

const _tenLop7A = [
  'Lê Hoàng An', 'Trần Ngọc Anh', 'Nguyễn Gia Bảo', 'Phạm Minh Châu', 'Võ Thành Đạt', 'Đỗ Hải Đăng', 'Bùi Thu Hà',
  'Hoàng Gia Hân', 'Ngô Đức Huy', 'Đặng Minh Khang', 'Lý Bảo Khánh', 'Trịnh Ngọc Lan', 'Phan Gia Linh', 'Vũ Đức Long',
];

void main() {
  final b = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> cho(WidgetTester t, [int ms = 1500]) async {
    for (var i = 0; i < ms ~/ 100; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  void kq(String s) {
    // ignore: avoid_print
    print('KQ $s');
  }

  Future<void> chup(WidgetTester t, String ten) async {
    for (final s in t.stateList<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))) {
      s.removeCurrentSnackBar();
    }
    await cho(t, 700);
    try {
      await b.takeScreenshot('xem_$ten');
      kq('chup $ten: on');
    } catch (e) {
      kq('chup $ten: LOI $e');
    }
  }

  /// Cuộn danh sách chính cho đến khi [f] được dựng (danh sách dài chỉ dựng phần gần màn hình).
  Future<void> cuonToi(WidgetTester t, Finder f) async {
    if (f.evaluate().isNotEmpty) return;
    try {
      final sc = find.descendant(of: find.byType(ListView).last, matching: find.byType(Scrollable)).first;
      final vt = t.state<ScrollableState>(sc).position;
      for (var i = 0; i < 60 && f.evaluate().isEmpty && vt.pixels < vt.maxScrollExtent; i++) {
        vt.jumpTo(min(vt.pixels + 300, vt.maxScrollExtent));
        await cho(t, 200);
      }
    } catch (_) {}
  }

  /// Gõ chữ thẳng vào ô (bàn phím thật trên máy giả lập hay nuốt lần gõ thứ hai).
  Future<void> go(WidgetTester t, Finder o, String chu) async {
    t.widget<TextField>(o).controller!.text = chu;
    await cho(t, 300);
  }

  Future<void> bam(WidgetTester t, Finder f, {int ms = 1200}) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await cho(t, 500);
    await cuonToi(t, f);
    await t.ensureVisible(f.first);
    await cho(t, 300);
    await t.tap(f.first);
    await cho(t, ms);
  }

  Future<void> cuonDau(WidgetTester t) async {
    try {
      final sc = find.descendant(of: find.byType(ListView).last, matching: find.byType(Scrollable)).first;
      t.state<ScrollableState>(sc).position.jumpTo(0);
    } catch (_) {}
    await cho(t, 500);
  }

  Future<void> buoc(WidgetTester t, String ten, Future<void> Function() viec) async {
    try {
      Navigator.of(t.element(find.byType(TrangChu, skipOffstage: false))).popUntil((r) => r.isFirst);
      await cho(t, 800);
    } catch (_) {}
    try {
      await viec();
      kq('$ten: xong');
    } catch (e, st) {
      kq('$ten: LOI ${e.toString().split('\n').first}');
      kq('$ten: tai ${st.toString().split('\n').where((d) => d.contains('xem_tro_choi') || d.contains('lib/')).take(4).join(' <- ')}');
      await chup(t, '${ten}_loi');
    }
  }

  testWidgets('Xem Ô chữ mỗi ngày, Thử thách cả lớp', (t) async {
    FlutterError.onError = (d) => kq('loi_giao_dien: ${d.exceptionAsString().split('\n').first}');
    final p = await SharedPreferences.getInstance();
    await ghiLop([
      Lop('7A', 'tr', 'Ngữ văn', [for (final ten in _tenLop7A) HocSinh(ten)]),
    ]);
    await p.setString('lop_dang_day', '7A');

    app.main();
    await cho(t, 3500);
    await b.convertFlutterSurfaceToImage();

    final o = oChuCuaNgay(DateTime.now());
    kq('o_chu_hom_nay: ${o.ten} (${o.tuKhoa}, ${o.hang.length} hàng)');

    await buoc(t, 'o_chu_ngay', () async {
      moTienIch(t.element(find.byType(TrangChu, skipOffstage: false)), timTheoMa('o_chu'));
      await cho(t, 2500);
      await chup(t, '01_o_chu');
      await bam(t, find.text('Giải ngay'), ms: 2500);
      await chup(t, '02_o_chu_ngay');
      // Một câu sai, rồi giải hai hàng đầu
      await go(t, find.byType(TextField), 'chưa biết');
      await bam(t, find.text('Trả lời'));
      await cuonDau(t);
      await chup(t, '03_tra_loi_sai');
      for (var i = 0; i < 2; i++) {
        await go(t, find.byType(TextField), o.hang[i].dapAn.toLowerCase());
        await bam(t, find.text('Trả lời'));
      }
      await cuonDau(t);
      await chup(t, '04_dang_giai');
      for (var i = 2; i < o.hang.length; i++) {
        await go(t, find.byType(TextField), o.hang[i].dapAn);
        await bam(t, find.text('Trả lời'));
      }
      await cuonDau(t);
      await chup(t, '05_xong');
      kq('o_chu_xong: ${find.text('🎉 Xong ô chữ hôm nay!').evaluate().isNotEmpty}');
      await bam(t, find.text('Lưu để chiếu lên lớp'));
      Navigator.of(t.element(find.byType(Scaffold).last)).pop();
      await cho(t, 2500);
      await chup(t, '06_o_chu_sau_khi_giai');
    });

    await buoc(t, 'thu_thach', () async {
      moTienIch(t.element(find.byType(TrangChu, skipOffstage: false)), timTheoMa('cong_cu'));
      await cho(t, 2500);
      await bam(t, find.text('Thử thách'), ms: 2000);
      await chup(t, '10_thu_thach');
      await bam(t, find.text('Chơi'), ms: 2000);
      await chup(t, '11_cau_hoi');
      await bam(t, find.textContaining('Bắt đầu tính giờ'), ms: 3000);
      await chup(t, '12_dem_gio');
      await bam(t, find.text('Dừng giờ, xem đáp án'));
      await bam(t, find.text('Bùi Thu Hà'), ms: 300);
      await bam(t, find.text('Ngô Đức Huy'), ms: 300);
      await chup(t, '13_dap_an_chon_em_sai');
      await bam(t, find.text('Câu tiếp theo'));
      // Câu trắc nghiệm (câu 7) để xem đáp án kèm lựa chọn
      final mau = boThuThachMau();
      for (var i = 1; i < mau.cau.length; i++) {
        await bam(t, find.textContaining('Bắt đầu tính giờ'), ms: 600);
        await bam(t, find.text('Dừng giờ, xem đáp án'), ms: 600);
        if (i == 6) await chup(t, '14_cau_trac_nghiem');
        await bam(t, find.text(i == mau.cau.length - 1 ? 'Xem kết quả' : 'Câu tiếp theo'));
      }
      await chup(t, '15_ket_thuc');
    });

    await buoc(t, 'soan_bo', () async {
      moTienIch(t.element(find.byType(TrangChu, skipOffstage: false)), timTheoMa('cong_cu'));
      await cho(t, 2500);
      await bam(t, find.text('Thử thách'), ms: 2000);
      await bam(t, find.text('Bộ câu hỏi mới'), ms: 2000);
      await t.enterText(find.widgetWithText(TextField, 'Tên bộ câu hỏi'), 'Ôn tập Bài 6, Ngữ văn 7');
      await t.enterText(
        find.widgetWithText(TextField, 'Câu hỏi và đáp án'),
        'Câu 1: Tác giả bài thơ "Tiếng gà trưa"?\nĐáp án: Xuân Quỳnh\n\n'
        'Câu 2: Thể thơ có dòng 6 tiếng và dòng 8 tiếng xen kẽ?\nĐáp án: Lục bát\n\n'
        'Biện pháp tu từ gán đặc điểm của người cho vật? | Nhân hóa',
      );
      await cho(t, 800);
      FocusManager.instance.primaryFocus?.unfocus();
      await cuonDau(t);
      await chup(t, '20_soan_bo_dan_chu');
      // Nhờ AI soạn thật qua máy chủ, xem câu trả lời đọc ra được mấy câu
      await bam(t, find.text('Nhờ AI soạn câu hỏi'), ms: 1500);
      await t.enterText(find.widgetWithText(TextField, 'Chủ đề, bài học'), 'Phân số, Toán 6');
      await cho(t, 500);
      await go(t, find.widgetWithText(TextField, 'Dành cho lớp (không bắt buộc)'), 'lớp 6');
      await bam(t, find.text('Soạn'), ms: 1000);
      var xong = false;
      for (var i = 0; i < 120 && !xong; i++) {
        await cho(t, 1000);
        xong = find.textContaining('Bản do AI soạn').evaluate().isNotEmpty;
      }
      await cho(t, 1000);
      await chup(t, '21_ai_soan');
      // Phần app đọc ra từ câu trả lời của AI: số câu, đáp án từng câu
      await cuonToi(t, find.textContaining('Đọc được'));
      final docDuoc = find.textContaining('Đọc được').evaluate().map((e) => (e.widget as Text).data).join(' | ');
      kq('ai_soan: ${xong ? "co ket qua" : "KHONG CO KET QUA"}; $docDuoc');
      if (find.textContaining('Đọc được').evaluate().isNotEmpty) {
        await Scrollable.ensureVisible(t.element(find.textContaining('Đọc được').first), alignment: 0.05);
      }
      await chup(t, '21b_ai_soan_doc_duoc');
      await bam(t, find.text('Lưu bộ câu hỏi'), ms: 2000);
      await chup(t, '22_danh_sach_bo');
    });

    // Thẻ Công cụ trên lớp, mô tả mới trên trang chủ
    await buoc(t, 'ket_thuc', () async {
      await chup(t, '30_trang_chu');
    });
  });
}
