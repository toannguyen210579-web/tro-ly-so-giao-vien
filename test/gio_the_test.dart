import 'package:flutter_test/flutter_test.dart';
import 'package:tro_ly_so_giao_vien/data/gio_the.dart';
import 'package:tro_ly_so_giao_vien/services/tep_word.dart';
import 'package:archive/archive.dart';
import 'dart:convert';

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
}
