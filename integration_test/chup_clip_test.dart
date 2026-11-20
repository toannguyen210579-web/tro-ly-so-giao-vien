// Chụp màn hình app thật cho clip "Dùng thử tiện ích" của kênh Việt Nam Tiêu Điểm.
// Dữ liệu mẫu (lớp 7A, tên học sinh, biên bản) là dữ liệu tự đặt để minh họa.
// Ảnh lưu vào anh_chay_thu/clip_*.png; dòng "KQ ..." ghi kết quả từng bước.

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tro_ly_so_giao_vien/data/tien_ich.dart';
import 'package:tro_ly_so_giao_vien/main.dart' as app;
import 'package:tro_ly_so_giao_vien/screens/bieu_tuong.dart';
import 'package:tro_ly_so_giao_vien/screens/dieu_huong.dart';
import 'package:tro_ly_so_giao_vien/screens/nhan_xet.dart';
import 'package:tro_ly_so_giao_vien/screens/trang_chu.dart';
import 'package:tro_ly_so_giao_vien/services/giong_may.dart';

import 'chup_clip_anh_the.dart';

/// Trả về ảnh mẫu thay cho máy ảnh, thư viện ảnh (máy giả lập không có máy ảnh thật).
class _AnhMau extends ImagePickerPlatform {
  final String duong;
  _AnhMau(this.duong);

  @override
  Future<XFile?> getImageFromSource({required ImageSource source, ImagePickerOptions options = const ImagePickerOptions()}) async =>
      XFile(duong);

  @override
  Future<XFile?> getImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
  }) async =>
      XFile(duong);
}

const _tenLop7A = [
  'Lê Hoàng An', 'Trần Ngọc Anh', 'Nguyễn Gia Bảo', 'Phạm Minh Châu', 'Võ Thành Đạt', 'Đỗ Hải Đăng', 'Bùi Thu Hà',
  'Hoàng Gia Hân', 'Ngô Đức Huy', 'Đặng Minh Khang', 'Lý Bảo Khánh', 'Trịnh Ngọc Lan', 'Phan Gia Linh', 'Vũ Đức Long',
  'Mai Thảo My', 'Đinh Hoài Nam', 'Tạ Bảo Ngọc', 'Hồ Minh Nhật', 'Lưu Yến Nhi', 'Cao Thành Phát', 'Dương Hà Phương',
  'Lâm Minh Quân', 'Kiều Diễm Quỳnh', 'Tô Đức Tài', 'Châu Minh Thư', 'La Quốc Trung', 'Mạc Thanh Tú', 'Quách Hải Yến',
];

