import 'dart:math';
import 'dart:typed_data';

/// Giơ thẻ (kiểu Plickers): mỗi em một thẻ có mã QR, bốn cạnh ghi A, B, C, D.
/// Em xoay thẻ cho chữ mình chọn lên trên; app đọc chiều xoay của mã QR để biết đáp án.
const tienToThe = 'VNTD-GT:';

String maThe(int so) => '$tienToThe$so';

int? soTuMa(String? ma) {
  if (ma == null || !ma.startsWith(tienToThe)) return null;
  return int.tryParse(ma.substring(tienToThe.length));
}

/// Góc (độ) của cạnh trên mã QR, từ góc trên trái sang góc trên phải. 0 = thẻ thẳng (A lên trên).
double gocCanhTren(double x0, double y0, double x1, double y1) => atan2(y1 - y0, x1 - x0) * 180 / pi;

/// Đổi góc thành đáp án, có trừ góc hiệu chỉnh (khi máy ảnh trả ảnh xoay sẵn).
/// A: thẳng; B: thẻ xoay trái 90° (cạnh B lên trên); C: lộn ngược; D: xoay phải 90°.
String dapAnTuGoc(double goc, {double hieuChinh = 0}) {
  var g = goc - hieuChinh;
  while (g <= -180) {
    g += 360;
  }
  while (g > 180) {
    g -= 360;
  }
  if (g > -45 && g <= 45) return 'A';
  if (g > -135 && g <= -45) return 'B';
  if (g > 45 && g <= 135) return 'D';
  return 'C';
}

/// Kết quả một câu hỏi.
class CauGioThe {
  String tieuDe;
  String? dapAnDung;
  DateTime luc;

  /// Số thẻ -> đáp án.
  Map<int, String> traLoi;

  CauGioThe({required this.tieuDe, this.dapAnDung, required this.luc, Map<int, String>? traLoi}) : traLoi = traLoi ?? {};

  Map<String, int> get thongKe => {for (final c in ['A', 'B', 'C', 'D']) c: traLoi.values.where((v) => v == c).length};

  Map<String, dynamic> toJson() => {
        'td': tieuDe,
        'dung': dapAnDung,
        'luc': luc.toIso8601String(),
        'tl': {for (final e in traLoi.entries) '${e.key}': e.value},
      };

  factory CauGioThe.fromJson(Map<String, dynamic> j) => CauGioThe(
        tieuDe: j['td'] as String? ?? '',
        dapAnDung: j['dung'] as String?,
        luc: DateTime.tryParse(j['luc'] as String? ?? '') ?? DateTime.now(),
        traLoi: {for (final e in Map<String, dynamic>.from(j['tl'] as Map? ?? {}).entries) int.parse(e.key): e.value as String},
      );
}

// ---------------------------------------------------------------------------
// Đọc chiều thẻ từ chính ảnh mã QR.
// Bộ đọc ML Kit trả 4 góc mã theo khung ẢNH (góc trên trái của ảnh trước), không theo chiều mã,
// nên không dùng thứ tự góc để biết thẻ xoay. Mã QR có ô vuông định vị ở 3 góc; góc còn lại
// là góc dưới phải của mã. Tìm góc thiếu ô định vị trong ảnh là biết thẻ đang xoay về phía nào.
// ---------------------------------------------------------------------------

/// Ảnh xám: mỗi điểm một byte độ sáng (0 đen, 255 trắng). [tiLe] = cỡ ảnh này / cỡ ảnh gốc
/// (khi ảnh gốc lớn được thu nhỏ để xử lý nhanh), tọa độ truyền vào tính theo ảnh gốc.
class AnhXam {
  final Uint8List sang;
  final int rong;
  final int cao;
  final double tiLe;
  const AnhXam(this.sang, this.rong, this.cao, {this.tiLe = 1});

  double diem(double x, double y) {
    final xi = (x * tiLe).round().clamp(0, rong - 1).toInt();
    final yi = (y * tiLe).round().clamp(0, cao - 1).toInt();
    return sang[yi * rong + xi].toDouble();
  }
}

/// Ô (a, b) trong vùng 7x7 ở góc mã QR có thuộc phần đen của ô vuông định vị không.
bool _denDinhVi(int a, int b) => a == 0 || a == 6 || b == 0 || b == 6 || (a >= 2 && a <= 4 && b >= 2 && b <= 4);

