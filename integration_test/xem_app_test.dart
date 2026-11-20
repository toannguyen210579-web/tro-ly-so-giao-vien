// Đi qua các tiện ích với dữ liệu mẫu, chụp màn hình để người dùng xem app mà không cần điện thoại Android.
// Bổ sung cho chup_clip_test.dart (đã có Đọc to, Tính lương, Họp, Giơ thẻ, Nhắn phụ huynh, Hỏi Trợ lý).
// Dữ liệu mẫu (lớp 7A, giấy khen, đề Toán 8) là dữ liệu tự đặt. Ảnh lưu vào anh_chay_thu/xem_*.png.

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tro_ly_so_giao_vien/data/cham_diem.dart';
import 'package:tro_ly_so_giao_vien/data/luu_tru.dart';
import 'package:tro_ly_so_giao_vien/data/minh_chung.dart';
import 'package:tro_ly_so_giao_vien/data/tien_ich.dart';
import 'package:tro_ly_so_giao_vien/main.dart' as app;
import 'package:tro_ly_so_giao_vien/screens/dieu_huong.dart';
import 'package:tro_ly_so_giao_vien/screens/nhan_xet.dart';
import 'package:tro_ly_so_giao_vien/screens/trang_chu.dart';
import 'package:tro_ly_so_giao_vien/services/tep_pdf.dart';

import 'anh_mau_xem.dart';

/// Trả về ảnh mẫu thay cho máy ảnh, thư viện ảnh. Đổi [duong] trước mỗi lần chọn ảnh.
class _AnhMau extends ImagePickerPlatform {
  String duong = '';

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

  @override
  Future<List<XFile>> getMultiImageWithOptions({MultiImagePickerOptions options = const MultiImagePickerOptions()}) async =>
      [XFile(duong)];

  @override
  Future<List<XFile>?> getMultiImage({double? maxWidth, double? maxHeight, int? imageQuality}) async => [XFile(duong)];
}

const _tenLop7A = [
  'Lê Hoàng An', 'Trần Ngọc Anh', 'Nguyễn Gia Bảo', 'Phạm Minh Châu', 'Võ Thành Đạt', 'Đỗ Hải Đăng', 'Bùi Thu Hà',
  'Hoàng Gia Hân', 'Ngô Đức Huy', 'Đặng Minh Khang', 'Lý Bảo Khánh', 'Trịnh Ngọc Lan', 'Phan Gia Linh', 'Vũ Đức Long',
];

