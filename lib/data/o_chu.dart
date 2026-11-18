/// Ô chữ hàng ngang, cột dọc ghép thành từ khóa (phần tính toán, có kiểm thử).
const _co = 'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
const _khong = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';

/// "Bác Hồ" -> "BACHO": bỏ dấu, bỏ khoảng trắng, viết hoa (cách ghi đáp án ô chữ quen thuộc).
String chuanHoaO(String s) {
  final b = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    final i = _co.indexOf(ch);
    final c = i >= 0 ? _khong[i] : ch;
    if (RegExp(r'[a-z0-9]').hasMatch(c)) b.write(c.toUpperCase());
  }
  return b.toString();
}

class HangO {
  String cauHoi;
  String dapAn;
  HangO(this.cauHoi, this.dapAn);
  String get chu => chuanHoaO(dapAn);
  Map<String, dynamic> toJson() => {'h': cauHoi, 'd': dapAn};
  factory HangO.fromJson(Map<String, dynamic> j) => HangO(j['h'] as String? ?? '', j['d'] as String? ?? '');
}

class OChu {
  String id;
  String ten;
  String tuKhoa;
  List<HangO> hang;
  OChu({required this.id, required this.ten, required this.tuKhoa, required this.hang});

  String get khoa => chuanHoaO(tuKhoa);

  Map<String, dynamic> toJson() => {'id': id, 'ten': ten, 'k': tuKhoa, 'hang': hang.map((e) => e.toJson()).toList()};
  factory OChu.fromJson(Map<String, dynamic> j) => OChu(
        id: j['id'] as String,
        ten: j['ten'] as String? ?? '',
        tuKhoa: j['k'] as String? ?? '',
        hang: (j['hang'] as List<dynamic>? ?? []).map((e) => HangO.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      );

  /// Vị trí chữ của từ khóa trong từng hàng (-1 nếu hàng không chứa chữ đó).
  List<int> get viTriKhoa {
    final k = khoa;
    return [for (var i = 0; i < hang.length; i++) i < k.length ? hang[i].chu.indexOf(k[i]) : -1];
  }

  /// Lỗi cần sửa trước khi chơi; rỗng là hợp lệ.
  List<String> get loi {
    final k = khoa;
    final kq = <String>[];
    if (k.isEmpty) kq.add('Chưa có từ khóa.');
    if (hang.length != k.length) kq.add('Từ khóa có ${k.length} chữ cái, cần đúng ${k.length} hàng ngang (đang có ${hang.length}).');
    final vt = viTriKhoa;
    for (var i = 0; i < hang.length && i < k.length; i++) {
      if (hang[i].chu.isEmpty) {
        kq.add('Hàng ${i + 1} chưa có đáp án.');
      } else if (vt[i] < 0) {
        kq.add('Đáp án hàng ${i + 1} không có chữ "${k[i]}" của từ khóa.');
      }
    }
    return kq;
  }

  /// Số cột cần dịch sang phải của từng hàng để chữ từ khóa thẳng một cột.
  List<int> get doLech {
    final vt = viTriKhoa.map((v) => v < 0 ? 0 : v).toList();
    final m = vt.isEmpty ? 0 : vt.reduce((a, b) => a > b ? a : b);
    return [for (final v in vt) m - v];
  }

  int get soCot {
    final l = doLech;
    var c = 0;
    for (var i = 0; i < hang.length; i++) {
      final w = l[i] + hang[i].chu.length;
      if (w > c) c = w;
    }
    return c;
  }
}
