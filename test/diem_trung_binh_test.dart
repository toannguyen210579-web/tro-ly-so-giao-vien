import 'package:flutter_test/flutter_test.dart';
import 'package:tro_ly_so_giao_vien/data/tien_ich.dart';
import 'package:tro_ly_so_giao_vien/screens/nhan_xet.dart';

void main() {
  test('Điểm trung bình môn học kỳ theo Thông tư 22', () {
    // (8 + 7 + 9 + 2*8 + 3*9) / (3 + 5) = 67 / 8 = 8.375 -> 8.4
    final h = HocSinh('A', diemTx: '8 7 9', diemGk: '8', diemCk: '9');
    expect(h.diemTrungBinh, 8.4);
  });

  test('Thiếu điểm thì chưa tính', () {
    expect(HocSinh('B', diemTx: '8', diemGk: '').diemTrungBinh, isNull);
  });

  test('Ô hỏi mở đúng tiện ích theo từ khóa', () {
    expect(timTheoCau('Nhận xét lớp 6A')?.ma, 'nhan_xet');
    expect(timTheoCau('quét giấy tờ')?.ma, 'quet');
    expect(timTheoCau('lương cơ sở là bao nhiêu'), isNotNull);
    expect(timTheoCau('thời tiết hôm nay'), isNull);
  });
}
