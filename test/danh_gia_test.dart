import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tro_ly_so_giao_vien/data/danh_gia.dart';
import 'package:tro_ly_so_giao_vien/screens/danh_gia_xep_loai.dart' show tachUuHanChe;
import 'package:tro_ly_so_giao_vien/services/tep_word.dart';

void main() {
  test('Mức xếp loại theo Điều 12 Nghị định 233/2026', () {
    expect(mucTheoDiem(90), 0);
    expect(mucTheoDiem(89.99), 1);
    expect(mucTheoDiem(70), 1);
    expect(mucTheoDiem(69.5), 2);
    expect(mucTheoDiem(50), 2);
    expect(mucTheoDiem(49.9), 3);
  });

  test('Điểm mẫu: chung 30, nhiệm vụ 70; sửa sai tổng thì báo lỗi', () {
    final q = QuyCheDanhGia();
    expect(q.tongChung, 30);
    expect(q.tongNhiemVu, 70);
    expect(q.loiDiem, isEmpty);
    q.chung = [10, 10, 8];
    expect(q.loiDiem, contains('30 điểm'));
  });

  test('Tính điểm một kỳ: tiêu chí chung cộng ba thành phần nhiệm vụ', () {
    final q = QuyCheDanhGia();
    final k = KyDanhGia(ma: '2026-09', chung: [10, 12, 8], viec: [
      ViecGiao(ten: 'Dạy đủ tiết'), // Đủ, Tốt, Đúng hạn
      ViecGiao(ten: 'Hồ sơ chuyên môn', khoiLuong: 0, chatLuong: 1, tienDo: 1), // Đủ, Đạt (80%), Trễ (60%)
    ]);
    final nv = k.diemNhiemVu(q);
    expect(nv[0], 25); // số lượng
    expect(nv[1], closeTo(27, 0.001)); // 30 x (1 + 0,8) / 2
    expect(nv[2], closeTo(12, 0.001)); // 15 x (1 + 0,6) / 2
    expect(k.diemTuCham(q), closeTo(94, 0.001));
    k.diemTruong = 88;
    expect(k.diem(q), 88); // ưu tiên điểm trường xác nhận
  });

  test('Kỳ năm học: 9 tháng (9 đến 5) hoặc 3 quý; năm công tác 12 tháng', () {
    final q = QuyCheDanhGia();
    final thang = cacKy(q, 2026);
    expect(thang.length, 9);
    expect(thang.first.ma, '2026-09');
    expect(thang.last.ma, '2027-05');
    expect(thang.last.den, DateTime(2027, 6));
    q.theoQuy = true;
    final quy = cacKy(q, 2026);
    expect(quy.map((e) => e.ma), ['2026-Q1', '2026-Q2', '2026-Q3']);
    expect(quy[1].tu, DateTime(2026, 12));
    expect(quy[1].den, DateTime(2027, 3));
    final cv = QuyCheDanhGia(namHoc: false);
    expect(cacKy(cv, 2026).length, 12);
    expect(namDanhGia(q, DateTime(2027, 3, 1)), 2026);
    expect(namDanhGia(q, DateTime(2026, 9, 1)), 2026);
    expect(namDanhGia(cv, DateTime(2027, 3, 1)), 2027);
  });

  test('Tổng hợp năm: bình quân kỳ đã chấm và điểm cần đạt các kỳ còn lại', () {
    final q = QuyCheDanhGia();
    final moc = cacKy(q, 2026);
    final ky = {
      '2026-09': KyDanhGia(ma: '2026-09', diemTruong: 86),
      '2026-10': KyDanhGia(ma: '2026-10', diemTruong: 88),
    };
    final th = tongHop(q, moc, ky);
    expect(th.soKyDaCham, 2);
    expect(th.binhQuan, 87);
    expect(th.muc, 1);
    // Cần (90 x 9 - 174) / 7 = 90,857...
    expect(th.canDatXuatSac, closeTo(90.857, 0.001));
    expect(th.canDatTot, closeTo(65.143, 0.001)); // (70 x 9 - 174) / 7
    expect(tongHop(q, moc, {}).soKyDaCham, 0);
    // Hai phần cộng đúng bằng tổng, kể cả kỳ có điểm trường xác nhận khác điểm tự chấm
    final th2 = tongHop(q, moc, {
      '2026-09': KyDanhGia(ma: '2026-09', chung: [10, 12, 8], viec: [ViecGiao(ten: 'Dạy')], diemTruong: 92),
      '2026-10': KyDanhGia(ma: '2026-10', chung: [10, 11, 7], viec: [ViecGiao(ten: 'Dạy', tienDo: 1)]),
    });
    expect(th2.binhQuanChung + th2.binhQuanNhiemVu, closeTo(th2.binhQuan, 0.0001));
    expect(th2.binhQuan, closeTo((92 + 28 + 64) / 2, 0.0001));
  });

  test('Tự xếp loại: chưa đủ 6 tháng không xếp loại; kỷ luật, suy thoái là Không hoàn thành', () {
    expect(mucTuXepLoai(95, DieuKienNam()), 0);
    expect(mucTuXepLoai(95, DieuKienNam(chuaDu6Thang: true)), isNull);
    expect(mucTuXepLoai(95, DieuKienNam(biKyLuat: true)), 3);
    expect(mucTuXepLoai(75, DieuKienNam(suyThoai: true)), 3);
  });

  test('Lưu và đọc lại trên máy', () async {
    SharedPreferences.setMockInitialValues({});
    final q = QuyCheDanhGia(theoQuy: true, chung: [8, 14, 8]);
    await KhoDanhGia.ghiQuyChe(q);
    expect((await KhoDanhGia.docQuyChe()).chung, [8, 14, 8]);
    expect((await KhoDanhGia.docQuyChe()).theoQuy, true);
    await KhoDanhGia.ghiKy({
      '2026-09': KyDanhGia(ma: '2026-09', chung: [10, 12, 8], viec: [ViecGiao(ten: 'Dạy', chatLuong: 1)]),
      '2026-10': KyDanhGia(ma: '2026-10'), // chưa chấm: không lưu
    });
    final ky = await KhoDanhGia.docKy();
    expect(ky.keys, ['2026-09']);
    expect(ky['2026-09']!.viec.single.chatLuong, 1);
    await KhoDanhGia.ghiPhieu(2026, PhieuNam(hoTen: 'Nguyễn Văn A', dieuKien: DieuKienNam(biKyLuat: true)));
    final ph = await KhoDanhGia.docPhieu(2026);
    expect(ph!.hoTen, 'Nguyễn Văn A');
    expect(ph.dieuKien.biKyLuat, true);
    expect(await KhoDanhGia.docPhieu(2027), isNull);
  });

  test('Nội dung gửi AI không có họ tên, chỉ các việc đã chấm', () {
    final q = QuyCheDanhGia();
    final s = cauHoiUuHanChe(q, cacKy(q, 2026), {
      '2026-09': KyDanhGia(ma: '2026-09', chung: [10, 12, 8], viec: [ViecGiao(ten: 'Bồi dưỡng học sinh giỏi', tienDo: 1)]),
    }, 'Giáo viên');
    expect(s, contains('Tháng 9/2026'));
    expect(s, contains('Bồi dưỡng học sinh giỏi'));
    expect(s, contains('Trễ hạn'));
    expect(s, isNot(contains('Tháng 10')));
  });

  test('Tách câu trả lời AI thành Ưu điểm, Hạn chế', () {
    final (ud, hc) = tachUuHanChe('ƯU ĐIỂM:\n- Dạy đủ tiết.\n- Hồ sơ đầy đủ.\nHẠN CHẾ:\n- Nộp kế hoạch trễ.');
    expect(ud, '- Dạy đủ tiết.\n- Hồ sơ đầy đủ.');
    expect(hc, '- Nộp kế hoạch trễ.');
    final (ud2, hc2) = tachUuHanChe('**Ưu điểm**: tốt');
    expect(ud2, 'tốt');
    expect(hc2, '');
  });

  test('Phiếu Word đúng các mục Phụ lục II, đánh dấu mức tự xếp loại', () {
    final b = taoDocxPhieuXepLoai(
      coQuanTren: 'UBND phường Buôn Hồ',
      donVi: 'Trường THCS A',
      nam: 'Năm học 2026-2027',
      hoTen: 'Nguyễn Văn A',
      chucDanh: 'Giáo viên',
      donViCongTac: 'Trường THCS A',
      diemChung: '29 điểm',
      diemNhiemVu: '60 điểm',
      tongDiem: '89 điểm',
      uuDiem: '- Dạy đủ tiết.',
      hanChe: '',
      mucXepLoai: mucXepLoai,
      mucTu: 1,
    );
    final xml = utf8.decode(ZipDecoder().decodeBytes(b).findFile('word/document.xml')!.content as List<int>);
    for (final muc in [
      'PHIẾU XẾP LOẠI CHẤT LƯỢNG VIÊN CHỨC',
      'I. TỔNG HỢP KẾT QUẢ THEO DÕI, ĐÁNH GIÁ',
      'II. VIÊN CHỨC TỰ ĐÁNH GIÁ, XẾP LOẠI CHẤT LƯỢNG',
      'III. KẾT QUẢ XẾP LOẠI CHẤT LƯỢNG VIÊN CHỨC CỦA CẤP CÓ THẨM QUYỀN',
      'IV. Ý KIẾN NHẬN XÉT CỦA CẤP CÓ THẨM QUYỀN',
      'VIÊN CHỨC TỰ XẾP LOẠI',
      'CẤP CÓ THẨM QUYỀN XẾP LOẠI',
      'TRƯỜNG THCS A',
      'UBND PHƯỜNG BUÔN HỒ',
    ]) {
      expect(xml, contains(muc), reason: muc);
    }
    expect(xml, contains('☒ Hoàn thành tốt nhiệm vụ'));
    expect('☒'.allMatches(xml).length, 1); // mục III để trống
  });
}
