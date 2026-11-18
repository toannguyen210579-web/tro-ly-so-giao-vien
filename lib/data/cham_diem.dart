/// Phần tính toán của Chấm trắc nghiệm (không phụ thuộc giao diện, có kiểm thử).
const chuLuaChon = ['A', 'B', 'C', 'D'];

/// Chuẩn hóa chuỗi đáp án thầy cô gõ nhanh: "abcd", "A B C D", "1 2 3 4", "1A 2B 3C"
/// đều thành "ABCD". Câu bỏ trống ghi bằng dấu "-" hoặc "_" hoặc "0".
String chuanHoaDapAn(String s, int soCau) {
  var t = s.toUpperCase();
  // Dạng "1A 2B 3C": bỏ số thứ tự đứng ngay trước chữ.
  t = t.replaceAll(RegExp(r'\d+\s*[\.\):]?\s*(?=[A-D])'), '');
  final b = StringBuffer();
  for (final ch in t.split('')) {
    if ('ABCD'.contains(ch)) {
      b.write(ch);
    } else if ('1234'.contains(ch)) {
      b.write(chuLuaChon[int.parse(ch) - 1]);
    } else if ('-_0'.contains(ch)) {
      b.write('-');
    }
  }
  var kq = b.toString();
  if (kq.length > soCau) kq = kq.substring(0, soCau);
  return kq.padRight(soCau, '-');
}

/// Số câu đúng. Câu nào đáp án để trống ("-") thì không tính.
int soCauDung(String dapAn, String traLoi) {
  var d = 0;
  for (var i = 0; i < dapAn.length && i < traLoi.length; i++) {
    if (dapAn[i] != '-' && dapAn[i] == traLoi[i]) d++;
  }
  return d;
}

/// Số câu có đáp án (bỏ câu để trống).
int soCauTinh(String dapAn) => dapAn.split('').where((c) => c != '-').length;

/// Điểm thang 10, làm tròn 2 chữ số.
double diemThang10(String dapAn, String traLoi) {
  final n = soCauTinh(dapAn);
  if (n == 0) return 0;
  return (soCauDung(dapAn, traLoi) * 1000 / n).round() / 100;
}

String hienDiem(double d) {
  final s = d.toStringAsFixed(2);
  return s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '').replaceAll('.', ',');
}

class BaiLam {
  String ten;
  String maDe;
  String traLoi;
  BaiLam({required this.ten, required this.maDe, required this.traLoi});

  Map<String, dynamic> toJson() => {'ten': ten, 'ma_de': maDe, 'tra_loi': traLoi};
  factory BaiLam.fromJson(Map<String, dynamic> j) =>
      BaiLam(ten: j['ten'] as String? ?? '', maDe: j['ma_de'] as String? ?? '', traLoi: j['tra_loi'] as String? ?? '');
}

class DeThi {
  String id;
  String ten;
  int soCau;

  /// Mã đề -> chuỗi đáp án dài đúng soCau.
  Map<String, String> dapAn;
  List<BaiLam> baiLam;

  DeThi({required this.id, required this.ten, required this.soCau, Map<String, String>? dapAn, List<BaiLam>? baiLam})
      : dapAn = dapAn ?? {},
        baiLam = baiLam ?? [];

  double? diemCua(BaiLam b) {
    final d = dapAn[b.maDe];
    return d == null ? null : diemThang10(d, b.traLoi);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'ten': ten,
        'so_cau': soCau,
        'dap_an': dapAn,
        'bai_lam': baiLam.map((b) => b.toJson()).toList(),
      };

  factory DeThi.fromJson(Map<String, dynamic> j) => DeThi(
        id: j['id'] as String,
        ten: j['ten'] as String? ?? '',
        soCau: j['so_cau'] as int? ?? 0,
        dapAn: Map<String, String>.from(j['dap_an'] as Map? ?? {}),
        baiLam: (j['bai_lam'] as List<dynamic>? ?? [])
            .map((e) => BaiLam.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}