void main() {
  final b = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final anhMau = _AnhMau();
  WidgetTester? t0;

  Future<void> cho(WidgetTester t, [int ms = 1500]) async {
    for (var i = 0; i < ms ~/ 100; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

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
      await b.takeScreenshot('xem_$ten');
      kq('chup $ten: on');
    } catch (e) {
      kq('chup $ten: LOI $e');
    }
  }

  Future<bool> choChu(WidgetTester t, String chu, {int giay = 60}) async {
    for (var i = 0; i < giay * 2; i++) {
      if (find.textContaining(chu).evaluate().isNotEmpty) return true;
      await cho(t, 500);
    }
    return false;
  }

  /// Cuộn danh sách chính của màn đang mở cho [f] nằm gần đầu màn hình.
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

  /// Cuộn xuống cuối danh sách chính.
  Future<void> cuonCuoi(WidgetTester t) async {
    try {
      final sc = find.descendant(of: find.byType(ListView).last, matching: find.byType(Scrollable)).first;
      final vt = t.state<ScrollableState>(sc).position;
      vt.jumpTo(vt.maxScrollExtent);
    } catch (_) {}
    await cho(t, 800);
  }

  Future<void> bam(WidgetTester t, Finder f, {int ms = 1500}) async {
    await t.ensureVisible(f.first);
    await cho(t, 300);
    await t.tap(f.first);
    await cho(t, ms);
  }

  /// Bấm "Chọn ảnh" (ảnh mẫu), chờ ảnh hiện; chưa có thì thử lại, ghi thông báo của app nếu có.
  Future<bool> chonAnh(WidgetTester t, String duong, Finder daCo) async {
    anhMau.duong = duong;
    kq('anh_mau: ${File(duong).existsSync() ? "co tep ${File(duong).lengthSync()} byte" : "KHONG CO TEP"}');
    final truoc = daCo.evaluate().length;
    for (var lan = 1; lan <= 3; lan++) {
      await bam(t, find.text('Chọn ảnh'), ms: 500);
      for (var i = 0; i < 16; i++) {
        await cho(t, 500);
        if (daCo.evaluate().length > truoc) {
          kq('chon_anh: co anh sau lan $lan');
          return true;
        }
      }
      final tb = find.descendant(of: find.byType(SnackBar), matching: find.byType(Text)).evaluate().map((e) => (e.widget as Text).data).join(' | ');
      kq('chon_anh: lan $lan chua thay anh; thong bao: ${tb.isEmpty ? "khong" : tb}');
      tatThongBao(t);
    }
    return false;
  }

  Future<void> moMa(WidgetTester t, String ma) async {
    moTienIch(t.element(find.byType(TrangChu, skipOffstage: false)), timTheoMa(ma));
    await cho(t, 2500);
  }

  Future<void> buoc(String ten, Future<void> Function() viec) async {
    try {
      Navigator.of(t0!.element(find.byType(TrangChu, skipOffstage: false))).popUntil((r) => r.isFirst);
      await cho(t0!, 800);
    } catch (_) {}
    try {
      await viec();
      kq('$ten: xong');
    } catch (e) {
      kq('$ten: LOI ${e.toString().split('\n').first}');
      await chup(t0!, '${ten}_loi', giuThongBao: true);
    }
  }

  testWidgets('Xem app', (t) async {
    t0 = t;
    FlutterError.onError = (d) => kq('loi_giao_dien: ${d.exceptionAsString().split('\n').first}');

    // ---------- dữ liệu mẫu
    final tam = await getTemporaryDirectory();
    Future<String> ghiAnh(String ten, List<String> b64) async {
      final f = File('${tam.path}/$ten');
      await f.writeAsBytes(base64Decode(b64.join()));
      return f.path;
    }

    final giayKhen = await ghiAnh('giay_khen.jpg', anhGiayKhenBase64);
    final giayCN = await ghiAnh('giay_chung_nhan.jpg', anhGiayChungNhanBase64);
    final deToan = await ghiAnh('de_toan8.jpg', anhDeToan8Base64);
    ImagePickerPlatform.instance = anhMau;

    final p = await SharedPreferences.getInstance();
    const muc = ['Tốt', 'Khá', 'Tốt', 'Đạt', 'Khá'];
    await ghiLop([
      Lop('7A', 'tr', 'Toán', [
        for (var i = 0; i < _tenLop7A.length; i++) HocSinh(_tenLop7A[i], muc: muc[i % muc.length], diemTx: '${7 + i % 3} ${8 - i % 2}'),
      ]),
    ]);
    await p.setString('lop_dang_day', '7A');
    // Chấm trắc nghiệm: đề Toán 8 (10 câu, mã 101) và 4 bài đã chấm
    await LuuTru.ghiDanhSach(khoaChamTracNghiem, [
      DeThi(id: '1', ten: 'Kiểm tra 15 phút Toán 8', soCau: 10, dapAn: {'101': 'BACDACDBAD'}, baiLam: [
        BaiLam(ten: 'Trần Ngọc Anh', maDe: '101', traLoi: 'BACDACDBAD'),
        BaiLam(ten: 'Nguyễn Gia Bảo', maDe: '101', traLoi: 'BACDACDBCD'),
        BaiLam(ten: 'Phạm Minh Châu', maDe: '101', traLoi: 'BACBACABAD'),
        BaiLam(ten: 'Võ Thành Đạt', maDe: '101', traLoi: 'BCCDADDBAA'),
      ]).toJson(),
    ]);
    // Sổ minh chứng: một giấy khen có sẵn
    final mcDir = await thuMucApp('minh_chung');
    await File(giayKhen).copy('${mcDir.path}/mau_giay_khen.jpg');
    await LuuTru.ghiDanhSach('so_minh_chung', [
      MinhChung(
        id: '1',
        nhom: 'Thi đua, khen thưởng',
        tieuDe: 'Giấy khen giáo viên dạy giỏi cấp huyện 2025-2026',
        ngay: DateTime(2026, 5, 15),
        ma: 'TĐ-01',
        ghiChu: 'Số 125/QĐ-PGDĐT, Phòng GD&ĐT Hòa Bình',
        anh: ['mau_giay_khen.jpg'],
      ).toJson(),
    ]);

    app.main();
    await cho(t, 3500);
    await b.convertFlutterSurfaceToImage();
    await chup(t, '00_trang_chu');

    // ---------- Giải đề, soạn đáp án
    await buoc('giai_de', () async {
      await moMa(t, 'tao_de');
      await chup(t, '10_giai_de');
      if (!await chonAnh(t, deToan, find.byType(Image))) {
        // Không gắn được ảnh thì dán chữ đề để vẫn thử phần AI giải
        await t.enterText(find.widgetWithText(TextField, 'Hoặc gõ, dán đề vào đây'),
            'Câu 1. Kết quả khai triển (x + 3)² là: A. x² + 9  B. x² + 6x + 9  C. x² + 3x + 9  D. x² − 6x + 9\n'
            'Câu 2. Phân tích x² − 16 thành nhân tử: A. (x − 4)²  B. (x + 4)²  C. (x − 4)(x + 4)  D. (x − 8)(x + 8)');
        FocusManager.instance.primaryFocus?.unfocus();
      }
      await chup(t, '11_giai_de_co_anh');
      await bam(t, find.text('Giải, soạn đáp án'), ms: 1500);
      final dy = find.text('Đồng ý gửi');
      if (dy.evaluate().isNotEmpty) await bam(t, dy);
      // Ô kết quả chỉ hiện khi AI trả lời xong
      var xong = false;
      for (var i = 0; i < 300 && !xong; i++) {
        await cho(t, 500);
        xong = find.widgetWithText(TextField, 'Kết quả (sửa được)').evaluate().isNotEmpty;
      }
      kq('giai_de_ai: ${xong ? "co ket qua" : "CHUA CO"}');
      await cho(t, 1500);
      await cuonDen(t, find.text('Kết quả (sửa được)'), viTri: 0.02);
      await chup(t, '12_giai_de_ket_qua', giuThongBao: true);
      await cuonCuoi(t);
      await chup(t, '13_giai_de_nut');
    });

    // ---------- Chấm trắc nghiệm
    await buoc('cham_tn', () async {
      await moMa(t, 'cham_tn');
      await chup(t, '20_cham_tn');
      await bam(t, find.text('Kiểm tra 15 phút Toán 8'));
      await chup(t, '21_cham_tn_bai');
      await bam(t, find.text('Chấm bài').first);
      await chup(t, '21b_cham_tn_tab');
      await bam(t, find.text('Chấm bài mới'));
      await t.enterText(find.widgetWithText(TextField, 'Họ và tên học sinh'), 'Lê Hoàng An');
      await t.enterText(find.widgetWithText(TextField, 'Gõ nhanh cả dãy (không bắt buộc)'), 'BACDACDBAA');
      FocusManager.instance.primaryFocus?.unfocus();
      await cho(t, 1000);
      kq('cham_tn_diem: ${find.textContaining('điểm').evaluate().map((e) => (e.widget as Text).data).join(' | ')}');
      await chup(t, '22_cham_tn_nhap');
      await bam(t, find.text('Lưu, chấm em tiếp'), ms: 2000);
      Navigator.of(t.element(find.byType(Scaffold).last)).maybePop();
      await cho(t, 1500);
      await chup(t, '23_cham_tn_ket_qua');
      await bam(t, find.text('Thống kê').first);
      await chup(t, '24_cham_tn_thong_ke');
    });

    // ---------- Sổ minh chứng
    await buoc('minh_chung', () async {
      await moMa(t, 'minh_chung');
      await chup(t, '30_minh_chung');
      await bam(t, find.text('Thêm minh chứng'));
      final td = find.widgetWithText(TextField, 'Tiêu đề');
      await t.enterText(td, 'Giấy chứng nhận bồi dưỡng thường xuyên 2025-2026');
      await t.enterText(find.widgetWithText(TextField, 'Mã minh chứng (nếu hồ sơ yêu cầu)'), 'BD-01');
      FocusManager.instance.primaryFocus?.unfocus();
      await chonAnh(t, giayCN, find.byType(Image));
      await chup(t, '31_minh_chung_them');
      await bam(t, find.widgetWithText(FilledButton, 'Lưu'), ms: 2000);
      await chup(t, '32_minh_chung_ds');
      await bam(t, find.textContaining('Xuất để nộp hồ sơ'), ms: 1500);
      await chup(t, '33_minh_chung_xuat');
    });

    // ---------- Nhận xét học sinh
    await buoc('nhan_xet', () async {
      await moMa(t, 'nhan_xet');
      await chup(t, '40_nhan_xet');
      await bam(t, find.textContaining('7A').first);
      await chup(t, '41_nhan_xet_lop');
      await bam(t, find.text('Nhờ AI viết nhận xét'), ms: 1500);
      final dy = find.text('Đồng ý gửi');
      if (dy.evaluate().isNotEmpty) await bam(t, dy);
      var co = false;
      for (var i = 0; i < 180 && !co; i++) {
        await cho(t, 500);
        co = find.textContaining('Em ').evaluate().length >= 2;
      }
      kq('nhan_xet_ai: ${co ? "xong" : "CHUA XONG"}');
      await cho(t, 2000);
      await chup(t, '42_nhan_xet_ai', giuThongBao: true);
    });

    // ---------- Ảnh sang Word
    await buoc('sang_word', () async {
      await moMa(t, 'sang_word');
      await chup(t, '50_sang_word');
      await chonAnh(t, deToan, find.textContaining('Câu'));
      final doc = await choChu(t, 'Câu', giay: 60);
      kq('sang_word_doc: ${doc ? "doc duoc" : "CHUA DOC"}');
      await chup(t, '51_sang_word_chu', giuThongBao: true);
    });

    // ---------- Lịch, nhắc hạn
    await buoc('lich', () async {
      await moMa(t, 'lich');
      await chup(t, '60_lich');
      await bam(t, find.text('Thêm việc'));
      await t.enterText(find.widgetWithText(TextField, 'Việc cần làm'), 'Nộp kế hoạch ôn tập cuối học kỳ I');
      FocusManager.instance.primaryFocus?.unfocus();
      await cho(t, 800);
      await chup(t, '61_lich_them');
      await bam(t, find.text('Lưu'), ms: 1500);
      await chup(t, '62_lich_ds');
    });

    // ---------- Ô chữ, Công cụ trên lớp, Quét PDF, Ảnh thẻ: mở và chụp
    await buoc('o_chu', () async {
      await moMa(t, 'o_chu');
      await chup(t, '70_o_chu');
      await bam(t, find.text('Ô chữ mới'));
      await chup(t, '71_o_chu_moi');
    });
    await buoc('cong_cu', () async {
      await moMa(t, 'cong_cu');
      await chup(t, '80_cong_cu');
      await cuonCuoi(t);
      await chup(t, '81_cong_cu_duoi');
    });
    await buoc('quet', () async {
      await moMa(t, 'quet');
      await chup(t, '90_quet_pdf');
    });
    await buoc('anh_the', () async {
      await moMa(t, 'anh_the');
      await chup(t, '91_anh_the');
    });
  }, timeout: const Timeout(Duration(minutes: 30)));
}