/// Xếp 4 góc theo chiều kim đồng hồ (trên ảnh, trục y hướng xuống), bắt đầu từ góc gần góc trên trái ảnh nhất.
List<(double, double)> _xepGoc(List<(double, double)> g) {
  final cx = g.fold<double>(0, (s, p) => s + p.$1) / g.length;
  final cy = g.fold<double>(0, (s, p) => s + p.$2) / g.length;
  final ds = [...g]..sort((p, q) => atan2(p.$2 - cy, p.$1 - cx).compareTo(atan2(q.$2 - cy, q.$1 - cx)));
  var dau = 0;
  for (var i = 1; i < ds.length; i++) {
    if (ds[i].$1 + ds[i].$2 < ds[dau].$1 + ds[dau].$2) dau = i;
  }
  return [for (var i = 0; i < 4; i++) ds[(dau + i) % 4]];
}

/// Góc xoay của thẻ (độ, cùng quy ước với [gocCanhTren], dùng tiếp với [dapAnTuGoc]), tính từ ảnh mã QR.
/// [goc]: 4 góc mã QR trên ảnh (thứ tự nào cũng được). Trả về null khi ảnh mờ, không chắc chiều.
double? gocTuAnh(AnhXam anh, List<(double, double)> goc) {
  if (goc.length != 4) return null;
  final g = _xepGoc(goc); // trên trái, trên phải, dưới phải, dưới trái (theo ảnh)
  (double, double) toaDo(double u, double v) => (
        g[0].$1 * (1 - u) * (1 - v) + g[1].$1 * u * (1 - v) + g[2].$1 * u * v + g[3].$1 * (1 - u) * v,
        g[0].$2 * (1 - u) * (1 - v) + g[1].$2 * u * (1 - v) + g[2].$2 * u * v + g[3].$2 * (1 - u) * v,
      );
  List<double>? diemTot;
  var tot = -1.0;
  for (final n in const [21, 25, 29, 33]) {
    // độ sáng giữa từng ô của mã (lấy trung bình 5 điểm cho đỡ nhiễu)
    final m = List<double>.filled(n * n, 0);
    for (var j = 0; j < n; j++) {
      for (var i = 0; i < n; i++) {
        var t = 0.0;
        for (final (du, dv) in const [(0.0, 0.0), (0.22, 0.0), (-0.22, 0.0), (0.0, 0.22), (0.0, -0.22)]) {
          final (x, y) = toaDo((i + 0.5 + du) / n, (j + 0.5 + dv) / n);
          t += anh.diem(x, y);
        }
        m[j * n + i] = t / 5;
      }
    }
    final nguong = m.reduce((a, b) => a + b) / m.length;
    // mức khớp với ô định vị ở từng góc: trên trái, trên phải, dưới phải, dưới trái
    final diem = <double>[];
    for (final (i0, j0) in [(0, 0), (n - 7, 0), (n - 7, n - 7), (0, n - 7)]) {
      var khop = 0;
      for (var b = 0; b < 7; b++) {
        for (var a = 0; a < 7; a++) {
          if ((m[(j0 + b) * n + i0 + a] < nguong) == _denDinhVi(a, b)) khop++;
        }
      }
      diem.add(khop / 49);
    }
    final xep = [...diem]..sort();
    final ba = (xep[1] + xep[2] + xep[3]) / 3;
    if (ba > tot) {
      tot = ba;
      diemTot = diem;
    }
  }
  if (diemTot == null || tot < 0.8) return null;
  final xep = [...diemTot]..sort();
  if (xep[1] - xep[0] < 0.15) return null;
  final thieu = diemTot.indexOf(xep[0]);
  // góc thiếu ô định vị = góc dưới phải của mã: dưới phải -> thẳng (A), trên phải -> B, trên trái -> C, dưới trái -> D
  return const [180.0, -90.0, 0.0, 90.0][thieu];
}

/// Chia ảnh [rong] x [cao] thành [hang] x [cot] mảnh chồng lên nhau một phần, để đọc mã QR nhỏ (lớp đông).
/// Trả về (x, y, rộng, cao) từng mảnh.
List<(int, int, int, int)> chiaManh(int rong, int cao, int cot, int hang, {double chong = 0.22}) {
  final w = (rong / (cot - (cot - 1) * chong)).ceil().clamp(1, rong).toInt();
  final h = (cao / (hang - (hang - 1) * chong)).ceil().clamp(1, cao).toInt();
  final ds = <(int, int, int, int)>[];
  for (var r = 0; r < hang; r++) {
    for (var c = 0; c < cot; c++) {
      final x = cot == 1 ? 0 : ((rong - w) * c / (cot - 1)).round();
      final y = hang == 1 ? 0 : ((cao - h) * r / (hang - 1)).round();
      ds.add((x, y, w, h));
    }
  }
  return ds;
}
