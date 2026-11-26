import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tro_ly_so_giao_vien/data/trinh_chieu.dart';
import 'package:tro_ly_so_giao_vien/screens/tao_trinh_chieu.dart';
import 'package:tro_ly_so_giao_vien/services/tep_pptx.dart';
import 'package:tro_ly_so_giao_vien/services/tep_trinh_chieu_pdf.dart';

/// Câu trả lời mẫu của AI (giống bài thử bằng python-pptx, LibreOffice ngày 26/11/2026).
const _mau = '''Đây là bài trình chiếu:
```json
{"tieu_de": "Bài 5. Phân số", "mon": "Toán", "lop": "6",
 "trang": [
  {"loai": "bia", "tieu_de": "Bài 5. Phân số", "y": ["Môn Toán", "Lớp 6"], "ghi_chu": "Giới thiệu bài học."},
  {"loai": "muc_tieu", "hoat_dong": "Mục tiêu bài học", "tieu_de": "Học xong bài này, em sẽ", "y": ["Nhận biết phân số với tử và mẫu là số nguyên", "So sánh hai phân số bằng nhau", "Vận dụng phân số vào bài toán thực tế"], "ghi_chu": "Đọc nhanh mục tiêu cho học sinh."},
  {"loai": "hoat_dong", "hoat_dong": "Hoạt động 1 · Mở đầu", "tieu_de": "Chia bánh cho các bạn", "y": ["Có 3 cái bánh chia đều cho 4 bạn", "Mỗi bạn được bao nhiêu phần cái bánh?"], "ghi_chu": "Cho học sinh thảo luận cặp đôi 2 phút.\\nĐáp án: 3/4 cái bánh."},
  {"loai": "hoat_dong", "hoat_dong": "Hoạt động 2 · Hình thành kiến thức mới", "tieu_de": "Khái niệm phân số <a & b>", "y": ["Phân số có dạng a/b, với a, b là số nguyên, b khác 0", "a là tử số, b là mẫu số", "Ví dụ: −3/4; 5/−7; 0/9", "Mọi số nguyên n đều viết được dưới dạng n/1"], "ghi_chu": "Nhấn mạnh điều kiện b khác 0."},
  {"loai": "cau_hoi", "hoat_dong": "Hoạt động 3 · Luyện tập", "tieu_de": "Câu hỏi luyện tập", "y": ["Câu 1. Viết các phân số: âm ba phần năm; bảy phần âm hai", "Câu 2. Trong các cách viết sau, cách viết nào là phân số: 4/0; −2/5; 1,5/3", "Câu 3. Biểu diễn số nguyên −6 dưới dạng phân số"], "ghi_chu": "Đáp án: C1: −3/5; 7/−2. C2: −2/5. C3: −6/1."},
  {"loai": "tong_ket", "hoat_dong": "Hoạt động 4 · Vận dụng", "tieu_de": "Về nhà", "y": ["Tìm 3 tình huống trong đời sống dùng phân số", "Làm bài tập 1, 2, 3 trang 9 SGK"], "ghi_chu": ""}
 ]}
```''';

