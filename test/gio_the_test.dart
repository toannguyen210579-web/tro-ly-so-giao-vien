import 'package:flutter_test/flutter_test.dart';
import 'package:tro_ly_so_giao_vien/data/gio_the.dart';
import 'package:tro_ly_so_giao_vien/services/tep_word.dart';
import 'package:archive/archive.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/widgets.dart' as pw;
import 'package:tro_ly_so_giao_vien/services/the_gio_pdf.dart';

void main() {
  test('mã thẻ', () {
    expect(soTuMa(maThe(12)), 12);
    expect(soTuMa('abc'), isNull);
    expect(soTuMa(null), isNull);
  });

  test('chiều xoay ra đáp án', () {
    // cạnh trên mã QR hướng sang phải: thẻ thẳng, chữ A ở trên
    expect(dapAnTuGoc(gocCanhTren(0, 0, 10, 0)), 'A');
    // hướng lên trên (y giảm): cạnh B lên trên
    expect(dapAnTuGoc(gocCanhTren(0, 10, 0, 0)), 'B');
    // hướng sang trái: lộn ngược, chữ C ở trên
    expect(dapAnTuGoc(gocCanhTren(10, 0, 0, 0)), 'C');
    // hướng xuống dưới: cạnh D lên trên
    expect(dapAnTuGoc(gocCanhTren(0, 0, 0, 10)), 'D');
    // nghiêng nhẹ vẫn đúng
    expect(dapAnTuGoc(30), 'A');
    expect(dapAnTuGoc(-170), 'C');
    // ảnh bị xoay sẵn 90 độ
    expect(dapAnTuGoc(90, hieuChinh: 90), 'A');
  });

  test('đọc chiều thẻ từ ảnh mã QR (góc thiếu ô định vị)', () {
    // Mã QR 21x21 giả lập: ô định vị ở 3 góc, phần còn lại ngẫu nhiên; vẽ 10 điểm ảnh mỗi ô, viền trắng 30 điểm.
    const n = 21, o = 10, le = 30, c = n * o + 2 * le;
    final r = Random(3);
    final den = List.generate(n, (_) => List.generate(n, (_) => r.nextBool()));
    void dinhVi(int i0, int j0) {
      for (var b = 0; b < 7; b++) {
        for (var a = 0; a < 7; a++) {
          den[j0 + b][i0 + a] = a == 0 || a == 6 || b == 0 || b == 6 || (a >= 2 && a <= 4 && b >= 2 && b <= 4);
        }
      }
    }
    dinhVi(0, 0);
    dinhVi(n - 7, 0);
    dinhVi(0, n - 7);
    // xoay ma trận theo chiều kim đồng hồ k lần (90 độ mỗi lần)
    List<List<bool>> xoay(List<List<bool>> m, int k) {
      var x = m;
      for (var t = 0; t < k; t++) {
        x = List.generate(n, (j) => List.generate(n, (i) => x[n - 1 - i][j]));
      }
      return x;
    }
    AnhXam ve(List<List<bool>> m) {
      final s = Uint8List(c * c)..fillRange(0, c * c, 235);
      for (var y = 0; y < c; y++) {
        for (var x = 0; x < c; x++) {
          final i = (x - le) ~/ o, j = (y - le) ~/ o;
          if (x >= le && y >= le && i < n && j < n && m[j][i]) s[y * c + x] = 20;
        }
      }
      return AnhXam(s, c, c);
    }
    // 4 góc mã theo khung ảnh (như ML Kit trả về), cố tình đưa lộn thứ tự
    final g = <(double, double)>[(le + n * o + 0.0, le + 0.0), (le + 0.0, le + n * o + 0.0), (le + 0.0, le + 0.0), (le + n * o + 0.0, le + n * o + 0.0)];
    // thẻ thẳng: A; xoay trái 90 (= xoay phải 3 lần): B; lộn ngược: C; xoay phải 90: D
    expect(dapAnTuGoc(gocTuAnh(ve(den), g)!), 'A');
    expect(dapAnTuGoc(gocTuAnh(ve(xoay(den, 3)), g)!), 'B');
    expect(dapAnTuGoc(gocTuAnh(ve(xoay(den, 2)), g)!), 'C');
    expect(dapAnTuGoc(gocTuAnh(ve(xoay(den, 1)), g)!), 'D');
    // ảnh trắng trơn: không đoán bừa
    expect(gocTuAnh(AnhXam(Uint8List(c * c)..fillRange(0, c * c, 235), c, c), g), isNull);
  });

  test('chia ảnh thành mảnh chồng nhau phủ kín ảnh', () {
    final ds = chiaManh(3000, 2000, 3, 3);
    expect(ds.length, 9);
    expect(ds.first.$1, 0);
    expect(ds.last.$1 + ds.last.$3, 3000);
    expect(ds.last.$2 + ds.last.$4, 2000);
    expect(ds[1].$1 < ds[0].$3, isTrue); // có phần chồng
  });

  test('thống kê và lưu', () {
    final c = CauGioThe(tieuDe: 'Câu 1', dapAnDung: 'B', luc: DateTime(2026, 11, 18), traLoi: {1: 'A', 2: 'B', 3: 'B'});
    expect(c.thongKe, {'A': 1, 'B': 2, 'C': 0, 'D': 0});
    final d = CauGioThe.fromJson(c.toJson());
    expect(d.traLoi, c.traLoi);
    expect(d.dapAnDung, 'B');
  });

  test('tệp Word', () {
    final doan = tachDoan('Dòng một\nnối tiếp\n\nĐoạn hai');
    expect(doan.length, 2);
    final z = ZipDecoder().decodeBytes(taoDocx(doan, tieuDe: 'Thử <&>'));
    final xml = utf8.decode(z.findFile('word/document.xml')!.content as List<int>);
    expect(xml.contains('Đoạn hai'), isTrue);
    expect(xml.contains('Thử &lt;&amp;&gt;'), isTrue);
  });

  // Lỗi 24/11/2026: bấm In bộ thẻ không thấy gì. Tạo thử bộ thẻ lớp 40 em có tên tiếng Việt, đo thời gian.
  test('tạo bộ thẻ PDF cả lớp', () async {
    final f = pw.Font.ttf(File('assets/fonts/DejaVuSerif.ttf').readAsBytesSync().buffer.asByteData());
    final fb = pw.Font.ttf(File('assets/fonts/DejaVuSerif-Bold.ttf').readAsBytesSync().buffer.asByteData());
    final ten = [for (var i = 1; i <= 40; i++) 'Nguyễn Thị Hồng Ánh $i'];
    final dh = Stopwatch()..start();
    final pdf = await taoPdfBoThe(40, ten, theme: pw.ThemeData.withFont(base: f, bold: fb));
    // ignore: avoid_print
    print('KQ bo_the: 40 thẻ, ${pdf.length} byte, ${dh.elapsedMilliseconds} ms');
    expect(String.fromCharCodes(pdf.take(5)), '%PDF-');
    expect(pdf.length, greaterThan(10000));
    Directory('build').createSync(recursive: true);
    File('build/thu_bo_the.pdf').writeAsBytesSync(pdf);
    // lớp lẻ: trang cuối một thẻ
    final le = await taoPdfBoThe(5, const [], theme: pw.ThemeData.withFont(base: f, bold: fb));
    expect(String.fromCharCodes(le.take(5)), '%PDF-');
  });

  test('tệp Word có bảng (bảng lương)', () {
    final b = taoDocxBang(
      tieuDe: 'BẢNG LƯƠNG THÁNG (THAM KHẢO)',
      phuDe: 'Lập ngày 24/11/2026',
      dongDau: ['Giáo viên THCS, Hạng III, bậc 4, hệ số 3,33.'],
      bang: [
        ['STT', 'Khoản', 'Số tiền (đồng)'],
        ['1', 'Lương theo hệ số', '8.424.900'],
        ['', 'Thực nhận <&>', '9.000.000'],
      ],
      doRong: const [90, 580, 330],
      canPhai: const {2},
      dongDam: const {2},
      dongCuoi: ['Nâng bậc kế tiếp dự kiến từ 01/09/2027.'],
    );
    final z = ZipDecoder().decodeBytes(b);
    final xml = utf8.decode(z.findFile('word/document.xml')!.content as List<int>);
    expect(xml.contains('<w:tbl>'), isTrue);
    expect('<w:tr>'.allMatches(xml).length, 3);
    expect(xml.contains('Thực nhận &lt;&amp;&gt;'), isTrue);
    Directory('build').createSync(recursive: true);
    File('build/thu_bang_luong.docx').writeAsBytesSync(b);
  });
}
