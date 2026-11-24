/// Thử thách cả lớp: chiếu câu hỏi, đếm giờ, học sinh ghi đáp án lên bảng con,
/// em trả lời sai bị loại, em trụ lại đến cuối là người thắng (phần tính toán, có kiểm thử).

class CauThuThach {
  /// Câu hỏi; câu trắc nghiệm có thêm các dòng lựa chọn A., B., C., D.
  final String hoi;
  final String dapAn;
  const CauThuThach(this.hoi, this.dapAn);

  Map<String, dynamic> toJson() => {'h': hoi, 'd': dapAn};
  factory CauThuThach.fromJson(Map<String, dynamic> j) => CauThuThach(j['h'] as String? ?? '', j['d'] as String? ?? '');

  /// Đáp án trắc nghiệm chỉ ghi một chữ (B) thì kèm nội dung lựa chọn: "B. Cá voi".
  String get dapAnDayDu {
    final d = dapAn.trim();
    final m = RegExp(r'^([A-Da-d])\s*[.)]?$').firstMatch(d);
    if (m == null) return d;
    final chu = m.group(1)!.toUpperCase();
    for (final dong in hoi.split('\n')) {
      final l = RegExp(r'^\s*([A-Da-d])\s*[.)]\s*(.+)$').firstMatch(dong);
      if (l != null && l.group(1)!.toUpperCase() == chu) return '$chu. ${l.group(2)!.trim()}';
    }
    return chu;
  }

  @override
  bool operator ==(Object other) => other is CauThuThach && other.hoi == hoi && other.dapAn == dapAn;

  @override
  int get hashCode => Object.hash(hoi, dapAn);

  @override
  String toString() => 'CauThuThach($hoi | $dapAn)';
}

class BoThuThach {
  String id;
  String ten;
  List<CauThuThach> cau;
  BoThuThach({required this.id, required this.ten, required this.cau});

  Map<String, dynamic> toJson() => {'id': id, 'ten': ten, 'cau': [for (final c in cau) c.toJson()]};
  factory BoThuThach.fromJson(Map<String, dynamic> j) => BoThuThach(
        id: j['id'] as String? ?? '',
        ten: j['ten'] as String? ?? '',
        cau: [for (final c in (j['cau'] as List<dynamic>? ?? [])) CauThuThach.fromJson(Map<String, dynamic>.from(c as Map))],
      );
}

/// Bộ câu hỏi mẫu để thầy cô bấm chơi thử ngay.
BoThuThach boThuThachMau() => BoThuThach(id: 'mau', ten: 'Mẫu: Kiến thức chung', cau: const [
      CauThuThach('Thủ đô của nước Cộng hòa xã hội chủ nghĩa Việt Nam là thành phố nào?', 'Hà Nội'),
      CauThuThach('12 × 8 bằng bao nhiêu?', '96'),
      CauThuThach('Ở áp suất khí quyển bình thường, nước sôi ở bao nhiêu độ C?', '100 độ C'),
      CauThuThach('Ai là tác giả của "Truyện Kiều"?', 'Nguyễn Du'),
      CauThuThach('Hành tinh nào gần Mặt Trời nhất?', 'Sao Thủy'),
      CauThuThach('Chiến thắng Điện Biên Phủ diễn ra vào năm nào?', '1954'),
      CauThuThach('Con vật nào sau đây là động vật có vú?\nA. Cá chép\nB. Cá voi\nC. Cá mập\nD. Cá ngựa', 'B'),
      CauThuThach('Đỉnh núi cao nhất Việt Nam tên là gì?', 'Phan Xi Păng'),
    ]);

