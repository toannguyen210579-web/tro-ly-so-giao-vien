/// Tính lương giáo viên công lập (phần tính toán, có kiểm thử).
/// Căn cứ, cập nhật 18/11/2026:
/// - Lương cơ sở 2.530.000 đồng/tháng từ 01/7/2026: Nghị định 161/2026/NĐ-CP.
/// - Bảng lương viên chức: Nghị định 204/2004/NĐ-CP; hạng chức danh giáo viên: các Thông tư 01, 02, 03, 04/2021/TT-BGDĐT
///   được sửa đổi bởi Thông tư 93/2026/TT-BGDĐT.
/// - Phụ cấp ưu đãi theo nghề: Nghị định 182/2026/NĐ-CP (áp dụng từ 01/01/2026).
/// - Phụ cấp thâm niên nhà giáo: Nghị định 77/2021/NĐ-CP (đủ 5 năm được 5%, từ năm thứ sáu mỗi năm thêm 1%).
/// - Đóng bảo hiểm phần người lao động: BHXH 8%, BHYT 1,5%, BHTN 1%.

const luongCoSo = 2530000;
const ngayCapNhatLuong = '18/11/2026';

const canCuLuong = [
  'Lương cơ sở 2.530.000 đồng/tháng từ 01/7/2026: Nghị định 161/2026/NĐ-CP',
  'Hệ số lương theo bảng lương viên chức: Nghị định 204/2004/NĐ-CP; hạng chức danh giáo viên theo Thông tư 93/2026/TT-BGDĐT',
  'Phụ cấp ưu đãi theo nghề: Nghị định 182/2026/NĐ-CP, áp dụng từ 01/01/2026',
  'Phụ cấp thâm niên nhà giáo: Nghị định 77/2021/NĐ-CP',
  'Trừ bảo hiểm: BHXH 8%, BHYT 1,5%, BHTN 1% trên lương, phụ cấp chức vụ, thâm niên vượt khung, thâm niên nghề',
];

/// Một nhóm hệ số (ngạch) trong bảng lương viên chức.
class NgachLuong {
  final String ma;
  final double batDau;
  final double buoc;
  final int soBac;
  const NgachLuong(this.ma, this.batDau, this.buoc, this.soBac);

  double heSo(int bac) => ((batDau + buoc * (bac - 1)) * 100).round() / 100;
}

const a0 = NgachLuong('A0', 2.10, 0.31, 10);
const a1 = NgachLuong('A1', 2.34, 0.33, 9);
const a22 = NgachLuong('A2.2', 4.00, 0.34, 8);
const a21 = NgachLuong('A2.1', 4.40, 0.34, 8);

const capDay = ['Mầm non', 'Tiểu học', 'THCS', 'THPT'];
const hangGV = ['Hạng I', 'Hạng II', 'Hạng III'];

NgachLuong ngachCua(String cap, String hang) {
  if (cap == 'Mầm non') {
    return switch (hang) { 'Hạng I' => a22, 'Hạng II' => a1, _ => a0 };
  }
  return switch (hang) { 'Hạng I' => a21, 'Hạng II' => a22, _ => a1 };
}

/// Mức phụ cấp ưu đãi mặc định theo cấp dạy (Nghị định 182/2026/NĐ-CP).
int uuDaiMacDinh(String cap) => (cap == 'Mầm non' || cap == 'Tiểu học') ? 45 : 40;

/// Phần trăm phụ cấp thâm niên theo số năm dạy có đóng BHXH (đủ 5 năm: 5%).
int phanTramThamNien(int soNam) => soNam >= 5 ? soNam : 0;

/// Số năm tròn tính từ ngày bắt đầu đến ngày tính.
int soNamTron(DateTime tu, DateTime den) {
  var n = den.year - tu.year;
  if (den.month < tu.month || (den.month == tu.month && den.day < tu.day)) n--;
  return n < 0 ? 0 : n;
}

/// Ngày nâng bậc kế tiếp: 3 năm (36 tháng) với các ngạch từ cao đẳng trở lên.
DateTime ngayNangBacKe(DateTime ngayXepBac) =>
    DateTime(ngayXepBac.year + 3, ngayXepBac.month, ngayXepBac.day);

class KetQuaLuong {
  final double heSo;
  final int luongHeSo;
  final int phuCapChucVu;
  final int chenhLechBaoLuu;
  final int thamNienVuotKhung;
  final int uuDai;
  final int thamNien;
  final int khuVuc;
  final int baoHiem;
  int get tongThuNhap => luongHeSo + phuCapChucVu + chenhLechBaoLuu + thamNienVuotKhung + uuDai + thamNien + khuVuc;
  int get thucNhan => tongThuNhap - baoHiem;

  const KetQuaLuong({
    required this.heSo,
    required this.luongHeSo,
    required this.phuCapChucVu,
    required this.chenhLechBaoLuu,
    required this.thamNienVuotKhung,
    required this.uuDai,
    required this.thamNien,
    required this.khuVuc,
    required this.baoHiem,
  });
}

int _tien(double x) => x.round();

/// Tính lương một tháng.
/// [heSo] hệ số lương theo bậc; [heSoBaoLuu] hệ số chênh lệch bảo lưu (nếu có);
/// [heSoChucVu] phụ cấp chức vụ (tổ trưởng, phó hiệu trưởng…); [heSoKhuVuc] phụ cấp khu vực;
/// [phanTramVuotKhung] thâm niên vượt khung; [phanTramUuDai]; [phanTramThamNienNghe].
KetQuaLuong tinhLuong({
  required double heSo,
  double heSoBaoLuu = 0,
  double heSoChucVu = 0,
  double heSoKhuVuc = 0,
  int phanTramVuotKhung = 0,
  required int phanTramUuDai,
  required int phanTramThamNienNghe,
  int coSo = luongCoSo,
}) {
  final luong = heSo * coSo;
  final chucVu = heSoChucVu * coSo;
  final baoLuu = heSoBaoLuu * coSo;
  final vuotKhung = luong * phanTramVuotKhung / 100;
  // Phụ cấp ưu đãi, thâm niên tính trên lương + phụ cấp chức vụ + thâm niên vượt khung (kể cả hệ số bảo lưu).
  final nen = luong + chucVu + baoLuu + vuotKhung;
  final uuDai = nen * phanTramUuDai / 100;
  final thamNien = nen * phanTramThamNienNghe / 100;
  final baoHiem = (nen + thamNien) * 10.5 / 100;
  return KetQuaLuong(
    heSo: heSo,
    luongHeSo: _tien(luong),
    phuCapChucVu: _tien(chucVu),
    chenhLechBaoLuu: _tien(baoLuu),
    thamNienVuotKhung: _tien(vuotKhung),
    uuDai: _tien(uuDai),
    thamNien: _tien(thamNien),
    khuVuc: _tien(heSoKhuVuc * coSo),
    baoHiem: _tien(baoHiem),
  );
}

/// 8420000 -> "8.420.000"
String dinhDangTien(int x) {
  final s = x.abs().toString();
  final b = StringBuffer(x < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return b.toString();
}