void main() {
  final b = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> cho(WidgetTester t, [int ms = 1500]) async {
    for (var i = 0; i < ms ~/ 100; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  WidgetTester? t0;

  void kq(String s) {
    // ignore: avoid_print
    print('KQ $s');
  }

  void tatThongBao(WidgetTester t) {
    for (final s in t.stateList<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))) {
      s.removeCurrentSnackBar();
    }
  }

  Future<void> chup(WidgetTester t, String ten, {bool giuThongBao = false}) async {
    if (!giuThongBao) tatThongBao(t);
    await cho(t, 700);
    try {
      await b.takeScreenshot('clip_$ten');
      kq('chup $ten: on');
    } catch (e) {
      kq('chup $ten: LOI $e');
    }
  }

  /// Chờ đến khi thấy chữ (tối đa [giay] giây).
  Future<bool> choChu(WidgetTester t, String chu, {int giay = 60}) async {
    for (var i = 0; i < giay * 2; i++) {
      if (find.textContaining(chu).evaluate().isNotEmpty) return true;
      await cho(t, 500);
    }
    return false;
  }

  /// Cuộn danh sách chính của màn đang mở để [f] nằm ở gần đầu màn hình.
  /// Đặt thẳng vị trí cuộn (không kéo tay, vì ô nhập nhiều dòng sẽ giữ lấy thao tác kéo).
  Future<void> cuonDen(WidgetTester t, Finder f, {double viTri = 0.08}) async {
    try {
      final sc = find.descendant(of: find.byType(ListView).last, matching: find.byType(Scrollable)).first;
      final vt = t.state<ScrollableState>(sc).position;
      vt.jumpTo(0);
      await cho(t, 300);
      for (var i = 0; i < 80 && f.evaluate().isEmpty && vt.pixels < vt.maxScrollExtent; i++) {
        vt.jumpTo(min(vt.pixels + 300, vt.maxScrollExtent));
        await cho(t, 200);
      }
      await Scrollable.ensureVisible(t.element(f.first), alignment: viTri);
    } catch (e) {
      kq('cuon: LOI ${e.toString().split('\n').first}');
    }
    await cho(t, 700);
  }

  Future<void> moMa(WidgetTester t, String ma) async {
    moTienIch(t.element(find.byType(TrangChu, skipOffstage: false)), timTheoMa(ma));
    await cho(t, 2500);
  }

  Future<void> quayVe(WidgetTester t, [int lan = 1]) async {
    for (var i = 0; i < lan; i++) {
      Navigator.of(t.element(find.byType(Scaffold).last)).pop();
      await cho(t, 900);
    }
  }

  Future<void> buoc(String ten, Future<void> Function() viec) async {
    try {
      Navigator.of(t0!.element(find.byType(TrangChu, skipOffstage: false))).popUntil((r) => r.isFirst);
      await cho(t0!, 800);
    } catch (_) {}
    try {
      await viec();
    } catch (e) {
      kq('$ten: LOI ${e.toString().split('\n').first}');
    }
  }

  testWidgets('Chụp màn hình cho clip', (t) async {
    t0 = t;
    FlutterError.onError = (d) => kq('loi_giao_dien: ${d.exceptionAsString().split('\n').first}');

    // ---------- dữ liệu mẫu
    final p = await SharedPreferences.getInstance();
    await ghiLop([Lop('7A', 'tr', 'Toán', [for (final n in _tenLop7A) HocSinh(n)])]);
    await p.setString('lop_dang_day', '7A');
    // Tính lương: giáo viên THCS hạng II, bậc 1 (hệ số 4,00), dạy từ 01/9/2016, hưởng bậc từ 01/9/2024
    await p.setString('l_cap', 'THCS');
    await p.setString('l_hang', 'Hạng II');
    await p.setInt('l_bac', 1);
    await p.setInt('l_ud', 0);
    await p.setString('l_vao', DateTime(2016, 9, 1).toIso8601String());
    await p.setString('l_xep', DateTime(2024, 9, 1).toIso8601String());
    // Nhắn phụ huynh
    await p.setString('ph_ten_gv', 'Nguyễn Thị Hoa');
    await p.setString('ph_lop', '7A');
    // Biên bản họp tổ (ghi chép thô, chưa sắp xếp)
    await p.setString('bb_don_vi_tren', 'PHÒNG GIÁO DỤC VÀ ĐÀO TẠO');
    await p.setString('bb_don_vi', 'TRƯỜNG THCS HÒA BÌNH');
    await p.setString('bb_dia_danh', 'Hòa Bình');
    final hop = DateTime.now().subtract(const Duration(hours: 2));
    await p.setString(
      'bien_ban',
      jsonEncode([
        {
          'id': '1',
          'loai': 'Họp tổ chuyên môn',
          've_viec': 'Kế hoạch ôn tập cuối học kỳ I',
          'bat_dau': DateTime(hop.year, hop.month, hop.day, 14, 0).toIso8601String(),
          'ket_thuc': '',
          'dia_diem': 'Phòng họp tổ Toán',
          'chu_tri': 'Cô Trần Thu Lan, tổ trưởng',
          'thu_ky': 'Thầy Phạm Văn Hùng',
          'thanh_phan': '8/8 giáo viên tổ Toán',
          'noi_dung': 'cô lan nêu lớp 9 còn yếu phần hình, đề nghị tăng tiết ôn\n'
              'thầy hùng đồng ý, chia nhóm ôn theo chuyên đề, mỗi người một chuyên đề\n'
              'cô mai đề nghị đầu giờ kiểm tra nhanh 5 phút bằng giơ thẻ\n'
              'cả tổ thống nhất ôn thứ ba, thứ năm từ tuần sau',
          'ket_luan': '',
        }
      ]),
    );
    final tam = await getTemporaryDirectory();
    final anh = File('${tam.path}/ca_lop_gio_the.jpg');
    await anh.writeAsBytes(base64Decode(anhTheLopBase64.join()));
    ImagePickerPlatform.instance = _AnhMau(anh.path);

    app.main();
    await cho(t, 3500);
    await b.convertFlutterSurfaceToImage();
    await chup(t, '00_trang_chu');
    await buoc('xem_du', () async {
      await t.tap(find.text('Khác').first);
      await cho(t, 2000);
      await chup(t, '02_du_15_tien_ich');
      await quayVe(t);
    });

    // ---------- 1. Giọng nói ⇄ Văn bản
    await buoc('giong', () async {
      try {
        await GiongMay.taiVe().timeout(const Duration(minutes: 6));
        kq('giong_may: san sang=${await GiongMay.sanSang()}');
      } catch (e) {
        kq('giong_may: LOI $e');
      }
      await moMa(t, 'doc_to');
      await t.enterText(
        find.widgetWithText(TextField, 'Văn bản cần đọc'),
        'Kính gửi các tổ chuyên môn. Thực hiện kế hoạch năm học, nhà trường đề nghị các tổ nộp kế hoạch ôn tập cuối học kỳ I '
        'về văn phòng trước ngày 30 tháng 11. Các tổ chủ động phân công giáo viên phụ trách từng chuyên đề.',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await cho(t, 800);
      await chup(t, '10_doc_to_truoc');
      await t.tap(find.text('Đọc to'));
      await cho(t, 4000);
      await chup(t, '11_doc_to_dang_doc');
      kq('doc_to: ${find.textContaining('Dừng').evaluate().isNotEmpty ? "dang doc" : "khong thay nut Dung"}');
      final dung = find.textContaining('Dừng');
      if (dung.evaluate().isNotEmpty) await t.tap(dung.first);
      await cho(t, 800);
      await t.tap(find.text('Giọng nói → Văn bản'));
      await cho(t, 1500);
      await chup(t, '12_ghi_loi_trong');
      await t.enterText(
        find.widgetWithText(TextField, 'Chữ đã ghi (sửa trực tiếp được)'),
        'Em chăm chỉ, tiếp thu bài nhanh. Em cần mạnh dạn phát biểu hơn trong giờ học.',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await cho(t, 800);
      await chup(t, '13_ghi_loi_co_chu');
      await quayVe(t);
    });

    // ---------- 2. Tính lương
    await buoc('luong', () async {
      await moMa(t, 'luong');
      await chup(t, '20_luong_tren');
      await t.tap(find.text('Theo cấp dạy (mầm non, tiểu học 45%; THCS, THPT 40%)'));
      await cho(t, 1200);
      await chup(t, '21_luong_muc_uu_dai');
      await t.tap(find.text('Theo cấp dạy (mầm non, tiểu học 45%; THCS, THPT 40%)').last);
      await cho(t, 1000);
      await cuonDen(t, find.text('Lương theo hệ số'), viTri: 0.15);
      await chup(t, '22_luong_ket_qua');
      await cuonDen(t, find.text('Nhắc ngày nâng bậc vào Lịch'), viTri: 0.25);
      await chup(t, '23_luong_nang_bac');
      await cuonDen(t, find.textContaining('Căn cứ (cập nhật'), viTri: 0.1);
      await chup(t, '24_luong_can_cu');
      await quayVe(t);
    });

    // ---------- 3. Họp, biên bản
    await buoc('hop', () async {
      await moMa(t, 'hop');
      await chup(t, '30_hop_danh_sach');
      await t.tap(find.text('Kế hoạch ôn tập cuối học kỳ I'));
      await cho(t, 2000);
      await chup(t, '31_hop_sua_tren');
      await cuonDen(t, find.text('Diễn biến, ý kiến'), viTri: 0.05);
      await chup(t, '32_hop_ghi_chep');
      await t.tap(find.text('Nhờ AI sắp xếp thành biên bản'));
      await cho(t, 1500);
      await chup(t, '33_hop_hoi_dong_y');
      final dy = find.text('Đồng ý gửi');
      if (dy.evaluate().isNotEmpty) await t.tap(dy);
      final xong = await choChu(t, 'AI đã sắp xếp xong', giay: 90);
      kq('hop_ai: ${xong ? "xong" : "CHUA XONG"}');
      await chup(t, '34_hop_ai_xong', giuThongBao: true);
      await cuonDen(t, find.text('Diễn biến, ý kiến'), viTri: 0.05);
      await chup(t, '35_hop_ai_ghi_chep');
      await cuonDen(t, find.text('Kết luận của chủ trì'), viTri: 0.2);
      await chup(t, '36_hop_ket_luan');
      await quayVe(t, 2);
    });

    // ---------- 4. Giơ thẻ
    await buoc('gio_the', () async {
      await moMa(t, 'gio_the');
      await chup(t, '40_gio_the_tren');
      await t.tap(find.text('Ảnh có sẵn'));
      final doc = await choChu(t, 'Đọc được', giay: 120);
      kq('gio_the_quet: ${doc ? find.textContaining('Đọc được').evaluate().map((e) => (e.widget as Text).data).join() : "KHONG DOC DUOC"}');
      await chup(t, '41_gio_the_doc_xong', giuThongBao: true);
      await t.tap(find.widgetWithText(ChoiceChip, 'B'));
      await cho(t, 1000);
      await cuonDen(t, find.textContaining('Đã nhận'), viTri: 0.05);
      await chup(t, '42_gio_the_ket_qua');
      await cuonDen(t, find.textContaining('Chưa nhận'), viTri: 0.05);
      await chup(t, '43_gio_the_tung_em');
      await quayVe(t);
    });

    // ---------- 5. Nhắn phụ huynh
    await buoc('nhan_ph', () async {
      await moMa(t, 'nhan_ph');
      await chup(t, '50_nhan_ph_tren');
      final o = find.widgetWithText(TextField, 'Tên học sinh (gõ vài chữ để chọn, không gửi cho AI)');
      await cuonDen(t, o, viTri: 0.4);
      await t.enterText(o.first, 'Lê Hoàng');
      await cho(t, 1200);
      await chup(t, '51_nhan_ph_chon_ten');
      final goiY = find.text('Lê Hoàng An');
      if (goiY.evaluate().isNotEmpty) await t.tap(goiY.last);
      FocusManager.instance.primaryFocus?.unfocus();
      await cho(t, 1000);
      await cuonDen(t, find.text('Chọn loại tin'), viTri: 0.0);
      await chup(t, '52_nhan_ph_mau');
      await t.tap(find.text('Khen ngợi'));
      await cho(t, 800);
      await t.enterText(find.widgetWithText(TextField, 'Ý thầy cô muốn nói (để AI soạn)'), 'tuần này em tiến bộ môn Toán, hăng hái phát biểu');
      FocusManager.instance.primaryFocus?.unfocus();
      await t.tap(find.text('Nhờ AI soạn tin'));
      final xong = await choChu(t, 'AI đã soạn xong', giay: 90);
      kq('nhan_ph_ai: ${xong ? "xong" : "CHUA XONG"}');
      await chup(t, '53_nhan_ph_ai', giuThongBao: true);
      await cuonDen(t, find.text('Tin nhắn (sửa trực tiếp được)'), viTri: 0.05);
      await chup(t, '54_nhan_ph_tin');
      await cuonDen(t, find.text('Gửi qua Zalo…'), viTri: 0.5);
      await chup(t, '55_nhan_ph_gui');
      await quayVe(t);
    });

    // ---------- biểu tượng các tiện ích (nền trắng) để cắt đưa vào clip
    await buoc('bieu_tuong', () async {
      Navigator.of(t.element(find.byType(TrangChu, skipOffstage: false))).push(MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Wrap(spacing: 40, runSpacing: 40, children: [
                for (final ma in ['doc_to', 'luong', 'hop', 'gio_the', 'nhan_ph', 'tao_de'])
                  BieuTuongNoi(ma: ma, icon: timTheoMa(ma).bieuTuong, size: 96),
              ]),
            ),
          ),
        ),
      ));
      await cho(t, 2000);
      await chup(t, '70_bieu_tuong');
      await quayVe(t);
    });

    // ---------- 6. Hỏi Trợ lý (kho văn bản)
    await buoc('hoi', () async {
      await t.tap(find.text('Hỏi Trợ lý').last);
      await cho(t, 1500);
      await t.enterText(find.byType(TextField).first, 'Trường phổ thông dân tộc nội trú được tuyển tối đa bao nhiêu phần trăm học sinh dân tộc Kinh?');
      await t.tap(find.byIcon(Icons.arrow_upward));
      var co = false;
      for (var i = 0; i < 120 && !co; i++) {
        await cho(t, 500);
        co = find.textContaining('10%').evaluate().isNotEmpty || find.textContaining('04/2023').evaluate().isNotEmpty;
      }
      kq('hoi: ${co ? "co tra loi" : "CHUA THAY"}');
      await cho(t, 3000);
      await chup(t, '60_hoi_tro_ly');
      await t.drag(find.byType(Scrollable).first, const Offset(0, -500));
      await cho(t, 1000);
      await chup(t, '61_hoi_tro_ly_duoi');
    });
  }, timeout: const Timeout(Duration(minutes: 30)));
}
