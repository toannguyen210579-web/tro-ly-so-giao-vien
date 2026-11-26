import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tro_ly_so_giao_vien/data/o_chu.dart';
import 'package:tro_ly_so_giao_vien/data/o_chu_moi_ngay.dart';
import 'package:tro_ly_so_giao_vien/data/o_chu_ngay_kho.dart';
import 'package:tro_ly_so_giao_vien/screens/o_chu_moi_ngay.dart';

void main() {
  test('Mọi ô trong kho hợp lệ, vừa màn hình điện thoại, không trùng chủ đề', () {
    expect(khoOChuNgay.length, greaterThanOrEqualTo(30));
    final ten = <String>{};
    for (var i = 0; i < khoOChuNgay.length; i++) {
      final (chuDe, khoa, hang) = khoOChuNgay[i];
      final o = OChu(id: '$i', ten: chuDe, tuKhoa: khoa, hang: [for (final (h, d) in hang) HangO(h, d)]);
      expect(o.loi, isEmpty, reason: chuDe);
      expect(o.hang.length, inInclusiveRange(5, 7), reason: chuDe);
      expect(o.soCot, lessThanOrEqualTo(12), reason: chuDe);
      for (final h in o.hang) {
        expect(h.cauHoi.trim(), isNotEmpty, reason: chuDe);
        expect(h.chu.length, inInclusiveRange(2, 11), reason: '$chuDe: ${h.dapAn}');
      }
      expect(ten.add(chuDe), isTrue, reason: 'trùng chủ đề $chuDe');
    }
  });

  test('Mỗi ngày một ô khác nhau, đủ một vòng kho rồi mới lặp lại', () {
    final dau = DateTime(2026, 11, 24);
    final da = <int>{};
    for (var i = 0; i < khoOChuNgay.length; i++) {
      da.add(soOChuCuaNgay(DateTime(dau.year, dau.month, dau.day + i)));
    }
    expect(da.length, khoOChuNgay.length);
    expect(soOChuCuaNgay(DateTime(2026, 11, 24, 23, 59)), soOChuCuaNgay(DateTime(2026, 11, 24, 0, 1)));
    expect(soOChuCuaNgay(DateTime(2025, 12, 31)), khoOChuNgay.length - 1);
    expect(oChuCuaNgay(dau).id, 'ngay_20261124');
    expect(maNgay(DateTime(2026, 1, 5)), '20260105');
    expect(ngayDayDu(dau), 'Thứ ba, 24/11/2026');
  });

  test('Đáp án gõ có dấu, không dấu, viết số đều nhận', () {
    expect(khopDapAn('chin', 'Chín'), isTrue);
    expect(khopDapAn('9', 'Chín'), isTrue);
    expect(khopDapAn(' ha  noi ', 'Hà Nội'), isTrue);
    expect(khopDapAn('com pa', 'Com-pa'), isTrue);
    expect(khopDapAn('trung', "T'rưng"), isTrue);
    expect(khopDapAn('', 'Chín'), isFalse);
    expect(khopDapAn('Huế', 'Hà Nội'), isFalse);
  });

  test('Giải từng hàng, xem đáp án, đoán từ khóa', () {
    final o = oChuCuaNgay(DateTime(2026, 11, 24));
    final t0 = DateTime(2026, 11, 24, 8);
    final t = TienDoNgay.moi('20261124', o.hang.length, t0);
    expect(t.traLoi(o, 0, 'sai bét', t0), isFalse);
    expect(t.traLoi(o, 0, o.hang[0].dapAn, t0), isTrue);
    expect(t.hang[0], TrangThaiHang.dungSauSai);
    expect(t.traLoi(o, 1, o.hang[1].dapAn.toLowerCase(), t0), isTrue);
    expect(t.hang[1], TrangThaiHang.dungNgay);
    t.moDapAn(2, t0);
    expect(t.hang[2], TrangThaiHang.xemDapAn);
    expect(t.hangKeTiep(2), 3);
    expect(t.daXong, isFalse);
    expect(t.doanTuKhoa(o, 'không phải', t0), isFalse);
    expect(t.tongSai, 2);
    final xong = t0.add(const Duration(minutes: 3, seconds: 5));
    expect(t.doanTuKhoa(o, o.tuKhoa, xong), isTrue);
    expect(t.daXong, isTrue);
    expect(t.hang.skip(3).every((v) => v == TrangThaiHang.boQua), isTrue);
    expect(thoiGianVN(t.thoiGian), '3 phút 05 giây');
    expect(t.soHangGiai, 2);

    final lai = TienDoNgay.fromJson(t.toJson());
    expect(lai.hang, t.hang);
    expect(lai.sai, t.sai);
    expect(lai.doanKhoa, isTrue);
    expect(lai.xong, t.xong);

    final chia = vanBanChiaSe(t, o, DateTime(2026, 11, 24), 3);
    expect(chia, contains('Ô chữ mỗi ngày 24/11/2026'));
    expect(chia, contains('🟨🟩⬜'));
    expect(chia, contains('🔑'));
    expect(chia, contains('Chuỗi 3 ngày liền'));
    for (final h in o.hang) {
      expect(chia.contains(h.dapAn), isFalse, reason: 'lộ đáp án ${h.dapAn}');
    }
  });

  test('Giải hết các hàng là xong', () {
    final o = oChuCuaNgay(DateTime(2026, 11, 25));
    final t0 = DateTime(2026, 11, 25, 20);
    final t = TienDoNgay.moi('20261125', o.hang.length, t0);
    for (var i = 0; i < o.hang.length; i++) {
      expect(t.traLoi(o, i, o.hang[i].dapAn, t0.add(Duration(seconds: 5 * i))), isTrue);
    }
    expect(t.daXong, isTrue);
    expect(t.soHangGiai, o.hang.length);
    expect(thoiGianVN(t.thoiGian), '${5 * (o.hang.length - 1)} giây');
    expect(t.traLoi(o, 0, o.hang[0].dapAn, t0), isFalse, reason: 'đã xong thì không tính thêm');
  });

  test('Chuỗi ngày giải liền nhau', () {
    final nay = DateTime(2026, 3, 1);
    expect(chuoiNgay(['20260226', '20260227', '20260228', '20260301'], nay), 4);
    expect(chuoiNgay(['20260227', '20260228'], nay), 2, reason: 'hôm nay chưa giải thì tính đến hôm qua');
    expect(chuoiNgay(['20260226', '20260301'], nay), 1);
    expect(chuoiNgay([], nay), 0);
  });

  test('Lưu tiến độ, bỏ tiến độ ngày cũ, giữ danh sách ngày đã xong', () async {
    SharedPreferences.setMockInitialValues({'o_chu_ngay_20261120': '{}'});
    final o = oChuCuaNgay(DateTime(2026, 11, 24));
    final t = TienDoNgay.moi('20261124', o.hang.length, DateTime(2026, 11, 24));
    t.doanTuKhoa(o, o.tuKhoa, DateTime(2026, 11, 24, 0, 1));
    await LuuOChuNgay.ghi(t);
    expect((await LuuOChuNgay.doc('20261124'))!.daXong, isTrue);
    expect(await LuuOChuNgay.ngayDaXong(), ['20261124']);
    expect(await LuuOChuNgay.doc('20261120'), isNull);
  });

  testWidgets('Màn Ô chữ mỗi ngày: gõ đáp án từng hàng đến khi xong', (t) async {
    SharedPreferences.setMockInitialValues({});
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    await t.binding.setSurfaceSize(const Size(420, 1800));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final ngay = DateTime(2026, 11, 24);
    final o = oChuCuaNgay(ngay);
    await t.pumpWidget(MaterialApp(home: OChuNgayMan(ngay: ngay)));
    await t.pumpAndSettle();
    expect(find.text('Chủ đề: ${o.ten}'), findsOneWidget);
    expect(find.text(o.hang[0].cauHoi), findsOneWidget);

    await t.enterText(find.byType(TextField), 'không đúng');
    await t.tap(find.text('Trả lời'));
    await t.pumpAndSettle();
    expect(find.text('Chưa đúng, thử lại nhé.'), findsOneWidget);

    for (var i = 0; i < o.hang.length; i++) {
      expect(find.text(o.hang[i].cauHoi), findsOneWidget, reason: 'hàng ${i + 1}');
      await t.enterText(find.byType(TextField), o.hang[i].dapAn);
      await t.tap(find.text('Trả lời'));
      await t.pumpAndSettle();
    }
    expect(find.text('🎉 Xong ô chữ hôm nay!'), findsOneWidget);
    expect(find.text('Từ khóa: ${o.tuKhoa.toUpperCase()}'), findsOneWidget);
    expect(find.text('1 ngày liền'), findsOneWidget);
    expect(find.text('Chia sẻ kết quả'), findsOneWidget);

    // Vào lại: vẫn thấy đã xong
    await t.pumpWidget(const SizedBox());
    await t.pumpWidget(MaterialApp(home: OChuNgayMan(ngay: ngay)));
    await t.pumpAndSettle();
    expect(find.text('🎉 Xong ô chữ hôm nay!'), findsOneWidget);
    expect(find.text('🔥 1 ngày liền'), findsOneWidget);

    await t.tap(find.text('Lưu để chiếu lên lớp'));
    await t.pumpAndSettle();
    expect(find.textContaining('Đã lưu vào danh sách Ô chữ'), findsOneWidget);
  });
}
