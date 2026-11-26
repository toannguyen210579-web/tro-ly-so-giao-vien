import 'package:flutter_test/flutter_test.dart';
import 'package:tro_ly_so_giao_vien/data/dich.dart';

void main() {
  test('Tách đoạn: theo dòng trống, không có dòng trống thì theo từng dòng', () {
    expect(tachDoanDich('Đoạn 1 dòng a\ndòng b\n\nĐoạn 2'), ['Đoạn 1 dòng a\ndòng b', 'Đoạn 2']);
    expect(tachDoanDich('Dòng 1\nDòng 2\n'), ['Dòng 1', 'Dòng 2']);
    expect(tachDoanDich('   '), isEmpty);
  });

  test('Chia khối mỗi trang không quá giới hạn, không mất chữ', () {
    final doan = [for (var i = 0; i < 30; i++) 'Đây là đoạn số $i. ' * 8];
    final khoi = chiaKhoiDich(doan, toiDa: 600);
    expect(khoi.length, greaterThan(1));
    for (final k in khoi) {
      expect(k.join('\n\n').length, lessThanOrEqualTo(600));
    }
    expect(khoi.expand((k) => k).join(), doan.join());
  });

  test('Đoạn rất dài được cắt theo câu', () {
    final dai = List.generate(50, (i) => 'Câu thứ $i rất dài để thử.').join(' ');
    final khoi = chiaKhoiDich([dai], toiDa: 200);
    expect(khoi.expand((k) => k).every((d) => d.length <= 200), isTrue);
  });

  test('Ghép song ngữ theo đoạn; số đoạn lệch thì ghép cả khối', () {
    expect(ghepSongNgu(['Xin chào', 'Tạm biệt'], 'Hello\n\nGoodbye'), [('Xin chào', 'Hello'), ('Tạm biệt', 'Goodbye')]);
    final lech = ghepSongNgu(['A', 'B', 'C'], 'X\n\nY');
    expect(lech.length, 1);
    expect(lech.first.$1, 'A\n\nB\n\nC');
  });

  test('Tách nguyên văn và bản dịch khi dịch ảnh song ngữ', () {
    final (goc, dich) = tachNguyenVanBanDich('NGUYÊN VĂN:\nGood morning\n\nBẢN DỊCH:\nChào buổi sáng');
    expect(goc, 'Good morning');
    expect(dich, 'Chào buổi sáng');
    expect(tachNguyenVanBanDich('**Chào** buổi sáng'), ('', 'Chào buổi sáng'));
  });

  test('Nhận chữ Trung, Nhật, Hàn và chữ có dấu tiếng Việt', () {
    expect(coChuCJK('教育部'), isTrue);
    expect(coChuCJK('안녕하세요'), isTrue);
    expect(coChuCJK('Xin chào thầy cô'), isFalse);
    expect(coDauTiengViet('Xin chào'), isTrue);
    expect(coDauTiengViet('Hello teachers'), isFalse);
    expect(dauYeuCauDich('Tiếng Anh', kieuDeHieu, true), 'Dịch sang: Tiếng Anh. Kiểu: Dễ hiểu. Song ngữ: có.');
  });
}
