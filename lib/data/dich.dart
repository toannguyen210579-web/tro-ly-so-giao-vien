/// Phần xử lý chữ của tiện ích Dịch tài liệu (không cần mạng, có phép thử riêng).

/// Ngôn ngữ đích thầy cô chọn được. Ngôn ngữ gốc AI tự nhận.
const dsNgonNguDich = ['Tiếng Việt', 'Tiếng Anh', 'Tiếng Trung', 'Tiếng Nhật', 'Tiếng Hàn', 'Tiếng Pháp'];

/// Kiểu dịch: bám câu chữ cho văn bản, tài liệu; dễ hiểu để đưa học sinh đọc.
const kieuSatNghia = 'Sát nghĩa';
const kieuDeHieu = 'Dễ hiểu';

/// Mỗi lượt dịch là một trang: chữ chia thành khối tối đa chừng này ký tự (máy chủ đếm 20 trang mỗi ngày).
const kyTuMoiTrang = 2500;

/// Dòng đầu gửi kèm mỗi yêu cầu dịch, máy chủ đọc để biết dịch sang đâu, kiểu gì.
String dauYeuCauDich(String den, String kieu, bool songNgu) =>
    'Dịch sang: $den. Kiểu: $kieu. Song ngữ: ${songNgu ? 'có' : 'không'}.';

/// Tách chữ thành đoạn: dòng trống ngăn đoạn; chữ không có dòng trống thì mỗi dòng là một đoạn.
List<String> tachDoanDich(String chu) {
  final t = chu.replaceAll('\r\n', '\n').trim();
  if (t.isEmpty) return const [];
  final theoDongTrong = t.split(RegExp(r'\n\s*\n')).map((d) => d.trim()).where((d) => d.isNotEmpty).toList();
  if (theoDongTrong.length > 1) return theoDongTrong;
  return t.split('\n').map((d) => d.trim()).where((d) => d.isNotEmpty).toList();
}

/// Gom các đoạn thành từng khối (mỗi khối là một lượt dịch, không quá [toiDa] ký tự).
/// Đoạn dài quá thì cắt theo câu; câu dài quá nữa thì cắt cứng.
List<List<String>> chiaKhoiDich(List<String> doan, {int toiDa = kyTuMoiTrang}) {
  final nho = <String>[];
  for (final d in doan) {
    if (d.length <= toiDa) {
      nho.add(d);
      continue;
    }
    var cur = StringBuffer();
    for (final cau in d.split(RegExp(r'(?<=[.!?。！？])\s+'))) {
      if (cur.length + cau.length + 1 > toiDa && cur.isNotEmpty) {
        nho.add(cur.toString().trim());
        cur = StringBuffer();
      }
      if (cau.length > toiDa) {
        for (var i = 0; i < cau.length; i += toiDa) {
          nho.add(cau.substring(i, i + toiDa > cau.length ? cau.length : i + toiDa));
        }
      } else {
        cur.write('$cau ');
      }
    }
    if (cur.toString().trim().isNotEmpty) nho.add(cur.toString().trim());
  }
  final kq = <List<String>>[];
  var khoi = <String>[];
  var dai = 0;
  for (final d in nho) {
    if (khoi.isNotEmpty && dai + d.length + 2 > toiDa) {
      kq.add(khoi);
      khoi = [];
      dai = 0;
    }
    khoi.add(d);
    dai += d.length + 2;
  }
  if (khoi.isNotEmpty) kq.add(khoi);
  return kq;
}

/// Bỏ dấu markdown AI đôi khi vẫn thêm (**, #).
String boDauMarkdownDich(String s) =>
    s.replaceAll('**', '').replaceAll(RegExp(r'^#+\s*', multiLine: true), '').trim();

/// Ghép đoạn gốc với đoạn dịch theo thứ tự. Số đoạn không khớp thì ghép cả khối với cả bản dịch.
List<(String, String)> ghepSongNgu(List<String> goc, String dich) {
  final d = tachDoanDich(boDauMarkdownDich(dich));
  if (d.length == goc.length) return [for (var i = 0; i < goc.length; i++) (goc[i], d[i])];
  return [(goc.join('\n\n'), d.join('\n\n'))];
}

/// Tách câu trả lời dịch ảnh, trang PDF có song ngữ: dòng "NGUYÊN VĂN:" rồi chữ gốc, dòng "BẢN DỊCH:" rồi bản dịch.
/// Không thấy các dòng đó thì coi cả câu trả lời là bản dịch.
(String, String) tachNguyenVanBanDich(String s) {
  final t = boDauMarkdownDich(s);
  final u = t.toUpperCase();
  final i = u.indexOf('BẢN DỊCH:');
  if (i < 0) return ('', t);
  final j = u.indexOf('NGUYÊN VĂN:');
  final goc = j >= 0 && j < i ? t.substring(j + 'NGUYÊN VĂN:'.length, i).trim() : '';
  return (goc, t.substring(i + 'BẢN DỊCH:'.length).trim());
}

/// Có chữ Trung, Nhật, Hàn: phông PDF của app không có các chữ này, nên chỉ xuất tệp Word.
bool coChuCJK(String s) => RegExp(r'[぀-ヿ㐀-鿿가-힯＀-￯]').hasMatch(s);

/// Chữ có dấu tiếng Việt (để đoán ngôn ngữ gốc khi dịch trên máy lúc mất mạng).
bool coDauTiengViet(String s) =>
    RegExp(r'[ăâđêôơưàảãáạằẳẵắặầẩẫấậèẻẽéẹềểễếệìỉĩíịòỏõóọồổỗốộờởỡớợùủũúụừửữứựỳỷỹýỵ]', caseSensitive: false).hasMatch(s);
