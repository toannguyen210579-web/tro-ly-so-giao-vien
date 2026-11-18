import 'package:flutter_test/flutter_test.dart';
import 'package:tro_ly_so_giao_vien/data/tinh_luong.dart';

void main() {
  test('Hệ số theo bậc', () {
    expect(a1.heSo(4), 3.33);
    expect(a1.heSo(9), 4.98);
    expect(a0.heSo(10), 4.89);
    expect(a22.heSo(8), 6.38);
    expect(a21.heSo(8), 6.78);
    expect(ngachCua('Mầm non', 'Hạng III').ma, 'A0');
    expect(ngachCua('THCS', 'Hạng II').ma, 'A2.2');
  });

  test('Thâm niên và ưu đãi', () {
    expect(phanTramThamNien(4), 0);
    expect(phanTramThamNien(5), 5);
    expect(phanTramThamNien(12), 12);
    expect(uuDaiMacDinh('Tiểu học'), 45);
    expect(uuDaiMacDinh('THPT'), 40);
    expect(soNamTron(DateTime(2015, 9, 1), DateTime(2026, 8, 31)), 10);
    expect(soNamTron(DateTime(2015, 9, 1), DateTime(2026, 9, 1)), 11);
  });

  test('Lương giáo viên THCS hạng III bậc 4, thâm niên 10%', () {
    final k = tinhLuong(heSo: 3.33, phanTramUuDai: 40, phanTramThamNienNghe: 10);
    expect(k.luongHeSo, 8424900);
    expect(k.uuDai, 3369960);
    expect(k.thamNien, 842490);
    expect(k.baoHiem, 973076);
    expect(k.thucNhan, 8424900 + 3369960 + 842490 - 973076);
    expect(dinhDangTien(8424900), '8.424.900');
  });
}
