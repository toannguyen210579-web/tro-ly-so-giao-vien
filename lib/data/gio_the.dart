import 'dart:math';

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