void main() {
  test('Đọc câu trả lời của AI (có chữ, ```json bọc ngoài), câu bị cắt giữa chừng, câu sai dạng', () {
    final bai = BaiChieu.tuTraLoi(_mau)!;
    expect(bai.tieuDe, 'Bài 5. Phân số');
    expect(bai.trang.length, 6);
    expect(bai.trang.first.laBia, true);
    expect(bai.trang[4].loai, 'cau_hoi');
    expect(bai.trang[2].ghiChu, 'Cho học sinh thảo luận cặp đôi 2 phút.\nĐáp án: 3/4 cái bánh.');
    // AI viết dài quá bị cắt: giữ các trang đã đủ
    final cat = _mau.substring(0, _mau.indexOf('"Câu hỏi luyện tập"'));
    final bai2 = BaiChieu.tuTraLoi(cat)!;
    expect(bai2.trang.length, 4);
    expect(bai2.trang.last.tieuDe, 'Khái niệm phân số <a & b>');
    expect(BaiChieu.tuTraLoi('Xin lỗi, tôi chưa đọc được giáo án.'), isNull);
    expect(BaiChieu.tuTraLoi('{"trang": []}'), isNull);
    // trang thiếu loại thì coi là hoạt động, trang trống bị bỏ
    final b3 = BaiChieu.tuTraLoi('{"trang":[{"tieu_de":"A","y":["x", ""]},{"y":[]}]}')!;
    expect(b3.trang.length, 1);
    expect(b3.trang.first.loai, 'hoat_dong');
    expect(b3.trang.first.y, ['x']);
    expect(b3.tieuDe, 'A');
  });

  test('Yêu cầu gửi máy chủ và cỡ chữ theo độ dài', () {
    expect(yeuCauTrinhChieu(capHoc: 'THCS', soTrang: 12), 'Cấp học: THCS. Số trang chiếu: khoảng 12.');
    expect(yeuCauTrinhChieu(capHoc: 'Tiểu học', soTrang: 8, noiDung: ' Giáo án '), 'Cấp học: Tiểu học. Số trang chiếu: khoảng 8.\n---\nGiáo án');
    expect(coChuNoiDung(['Ngắn']), 3200);
    expect(coChuNoiDung(List.filled(6, 'x' * 85)), 1800);
    expect(coChuNoiDung(List.filled(3, 'x' * 60)), 2800);
  });

  test('Tệp PowerPoint: đủ phần, chữ tiếng Việt, ký tự đặc biệt, ghi chú giáo viên; ghi ra build để CI mở thử', () {
    final bai = BaiChieu.tuTraLoi(_mau)!;
    final b = taoPptx(bai, mauTrinhChieu.first);
    final z = ZipDecoder().decodeBytes(b);
    expect(z.files.first.name, '[Content_Types].xml');
    String doc(String ten) => utf8.decode(z.findFile(ten)!.content as List<int>);
    for (var i = 1; i <= 6; i++) {
      expect(z.findFile('ppt/slides/slide$i.xml'), isNotNull);
      expect(z.findFile('ppt/notesSlides/notesSlide$i.xml'), isNotNull);
    }
    expect(doc('ppt/presentation.xml'), contains('<p:sldSz cx="12192000" cy="6858000"/>'));
    expect(doc('ppt/slides/slide4.xml'), contains('Khái niệm phân số &lt;a &amp; b&gt;'));
    expect(doc('ppt/slides/slide4.xml'), contains('HOẠT ĐỘNG 2 · HÌNH THÀNH KIẾN THỨC MỚI'));
    expect(doc('ppt/slides/slide1.xml'), contains('Môn Toán · Lớp 6'));
    expect(doc('ppt/notesSlides/notesSlide5.xml'), contains('Đáp án: C1: −3/5; 7/−2.'));
    // đáp án không hiện trên trang chiếu
    expect(doc('ppt/slides/slide5.xml'), isNot(contains('Đáp án')));
    expect(doc('[Content_Types].xml'), contains('/ppt/notesSlides/notesSlide6.xml'));
    Directory('build').createSync(recursive: true);
    File('build/thu_trinh_chieu.pptx').writeAsBytesSync(b);
    File('build/thu_trinh_chieu_mau_tim.pptx').writeAsBytesSync(taoPptx(bai, mauTrinhChieu.last));
  });

  test('Tệp PDF bài trình chiếu: mỗi trang chiếu một trang 16:9, phông Be Vietnam Pro', () async {
    final f = pw.Font.ttf(File('assets/fonts/BeVietnamPro-Regular.ttf').readAsBytesSync().buffer.asByteData());
    final fb = pw.Font.ttf(File('assets/fonts/BeVietnamPro-Bold.ttf').readAsBytesSync().buffer.asByteData());
    final bai = BaiChieu.tuTraLoi(_mau)!;
    // trang rất nhiều chữ vẫn vừa trang (chữ tự thu nhỏ, không sang trang mới)
    bai.trang.add(TrangChieu(loai: 'hoat_dong', hoatDong: 'Thử', tieuDe: 'Tiêu đề rất dài ' * 8, y: List.filled(9, 'Ý dài ' * 30)));
    final pdf = await taoPdfTrinhChieu(bai, mauTrinhChieu[1], theme: pw.ThemeData.withFont(base: f, bold: fb));
    expect(String.fromCharCodes(pdf.take(5)), '%PDF-');
    Directory('build').createSync(recursive: true);
    File('build/thu_trinh_chieu.pdf').writeAsBytesSync(pdf);
    // ignore: avoid_print
    print('KQ trinh_chieu_pdf: ${bai.trang.length} trang, ${pdf.length} byte');
  });

  testWidgets('Màn Tạo bài trình chiếu: chưa có giáo án thì nhắc; có bài thì xem từng trang, sửa trang', (t) async {
    SharedPreferences.setMockInitialValues({});
    // màn cao để cả khung nhập giáo án và nút Tạo cùng dựng (danh sách dựng dần khi cuộn)
    t.view.physicalSize = const Size(1080, 5200);
    t.view.devicePixelRatio = 2.6;
    addTearDown(t.view.reset);
    await t.pumpWidget(const MaterialApp(home: TaoTrinhChieu()));
    await t.pumpAndSettle();
    expect(find.text('Tệp giáo án (Word, PDF)'), findsOneWidget);
    expect(find.text('THCS'), findsOneWidget);
    await t.ensureVisible(find.byKey(const Key('tc_tao')));
    await t.tap(find.byKey(const Key('tc_tao')));
    await t.pump();
    expect(find.text('Thầy cô chọn tệp giáo án, chụp giáo án hoặc dán nội dung giáo án.'), findsOneWidget);
    // giáo án ngắn: hỏi trước khi gọi AI
    await t.enterText(find.byKey(const Key('tc_o_chu')), 'Bài 5. Phân số');
    await t.tap(find.byKey(const Key('tc_tao')));
    await t.pumpAndSettle();
    expect(find.text('Giáo án ngắn quá'), findsOneWidget);
    await t.tap(find.text('Thêm giáo án'));
    await t.pumpAndSettle();

    await t.pumpWidget(MaterialApp(home: TaoTrinhChieu(key: UniqueKey(), baiThu: BaiChieu.tuTraLoi(_mau))));
    await t.pumpAndSettle();
    expect(find.text('Bài 5. Phân số (6 trang)'), findsOneWidget);
    expect(find.text('Tạo lại'), findsOneWidget);
    await t.scrollUntilVisible(find.byKey(const ValueKey('tc_trang_2')), 300, scrollable: find.byType(Scrollable).first);
    await t.pumpAndSettle();
    expect(find.text('Chia bánh cho các bạn'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('tc_trang_2')));
    await t.pumpAndSettle();
    expect(find.text('Sửa trang 3'), findsOneWidget);
    await t.enterText(find.byKey(const Key('tc_sua_tieu_de')), 'Chia bánh');
    await t.enterText(find.byKey(const Key('tc_sua_y')), 'Ý một\n\nÝ hai');
    await t.tap(find.byKey(const Key('tc_luu_sua')));
    await t.pumpAndSettle();
    expect(find.text('Chia bánh'), findsOneWidget);
    expect(find.text('Ý hai'), findsOneWidget);
    await t.scrollUntilVisible(find.byKey(const Key('tc_luu')), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Lưu bài trình chiếu (PowerPoint, PDF)'), findsOneWidget);
  });

  // Máy giả lập 320 x 640 điểm (máy màn nhỏ nhất app hỗ trợ): không có chỗ nào tràn chữ, tràn nút
  testWidgets('Màn Tạo bài trình chiếu trên máy màn nhỏ 320 điểm không tràn', (t) async {
    SharedPreferences.setMockInitialValues({});
    t.view.physicalSize = const Size(960, 1920);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(home: TaoTrinhChieu(baiThu: BaiChieu.tuTraLoi(_mau))));
    await t.pumpAndSettle();
    final sc = find.byType(Scrollable).first;
    for (var i = 0; i < 40 && find.byKey(const Key('tc_luu')).evaluate().isEmpty; i++) {
      await t.drag(sc, const Offset(0, -300));
      await t.pumpAndSettle();
    }
    expect(find.byKey(const Key('tc_luu')), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
