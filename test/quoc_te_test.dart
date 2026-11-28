import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tro_ly_so_giao_vien/data/o_chu.dart';
import 'package:tro_ly_so_giao_vien/quoc_te/ai_qt.dart';
import 'package:tro_ly_so_giao_vien/quoc_te/cong_cu_qt.dart';
import 'package:tro_ly_so_giao_vien/quoc_te/ngon_ngu.dart';
import 'package:tro_ly_so_giao_vien/quoc_te/quoc_te.dart';
import 'package:tro_ly_so_giao_vien/quoc_te/trang_chu_qt.dart';
import 'package:tro_ly_so_giao_vien/screens/anh_the.dart';
import 'package:tro_ly_so_giao_vien/screens/cham_trac_nghiem.dart';
import 'package:tro_ly_so_giao_vien/screens/gio_the.dart';
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
        if (k != 'cwKeyHelp') expect(e.value[k]!.contains('{m}'), en[k]!.contains('{m}'), reason: '${e.key}/$k');
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

  testWidgets('Trang chủ: 11 công cụ, đổi tiếng thì chữ đổi và được nhớ', (t) async {
    await t.binding.setSurfaceSize(const Size(390, 844));
    await t.pumpWidget(_app());
    await t.pumpAndSettle();
    expect(bangChu['en']!['score'], 'Scoreboard');
    for (final k in ['timer', 'picker', 'groups', 'score', 'attendance', 'scan', 'idPhoto', 'answerCards', 'quizGrader', 'crossword', 'aiTools']) {
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

  testWidgets('Ảnh thẻ: bản quốc tế hiện chữ theo tiếng đã chọn, bản Việt giữ nguyên', (t) async {
    await t.binding.setSurfaceSize(const Size(390, 844));
    tieng.value = 'de';
    await t.pumpWidget(_app());
    await t.pumpAndSettle();
    await t.ensureVisible(find.byKey(const ValueKey('o_idPhoto')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('o_idPhoto')));
    await t.pumpAndSettle();
    expect(find.text('Passfoto'), findsOneWidget);
    expect(find.text('Foto aufnehmen'), findsOneWidget);
    expect(find.text('Hintergrund'), findsOneWidget);
    expect(find.text('35 x 45 mm'), findsOneWidget);
    expect(find.text('2 x 2 in'), findsOneWidget);
    expect(find.text('3 x 4 cm'), findsNothing);
    expect(find.text('Ảnh thẻ'), findsNothing);
    await _chup(t, '08_anh_the_de');

    laQuocTe = false;
    await t.pumpWidget(const MaterialApp(home: AnhThe()));
    await t.pumpAndSettle();
    expect(find.text('Ảnh thẻ'), findsOneWidget);
    expect(find.text('Chụp ảnh'), findsOneWidget);
    expect(find.text('Màu nền'), findsOneWidget);
    expect(find.text('3 x 4 cm'), findsOneWidget);
    expect(find.text('35 x 45 mm'), findsNothing);
    expect([for (final c in ['3x4', '4x6', '35x45', '2x2in']) soAnhTrenTo(c)], [8, 3, 8, 2]);
  });

  test('Ô chữ bản quốc tế nhận chữ cái của mọi thứ tiếng; bản Việt giữ cách cũ', () {
    expect(chuanHoaO('El Niño, 2024!'), 'ELNIÑO2024');
    expect(chuanHoaO('Москва'), 'МОСКВА');
    expect(chuanHoaO('Điện Biên'), 'DIENBIEN');
    final o = OChu(id: '1', ten: 't', tuKhoa: 'Map', hang: [HangO('a', 'Moon'), HangO('b', 'Earth'), HangO('c', 'Pacific')]);
    expect(o.loi, isEmpty);
    final sai = OChu(id: '2', ten: 't', tuKhoa: 'AB', hang: [HangO('a', 'Xyz')]);
    expect(sai.loi.first, 'The keyword has 2 letters, so it needs 2 rows (now 1).');
    laQuocTe = false;
    expect(chuanHoaO('El Niño'), 'ELNIO');
    expect(sai.loi.first, 'Từ khóa có 2 chữ cái, cần đúng 2 hàng ngang (đang có 1).');
  });

  testWidgets('Ô chữ: bản quốc tế có ô chữ mẫu tiếng Anh, chơi được, không hiện ô chữ mỗi ngày', (t) async {
    await t.binding.setSurfaceSize(const Size(390, 844));
    await t.pumpWidget(_app());
    await t.pumpAndSettle();
    await t.ensureVisible(find.byKey(const ValueKey('o_crossword')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('o_crossword')));
    await t.pumpAndSettle();
    expect(find.text('My crosswords'), findsOneWidget);
    expect(find.text('Sample: Geography'), findsOneWidget);
    expect(find.text('3 rows · keyword of 3 letters'), findsOneWidget);
    expect(find.textContaining('Ô chữ'), findsNothing);
    await _chup(t, '09_o_chu_en');
    await t.tap(find.text('Play'));
    await t.pumpAndSettle();
    expect(find.text('Reveal keyword'), findsOneWidget);
    await t.tap(find.text('Reveal keyword'));
    await t.pumpAndSettle();
    expect(find.text('KEYWORD: MAP'), findsOneWidget);
    await _chup(t, '10_choi_o_chu_en');
  });

  testWidgets('Giơ thẻ: bản quốc tế dùng danh sách lớp chung, chữ theo tiếng đã chọn', (t) async {
    await t.binding.setSurfaceSize(const Size(390, 844));
    SharedPreferences.setMockInitialValues({
      'qt_lop': ['Ana', 'Ben', 'Chloe', 'Diego'],
    });
    await t.pumpWidget(_app());
    await t.pumpAndSettle();
    await t.ensureVisible(find.byKey(const ValueKey('o_answerCards')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('o_answerCards')));
    await t.pumpAndSettle();
    expect(find.text('Answer cards'), findsOneWidget);
    expect(find.text('Print cards (4 cards, 2 per A4 page)'), findsOneWidget);
    expect(find.text('Received 0/4'), findsOneWidget);
    expect(find.textContaining('Thầy cô'), findsNothing);
    expect(find.textContaining('thẻ'), findsNothing);
    await _chup(t, '11_gio_the_en');

    laQuocTe = false;
    SharedPreferences.setMockInitialValues({});
    await t.pumpWidget(const MaterialApp(home: GioThe()));
    await t.pumpAndSettle();
    expect(find.text('Giơ thẻ'), findsOneWidget);
    expect(find.text('Chụp cả lớp'), findsOneWidget);
  });

  testWidgets('Chấm trắc nghiệm: bản quốc tế tạo bài, chữ theo tiếng đã chọn; bản Việt giữ nguyên', (t) async {
    await t.binding.setSurfaceSize(const Size(390, 844));
    await t.pumpWidget(_app());
    await t.pumpAndSettle();
    await t.ensureVisible(find.byKey(const ValueKey('o_quizGrader')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('o_quizGrader')));
    await t.pumpAndSettle();
    expect(find.text('Grade quizzes'), findsOneWidget);
    expect(find.text('No quizzes yet.'), findsOneWidget);
    expect(find.textContaining('Thầy cô'), findsNothing);
    await _chup(t, '12_cham_trac_nghiem_en');
    await t.tap(find.text('New quiz'));
    await t.pumpAndSettle();
    expect(find.text('Quiz name'), findsOneWidget);
    expect(find.text('Number of questions'), findsOneWidget);
    expect(find.text('Create'), findsOneWidget);
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();

    laQuocTe = false;
    await t.pumpWidget(const MaterialApp(home: ChamTracNghiem()));
    await t.pumpAndSettle();
    expect(find.text('Chấm trắc nghiệm'), findsOneWidget);
    expect(find.text('Chưa có bài kiểm tra nào.'), findsOneWidget);
  });

  testWidgets('Trợ lý AI: gửi đúng công cụ và ngôn ngữ, hiện kết quả, số lượt còn lại, báo hết lượt', (t) async {
    await t.binding.setSurfaceSize(const Size(390, 844));
    final daGui = <Map<String, dynamic>>[];
    var traLoi = <String, dynamic>{'ok': true, 'text': '1. What do plants need?\nANSWER KEY: 1A', 'remaining': 4};
    guiAiQT = (du) async {
      daGui.add(du);
      return traLoi;
    };
    tieng.value = 'es';
    await t.pumpWidget(_app());
    await t.pumpAndSettle();
    await t.ensureVisible(find.byKey(const ValueKey('o_aiTools')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('o_aiTools')));
    await t.pumpAndSettle();
    for (final (ma, _, _) in congCuAiQT) {
      expect(find.text(bangChu['es']!['ai_$ma']!), findsOneWidget, reason: ma);
    }
    await _chup(t, '13_tro_ly_ai_es');
    await t.tap(find.byKey(const ValueKey('ai_quiz')));
    await t.pumpAndSettle();
    // Chưa nhập thì nhắc, không gửi
    await t.tap(find.byKey(const ValueKey('ai_tao')));
    await t.pump();
    expect(find.text(bangChu['es']!['aiEmpty']!), findsOneWidget);
    expect(daGui, isEmpty);
    await t.enterText(find.byKey(const ValueKey('ai_noi_dung')), 'La fotosíntesis');
    await t.tap(find.byKey(const ValueKey('ai_tao')));
    await t.pumpAndSettle();
    expect(daGui.single['mode'], 'qt');
    expect(daGui.single['tool'], 'quiz');
    expect(daGui.single['lang'], 'Español');
    expect(daGui.single['input'], 'La fotosíntesis');
    expect(find.textContaining('ANSWER KEY: 1A'), findsOneWidget);
    expect(find.text(chu('aiLeft', n: 4)), findsOneWidget);
    await _chup(t, '14_ket_qua_ai_es');
    traLoi = {'ok': false, 'error': 'het_luot'};
    await t.tap(find.byKey(const ValueKey('ai_tao')));
    await t.pumpAndSettle();
    expect(find.text(bangChu['es']!['aiErrLimit']!), findsOneWidget);
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
