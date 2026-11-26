// Chụp màn hình tiện ích Đánh giá, xếp loại (NĐ 233/2026) để xem giao diện và làm clip giới thiệu.
// Dữ liệu mẫu là dữ liệu tự đặt. Ảnh lưu vào anh_chay_thu/xem_*.png.

import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tro_ly_so_giao_vien/data/danh_gia.dart';
import 'package:tro_ly_so_giao_vien/data/tien_ich.dart';
import 'package:tro_ly_so_giao_vien/main.dart' as app;
import 'package:tro_ly_so_giao_vien/screens/dieu_huong.dart';
import 'package:tro_ly_so_giao_vien/screens/trang_chu.dart';

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

  Future<void> cuon(WidgetTester t, double dy) async {
    try {
      final sc = find.descendant(of: find.byType(ListView).last, matching: find.byType(Scrollable)).first;
      final vt = t.state<ScrollableState>(sc).position;
      vt.jumpTo(min(max(0, vt.pixels + dy), vt.maxScrollExtent));
    } catch (_) {}
    await cho(t, 600);
  }

  Future<void> bam(WidgetTester t, Finder f, {int ms = 1200}) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await cho(t, 400);
    await t.ensureVisible(f.first);
    await cho(t, 300);
    await t.tap(f.first);
    await cho(t, ms);
  }

  testWidgets('Xem Đánh giá, xếp loại', (t) async {
    FlutterError.onError = (d) => kq('loi_giao_dien: ${d.exceptionAsString().split('\n').first}');
    final p = await SharedPreferences.getInstance();
    await p.setString('hs_ten', 'Nguyễn Thị Lan');
    await p.setString('hs_truong', 'Trường THCS Hòa Bình');
    final q = QuyCheDanhGia();
    final nam = namDanhGia(q, DateTime.now());
    final moc = cacKy(q, nam);
    await KhoDanhGia.ghiKy({
      moc[0].ma: KyDanhGia(ma: moc[0].ma, chung: [10, 12, 7.5], viec: [
        ViecGiao(ten: 'Dạy đủ 19 tiết/tuần môn Toán 7'),
        ViecGiao(ten: 'Kế hoạch bài dạy học kỳ I'),
        ViecGiao(ten: 'Chủ nhiệm lớp 7A'),
      ], diemTruong: 92),
      moc[1].ma: KyDanhGia(ma: moc[1].ma, chung: [10, 11.5, 7], viec: [
        ViecGiao(ten: 'Dạy đủ 19 tiết/tuần môn Toán 7'),
        ViecGiao(ten: 'Bồi dưỡng học sinh giỏi', chatLuong: 1),
        ViecGiao(ten: 'Nộp sổ điểm giữa kỳ', tienDo: 1),
      ]),
    });

    app.main();
    await cho(t, 3500);
    await b.convertFlutterSurfaceToImage();

    try {
      moTienIch(t.element(find.byType(TrangChu, skipOffstage: false)), timTheoMa('danh_gia'));
      await cho(t, 2500);
      kq('binh_quan: ${t.widget<Text>(find.byKey(const Key('dg_binh_quan'))).data}');
      await chup(t, '01_cac_ky');
      await cuon(t, 500);
      await chup(t, '02_cac_ky_duoi');

      // Chấm tháng thứ ba: trừ nửa điểm nhóm 3, thêm hai việc
      await cuon(t, -2000);
      await bam(t, find.byKey(Key('dg_ky_${moc[2].ma}')), ms: 2000);
      await bam(t, find.byTooltip('Trừ nửa điểm').at(2));
      await bam(t, find.byKey(const Key('dg_them_viec')));
      await t.enterText(find.byKey(const Key('dg_ten_viec_0')), 'Dạy đủ 19 tiết/tuần môn Toán 7');
      await bam(t, find.byKey(const Key('dg_them_viec')));
      await t.enterText(find.byKey(const Key('dg_ten_viec_1')), 'Hồ sơ thi giáo viên dạy giỏi');
      await bam(t, find.text('Trễ hạn').last);
      await cho(t, 600);
      await cuon(t, -2000);
      kq('tong_ky_3: ${t.widget<Text>(find.byKey(const Key('dg_tong_ky'))).data}');
      await chup(t, '03_cham_thang');
      await cuon(t, 650);
      await chup(t, '04_cham_viec');
      await bam(t, find.byKey(const Key('dg_luu_ky')), ms: 2000);
      kq('binh_quan_sau: ${t.widget<Text>(find.byKey(const Key('dg_binh_quan'))).data}');
      await chup(t, '05_sau_luu');

      await bam(t, find.text('Phiếu năm'), ms: 1500);
      await t.enterText(find.byKey(const Key('dg_uu_diem')), '- Dạy đủ 19 tiết/tuần, kế hoạch bài dạy nộp đúng hạn.\n- Chủ nhiệm lớp 7A nề nếp tốt.');
      await t.enterText(find.byKey(const Key('dg_han_che')), '- Nộp sổ điểm giữa kỳ còn trễ hạn.');
      await cho(t, 600);
      await chup(t, '06_phieu');
      await cuon(t, 900);
      kq('tu_xep_loai: ${t.widget<Text>(find.byKey(const Key('dg_tu_xep_loai'))).data}');
      await chup(t, '07_phieu_duoi');
      await bam(t, find.byKey(const Key('dg_luu_phieu')), ms: 4000);
      await chup(t, '08_da_luu');
      final thu = Directory('${(await getApplicationDocumentsDirectory()).path}/xuat');
      final tep = thu.existsSync() ? thu.listSync().map((e) => e.path.split('/').last).where((e) => e.startsWith('Phieu_xep_loai')).toList() : <String>[];
      kq('tep_phieu: ${tep.join(', ')}');
      for (final f in thu.listSync().whereType<File>().where((f) => f.path.contains('Phieu_xep_loai'))) {
        kq('co_tep ${f.path.split('/').last}: ${f.lengthSync()} byte');
      }
      Navigator.of(t.element(find.byType(TabBar))).maybePop();
      await cho(t, 1000);

      await bam(t, find.text('Quy chế'), ms: 1500);
      await chup(t, '09_quy_che');
      kq('danh_gia: xong');
    } catch (e, st) {
      kq('danh_gia: LOI ${e.toString().split('\n').first}');
      kq('tai ${st.toString().split('\n').where((d) => d.contains('xem_danh_gia') || d.contains('lib/')).take(4).join(' <- ')}');
      await chup(t, 'loi');
    }
  });
}
