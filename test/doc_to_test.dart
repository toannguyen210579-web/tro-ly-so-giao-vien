import 'package:flutter_test/flutter_test.dart';
import 'package:tro_ly_so_giao_vien/screens/doc_to_ghi_loi.dart';

void main() {
  test('Tách văn bản dài thành đoạn ngắn để đọc', () {
    expect(tachCau('Câu một. Câu hai!\n\nĐoạn mới'), ['Câu một. Câu hai!', 'Đoạn mới']);
    final dai = List.filled(100, 'chữ').join(' ');
    final ds = tachCau(dai, toiDa: 50);
    expect(ds.every((d) => d.length <= 50), isTrue);
    expect(ds.join(' '), dai);
  });
}
