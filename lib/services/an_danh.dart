import '../screens/nhan_xet.dart' show docLop;

/// Kết quả làm sạch câu hỏi trước khi gửi lên AI.
class CauDaLamSach {
  /// Nội dung gửi đi: tên học sinh trong danh sách lớp đã thay bằng mã, số điện thoại, email, số giấy tờ đã che.
  final String noiDung;

  /// true khi câu có dấu hiệu thông tin cá nhân. Máy chủ sẽ gửi câu này sang Claude thay vì Gemini miễn phí.
  final bool riengTu;

  /// Tên học sinh → mã đã dùng (gồm cả các mã từ những câu trước trong cùng cuộc trò chuyện).
  final Map<String, String> ma;
  const CauDaLamSach(this.noiDung, this.riengTu, [this.ma = const {}]);
}

/// Đổi mã HS01, HS02… trong câu trả lời của AI về lại tên thật, để thầy cô đọc thấy đúng tên học sinh.
/// Việc này làm trên máy, tên không rời khỏi điện thoại.
String traTen(String s, Map<String, String> ma) {
  var kq = s;
  for (final e in ma.entries) {
    kq = kq.replaceAll(RegExp('(?<![A-Za-z0-9])${e.value}(?![0-9])'), e.key);
  }
  return kq;
}

// Họ phổ biến của người Việt; tên đồng bào Tây Nguyên thường mở đầu bằng Y, H', Ksor, Rơ Mah, Niê...
const _ho = [
  'Nguyễn', 'Trần', 'Lê', 'Phạm', 'Hoàng', 'Huỳnh', 'Phan', 'Vũ', 'Võ', 'Đặng', 'Bùi', 'Đỗ', 'Hồ', 'Ngô',
  'Dương', 'Lý', 'Đào', 'Đoàn', 'Vương', 'Trịnh', 'Trương', 'Lâm', 'Mai', 'Tô', 'Hà', 'Cao', 'Đinh',
  'Lương', 'Tạ', 'Quách', 'Lưu', 'Châu', 'Thái', 'Kiều', 'Phùng', 'Hứa', 'Triệu', 'Từ', 'Lạc', 'Âu',
  'Ksor', 'Nay', 'Rơ', 'Kpă', 'Siu', 'Niê', 'Byă', 'Êban', 'Mlô', 'Adrơng', 'Ayŭn',
];

final _tenTheoHo = RegExp(
  "(?<![\\p{L}])(?:${_ho.join('|')})(?:\\s+\\p{Lu}[\\p{Ll}']*){1,3}",
  unicode: true,
);
final _tenDongBao = RegExp(r"(?<![\p{L}])(?:Y|H')\s?\p{Lu}[\p{Ll}]+(?:\s+\p{Lu}[\p{Ll}]+){0,2}", unicode: true);
final _xungHoTen = RegExp(
  // Chữ xưng hô viết thường hay hoa đầu đều được, nhưng tên phía sau phải viết hoa
  r'(?<![\p{L}])(?:[Ee]m|[Hh]ọc sinh|[Hh]ọc trò|[Pp]hụ huynh|[Cc]on tôi|[Cc]on em|[Cc]háu|[Bb]é|[Bb]ạn|[Aa]nh|[Cc]hị|[Cc]ô|[Tt]hầy|[Ôô]ng|[Bb]à)\s+\p{Lu}[\p{Ll}]+',
  unicode: true,
);
final _soDienThoai = RegExp(r'(?<!\d)(?:\+84|0)(?:[\s.\-]?\d){9,10}(?!\d)');
final _email = RegExp(r'[\w.+\-]+@[\w\-]+(?:\.[\w\-]+)+');
final _soGiayTo = RegExp(r'(?<!\d)\d{12}(?!\d)'); // số căn cước 12 chữ số

/// Làm sạch câu hỏi ngay trên máy:
/// 1. Tên học sinh có trong danh sách lớp → mã HS01, HS02… (đánh số theo lớp và thứ tự trong lớp).
/// 2. Số điện thoại, email, số căn cước → che đi.
/// 3. Có tên người (theo họ phổ biến, cách xưng hô) dù không có trong danh sách → đánh dấu riêng tư.
/// Hơi nghi là đánh dấu riêng tư, để câu đó đi qua Claude.
/// [maDaCo]: mã đã đặt ở các câu trước, để một em giữ đúng một mã suốt cuộc trò chuyện.
Future<CauDaLamSach> lamSachCauHoi(String cau, {Map<String, String> maDaCo = const {}}) async {
  var s = cau;
  var riengTu = false;
  final ma = Map<String, String>.from(maDaCo);

  // 1. Tên trong danh sách lớp (tên dài thay trước để "Nguyễn Văn An" không bị cắt thành "An")
  try {
    final ds = await docLop();
    final ten = <String>{};
    for (final lop in ds) {
      for (final h in lop.hocSinh) {
        final t = h.ten.trim();
        if (t.split(RegExp(r'\s+')).length >= 2) ten.add(t);
      }
    }
    // Mã đánh theo thứ tự xuất hiện trong cuộc trò chuyện (HS01, HS02…), không trùng giữa các lớp
    final theoDoDai = ten.toList()..sort((a, b) => b.length.compareTo(a.length));
    for (final t in theoDoDai) {
      final m = RegExp('(?<![\\p{L}])${RegExp.escape(t)}(?![\\p{L}])', unicode: true, caseSensitive: false);
      if (m.hasMatch(s)) {
        final maEm = ma[t] ??= 'HS${(ma.length + 1).toString().padLeft(2, '0')}';
        s = s.replaceAll(m, maEm);
        riengTu = true;
      }
    }
  } catch (_) {
    // Chưa có danh sách lớp: chỉ dựa vào các dấu hiệu bên dưới
  }

  // 2. Số liên lạc, giấy tờ
  for (final (m, thay) in [(_email, '[email]'), (_soDienThoai, '[số điện thoại]'), (_soGiayTo, '[số giấy tờ]')]) {
    if (m.hasMatch(s)) {
      s = s.replaceAll(m, thay);
      riengTu = true;
    }
  }

  // 3. Có vẻ là tên người
  if (_tenTheoHo.hasMatch(s) || _tenDongBao.hasMatch(s) || _xungHoTen.hasMatch(s)) riengTu = true;

  return CauDaLamSach(s, riengTu, ma);
}
