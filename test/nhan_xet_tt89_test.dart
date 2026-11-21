import 'package:flutter_test/flutter_test.dart';
import 'package:tro_ly_so_giao_vien/screens/nhan_xet.dart';

void main() {
  test('Học sinh khuyết tật: lưu và đọc lại cờ khuyết tật, mức Miễn', () {
    final h = HocSinh('Lò Văn A', muc: mucMien, khuyetTat: true);
    final j = h.toJson();
    expect(j['kt'], true);
    final doc = HocSinh.fromJson(Map<String, dynamic>.from(j));
    expect(doc.khuyetTat, true);
    expect(doc.muc, 'Miễn');
  });

  test('Học sinh bình thường: không ghi cờ khuyết tật, dữ liệu cũ vẫn đọc được', () {
    expect(HocSinh('B').toJson().containsKey('kt'), false);
    expect(HocSinh.fromJson({'ten': 'C', 'muc': 'Tốt'}).khuyetTat, false);
  });

  test('Mức đánh giá theo Thông tư 89/2026 có Miễn ở cả hai cấp', () {
    expect(mucTieuHoc, contains(mucMien));
    expect(mucTrungHoc, contains(mucMien));
    expect(vanBanDanhGia, contains('89/2026'));
  });
}
