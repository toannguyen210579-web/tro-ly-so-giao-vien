import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tro_ly_so_giao_vien/quoc_te/cong_cu_qt.dart';
import 'package:tro_ly_so_giao_vien/quoc_te/ngon_ngu.dart';
import 'package:tro_ly_so_giao_vien/quoc_te/quoc_te.dart';
import 'package:tro_ly_so_giao_vien/quoc_te/trang_chu_qt.dart';
import 'package:tro_ly_so_giao_vien/screens/quet_pdf.dart';

final _khoaAnh = GlobalKey();

Widget _app() => RepaintBoundary(
      key: _khoaAnh,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF1F6FE5), fontFamily: 'BVP'),
        home: ValueListenableBuilder<String>(
          valueListenable: tieng,
          builder: (_, ma, __) => TrangChuQT(key: ValueKey('qt_$ma')),
        ),
      ),
    );

/// Chụp màn đang vẽ ra build/anh_qt/<ten>.png để xem lại (không so ảnh).
Future<void> _chup(WidgetTester t, String ten) async {
  await t.runAsync(() async {
    final b = _khoaAnh.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final anh = await b.toImage(pixelRatio: 2);
    final d = await anh.toByteData(format: ui.ImageByteFormat.png);
    final f = File('build/anh_qt/$ten.png');
    f.parent.createSync(recursive: true);
    f.writeAsBytesSync(d!.buffer.asUint8List());
  });
}

Future<void> _napPhong() async {
  final l = FontLoader('BVP');
  for (final f in ['BeVietnamPro-Regular.ttf', 'BeVietnamPro-Bold.ttf']) {
    final b = File('assets/fonts/$f').readAsBytesSync();
    l.addFont(Future.value(ByteData.view(b.buffer)));
  }
  await l.load();
  final i = FontLoader('MaterialIcons');
  final thu = Platform.environment['FLUTTER_ROOT'];
  final duong = '$thu/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
  if (thu != null && File(duong).existsSync()) {
    i.addFont(Future.value(ByteData.view(File(duong).readAsBytesSync().buffer)));
    await i.load();
  }
}