/// Tách câu hỏi từ chữ thầy cô dán vào (từ Word, Zalo, hay do AI soạn). Nhận các kiểu:
/// - mỗi dòng "Câu hỏi | Đáp án";
/// - "Câu 1: ..." (có thể kèm các dòng A. B. C. D.), dòng sau "Đáp án: ...";
/// - các câu cách nhau bằng một dòng trống.
List<CauThuThach> tachCauHoi(String s) {
  final kq = <CauThuThach>[];
  String? hoi;
  String? da;
  var sauDongTrong = false;
  void chot() {
    final h = hoi?.trim() ?? '';
    if (h.isNotEmpty) kq.add(CauThuThach(h, (da ?? '').trim()));
    hoi = null;
    da = null;
  }

  final reDa = RegExp(r'^(đáp án|dap an|đa|trả lời|tra loi)\s*(đúng)?\s*[:：\-–]\s*');
  final reMuiTen = RegExp(r'^(=>|->|→)\s*');
  final reCau = RegExp(r'^(câu|cau)\s*\d+\s*(\([^)]*\))?\s*[:.)\-–]?\s*');
  final reSo = RegExp(r'^\d+\s*[.)]\s+');
  final reLuaChon = RegExp(r'^[a-d]\s*[.)]\s*\S');
  final reBo = RegExp(r'^(nguồn|tham khảo|lưu ý|ghi chú)\s*[:：]|https?://');

  for (final dong in s.split(RegExp(r'\r?\n'))) {
    final d = dong.trim();
    final t = d.toLowerCase();
    if (d.isEmpty) {
      // Dòng trống: câu đã có đáp án thì chốt; chưa có thì có thể đáp án ở dòng sau
      if (da != null) chot();
      sauDongTrong = true;
      continue;
    }
    if (reBo.hasMatch(t)) continue;
    final moiDoan = sauDongTrong;
    sauDongTrong = false;
    final mDa = reDa.firstMatch(t) ?? reMuiTen.firstMatch(t);
    if (mDa != null && hoi != null) {
      da = d.substring(mDa.end);
      continue;
    }
    final gach = d.indexOf('|');
    if (gach > 0) {
      chot();
      final dau = (reCau.firstMatch(t) ?? reSo.firstMatch(t))?.end ?? 0;
      hoi = d.substring(dau < gach ? dau : 0, gach);
      da = d.substring(gach + 1);
      chot();
      continue;
    }
    if (hoi != null && da == null && reLuaChon.hasMatch(t)) {
      hoi = '$hoi\n$d';
      continue;
    }
    final mCau = reCau.firstMatch(t) ?? reSo.firstMatch(t);
    // Kiểu hai dòng không ghi "Đáp án": dòng hỏi kết thúc bằng dấu ?, dòng sau ngắn là đáp án
    if (mCau == null && hoi != null && da == null && (hoi ?? '').trimRight().endsWith('?') && !d.endsWith('?') && d.length <= 80) {
      da = d;
      continue;
    }
    if (mCau != null || hoi == null || da != null || moiDoan) {
      chot();
      hoi = mCau == null ? d : d.substring(mCau.end);
      continue;
    }
    hoi = '$hoi $d'; // câu hỏi dài, xuống dòng giữa chừng
  }
  chot();
  return kq;
}

/// Chuyển bộ câu hỏi về dạng chữ để sửa; tachCauHoi đọc lại ra đúng như cũ.
String vanBanBo(List<CauThuThach> cau) => [for (var i = 0; i < cau.length; i++) 'Câu ${i + 1}: ${cau[i].hoi}\nĐáp án: ${cau[i].dapAn}'].join('\n\n');

/// Câu nhờ AI soạn bộ câu hỏi; câu trả lời theo mẫu "Câu 1: ... / Đáp án: ..." để tachCauHoi đọc được.
String cauNhoAISoan(String chuDe, String lop, int soCau) =>
    'Soạn $soCau câu hỏi cho trò chơi ôn tập "Thử thách cả lớp" (học sinh ghi đáp án lên bảng con trong 15 đến 30 giây) '
    'về: $chuDe${lop.trim().isEmpty ? '' : ', dành cho học sinh ${lop.trim()}'}. '
    'Kiến thức đúng chương trình, mỗi câu chỉ có một đáp án đúng, đáp án ngắn (một số, một từ hoặc một cụm từ); '
    'có thể xen vài câu trắc nghiệm bốn lựa chọn A, B, C, D, mỗi lựa chọn một dòng. Kiểm tra lại từng đáp án cho chính xác. '
    'Chỉ trả về các câu hỏi đúng mẫu dưới đây, không thêm lời dẫn, không dùng markdown:\n'
    'Câu 1: <câu hỏi>\nĐáp án: <đáp án>\n\nCâu 2: <câu hỏi>\nĐáp án: <đáp án>';

/// Bỏ lời dẫn AI viết trước "Câu 1".
String catTuCau1(String s) {
  final m = RegExp(r'(^|\n)\s*\**\s*C[âa]u\s*1\s*[:.)]', caseSensitive: false).firstMatch(s);
  return m == null ? s : s.substring(m.start).trim();
}

/// Một ván chơi: ai còn, ai bị loại.
class VanThuThach {
  final List<String> ca;
  final Set<String> biLoai = {};
  VanThuThach(this.ca);

  List<String> get conLai => [for (final t in ca) if (!biLoai.contains(t)) t];

  /// Loại các em trả lời sai ở câu vừa rồi. Tất cả các em còn lại đều sai thì không loại ai
  /// (như luật cứu trợ quen thuộc), trả về false.
  bool loai(Iterable<String> sai) {
    final s = {for (final t in sai) if (ca.contains(t) && !biLoai.contains(t)) t};
    if (s.isEmpty) return true;
    if (s.length >= conLai.length) return false;
    biLoai.addAll(s);
    return true;
  }

  /// Cứu trợ: cho cả lớp vào chơi lại.
  void cuuTro() => biLoai.clear();
}

/// Kết quả để gửi nhóm Zalo lớp, phụ huynh.
String ketQuaThuThach({required String tenBo, required String tenLop, required int soCau, required List<String> conLai, required int siSo}) {
  final b = StringBuffer('Thử thách cả lớp${tenLop.isEmpty ? '' : ' · Lớp $tenLop'} · $tenBo\n');
  if (siSo == 0) {
    b.write('Đã chơi $soCau câu hỏi.');
  } else {
    b.write('Qua $soCau câu hỏi, ${conLai.length}/$siSo em trụ lại đến cuối: ${conLai.join(', ')}.');
  }
  return b.toString();
}