void main() {
  setUpAll(_napPhong);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    tieng.value = 'en';
    laQuocTe = true;
  });

  test('Bảng chữ: 21 thứ tiếng, đủ khóa, giữ đúng chỗ {n}', () {
    expect(bangChu.length, 21);
    expect(tenTieng.keys.toSet(), bangChu.keys.toSet());
    final en = bangChu['en']!;
    for (final e in bangChu.entries) {
      expect(e.value.keys.toSet(), en.keys.toSet(), reason: e.key);
      for (final k in en.keys) {
        expect(e.value[k]!.trim().isNotEmpty, true, reason: '${e.key}/$k');
        expect(e.value[k]!.contains('{n}'), en[k]!.contains('{n}'), reason: '${e.key}/$k');
      }
    }
  });

  test('Lấy chữ, chọn tiếng theo máy, tách danh sách tên', () {
    expect(chu('group', n: 3, ma: 'en'), 'Group 3');
    expect(chu('group', n: 3, ma: 'vi'), 'Nhóm 3');
    expect(chu('khong_co_khoa'), 'khong_co_khoa');
    expect(tiengTheoMay(const [Locale('sv'), Locale('ja', 'JP')]), 'ja');
    expect(tiengTheoMay(const [Locale('sv')]), 'en');
    expect(LopQT.tach(' An \n\nBình\r\nAn\nChi '), ['An', 'Bình', 'Chi']);
  });

  testWidgets('Trang chủ: 6 công cụ, đổi tiếng thì chữ đổi và được nhớ', (t) async {
    await t.binding.setSurfaceSize(const Size(390, 844));
    await t.pumpWidget(_app());
    await t.pumpAndSettle();
    for (final k in ['timer', 'picker', 'groups', 'score', 'attendance', 'scan']) {
      expect(find.text(bangChu['en']![k]!), findsOneWidget, reason: k);
    }
    await _chup(t, '01_trang_chu_en');
    await t.tap(find.byKey(const ValueKey('nut_tieng')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('tieng_es')));
    await t.pumpAndSettle();
    expect(find.text('Temporizador'), findsOneWidget);
    expect((await SharedPreferences.getInstance()).getString('qt_tieng'), 'es');
    await _chup(t, '02_trang_chu_es');
  });

  testWidgets('Đồng hồ đếm ngược chạy, tạm dừng, hết giờ', (t) async {
    await t.binding.setSurfaceSize(const Size(390, 844));
    await t.pumpWidget(_app());
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('o_timer')));
    await t.pumpAndSettle();
    expect(find.text('05:00'), findsOneWidget);
    await t.tap(find.text('1'));
    await t.pump();
    expect(find.text('01:00'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('nut_chay')));
    await t.pump(const Duration(seconds: 3));
    expect(find.text('00:57'), findsOneWidget);
    await _chup(t, '03_dong_ho_en');
    await t.tap(find.byKey(const ValueKey('nut_chay')));
    await t.pump(const Duration(seconds: 5));
    expect(find.text('00:57'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('nut_chay')));
    await t.pump(const Duration(seconds: 58));
    expect(find.text('00:00'), findsOneWidget);
    expect(find.text("Time's up!"), findsOneWidget);
  });

  testWidgets('Chưa có lớp thì mời nhập; nhập xong gọi tên, chia nhóm, điểm danh dùng được', (t) async {
    await t.binding.setSurfaceSize(const Size(390, 844));
    await t.pumpWidget(_app());
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('o_picker')));
    await t.pumpAndSettle();
    expect(find.text(bangChu['en']!['needNames']!), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('nut_nhap_lop')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('o_ten')), 'Ana\nBen\nChloe\nDiego\nEmma\nFinn\nGrace');
    await t.tap(find.byKey(const ValueKey('nut_xong')));
    await t.pumpAndSettle();
    expect(await LopQT.doc(), hasLength(7));

    // Gọi tên: gọi 7 lần không lặp thì đủ 7 em
    final da = <String>{};
    for (var i = 0; i < 7; i++) {
      await t.tap(find.byKey(const ValueKey('nut_goi')));
      // Tên chạy lướt khoảng 1,3 giây rồi mới dừng: cho đồng hồ chạy đủ
      for (var k = 0; k < 20; k++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      da.add(t.widget<Text>(find.byKey(const ValueKey('ten_duoc_goi'))).data!);
    }
    expect(da.length, 7);
    await _chup(t, '04_goi_ten_en');
    await t.pageBack();
    await t.pumpAndSettle();

    // Chia nhóm
    await t.tap(find.byKey(const ValueKey('o_groups')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('nut_chia')));
    await t.pumpAndSettle();
    expect(find.text('Group 4'), findsOneWidget);
    expect(find.text('Group 5'), findsNothing);
    await _chup(t, '05_chia_nhom_en');
    await t.pageBack();
    await t.pumpAndSettle();

    // Điểm danh
    await t.tap(find.byKey(const ValueKey('o_attendance')));
    await t.pumpAndSettle();
    expect(find.text('Present: 7/7'), findsOneWidget);
    await t.tap(find.text('Ben'));
    await t.pump();
    expect(find.text('Present: 6/7'), findsOneWidget);
    expect(find.text('Late'), findsOneWidget);
    await _chup(t, '06_diem_danh_en');
  });

  testWidgets('Bảng điểm đội: cộng, trừ, thêm đội, mở lại vẫn còn điểm', (t) async {
    await t.binding.setSurfaceSize(const Size(390, 844));
    await t.pumpWidget(const MaterialApp(home: BangDiemQT()));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('cong_0')));
    await t.tap(find.byKey(const ValueKey('cong_0')));
    await t.tap(find.byKey(const ValueKey('tru_1')));
    await t.tap(find.byKey(const ValueKey('nut_them_doi')));
    await t.pumpAndSettle();
    expect(t.widget<Text>(find.byKey(const ValueKey('diem_0'))).data, '2');
    expect(t.widget<Text>(find.byKey(const ValueKey('diem_1'))).data, '-1');
    expect(find.text('Team 3'), findsOneWidget);
    expect(await DiemDoiQT.doc(), [2, -1, 0]);
  });

  testWidgets('Quét PDF: bản quốc tế hiện chữ theo tiếng đã chọn, bản Việt giữ nguyên', (t) async {
    await t.binding.setSurfaceSize(const Size(390, 844));
    // Máy thử không có thư mục tài liệu của điện thoại: trả về thư mục tạm
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (c) async => Directory.systemTemp.path,
    );
    tieng.value = 'fr';
    await t.pumpWidget(_app());
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('o_scan')));
    await t.pumpAndSettle();
    expect(find.text('Scanner en PDF'), findsOneWidget);
    expect(find.text('Scanner des pages'), findsOneWidget);
    expect(find.text('Choisir des photos'), findsOneWidget);
    expect(find.text('Quét PDF'), findsNothing);
    expect(find.textContaining('Thầy cô'), findsNothing);
    await _chup(t, '07_quet_pdf_fr');

    laQuocTe = false;
    await t.pumpWidget(const MaterialApp(home: QuetPdf()));
    await t.pumpAndSettle();
    expect(find.text('Quét PDF'), findsOneWidget);
    expect(find.text('Chụp, quét giấy tờ'), findsOneWidget);
    expect(find.text('Tệp PDF đã lưu'), findsOneWidget);
  });

  testWidgets('Không tràn chữ ở trang chủ với cả 21 thứ tiếng (màn 360×740)', (t) async {
    await t.binding.setSurfaceSize(const Size(360, 740));
    for (final ma in bangChu.keys) {
      tieng.value = ma;
      await t.pumpWidget(_app());
      await t.pumpAndSettle();
      expect(t.takeException(), isNull, reason: ma);
    }
  });
}
