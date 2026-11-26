import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Địa chỉ máy chủ trung gian (Cloudflare Worker).
/// Để trống thì app chạy chế độ thử: trả lời giả lập, không gọi AI thật.
/// Khóa API Claude KHÔNG bao giờ đặt trong app, chỉ đặt trên máy chủ.
const diaChiMayChu = 'https://tro-ly-gv.toannguyen210579.workers.dev';

/// Trang công khai trên máy chủ (Google Play, App Store bắt buộc có đường dẫn).
const trangDieuKhoan = '$diaChiMayChu/dieu-khoan';
const trangQuyenRiengTu = '$diaChiMayChu/quyen-rieng-tu';
const trangHoTro = '$diaChiMayChu/ho-tro';
const emailHoTro = 'hotro.trolysogv@gmail.com';

/// Tên loại trong app -> chế độ trên máy chủ.
const _cheDo = {
  'hoi': 'hoi',
  'nhan_xet': 'nhanxet',
  'tin_ph': 'tinnhan',
  'giai_de': 'giaide',
  'de_tuong_tu': 'detuongtu',
  'bien_ban': 'bienban',
  'chep_chu': 'chep_chu', // Biên bản: chép chữ từ ảnh, trang PDF
  'dich': 'dich', // Dịch tài liệu: mỗi lần một trang
  'danh_gia': 'danhgia', // Đánh giá, xếp loại: viết nháp Ưu điểm, Hạn chế cho phiếu năm
  'trinh_chieu': 'trinhchieu', // Tạo bài trình chiếu: dựng dàn trang chiếu từ giáo án
};

class KetQuaTroLy {
  final String? traLoi;
  final String? loi;
  final int? conLai;
  const KetQuaTroLy({this.traLoi, this.loi, this.conLai});
}

/// Số lượt còn lại hôm nay, lấy từ máy chủ.
class LuotHomNay {
  final Map<String, int> conLai; // theo chế độ máy chủ: hoi, nhanxet, tinnhan
  final int thuong; // lượt thưởng do xem quảng cáo
  const LuotHomNay(this.conLai, this.thuong);
}

/// Bỏ dấu markdown (**, #) để đưa câu trả lời vào ô soạn thảo.
String boDauMarkdown(String s) => s
    .replaceAll('**', '')
    .replaceAll(RegExp(r'^#{1,6}\s*', multiLine: true), '')
    .replaceAll(RegExp(r'^\s*[-*]\s+', multiLine: true), '- ')
    .trim();

class TroLyApi {
  static Future<String> maMay() async {
    final p = await SharedPreferences.getInstance();
    var ma = p.getString('ma_may');
    if (ma == null) {
      final r = Random.secure();
      ma = List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
      await p.setString('ma_may', ma);
    }
    return ma;
  }

  static Future<Map<String, dynamic>> _post(String duong, Map<String, dynamic> du, {int giay = 60}) async {
    final res = await http
        .post(
          Uri.parse('$diaChiMayChu$duong'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(du),
        )
        .timeout(Duration(seconds: giay));
    final j = jsonDecode(utf8.decode(res.bodyBytes));
    return j is Map<String, dynamic> ? j : <String, dynamic>{};
  }

  /// loai: 'hoi' (Hỏi Trợ lý), 'nhan_xet' (viết nhận xét), 'tin_ph' (soạn tin phụ huynh).
  /// 'giai_de', 'de_tuong_tu' (được kèm tối đa 4 ảnh JPEG mã base64), 'bien_ban' (sắp xếp biên bản họp).
  /// [riengTu]: câu có thông tin cá nhân, máy chủ sẽ dùng Claude thay vì Gemini miễn phí.
  /// [lichSu]: các cặp (câu hỏi, câu trả lời) trước đó trong Hỏi Trợ lý, để hỏi tiếp không phải nhắc lại.
  static Future<KetQuaTroLy> hoi(String noiDung,
      {String loai = 'hoi',
      List<String> anh = const [],
      List<String> pdf = const [],
      bool riengTu = false,
      List<(String, String)> lichSu = const []}) async {
    if (diaChiMayChu.isEmpty) {
      await Future.delayed(const Duration(milliseconds: 600));
      return const KetQuaTroLy(traLoi: '(Chế độ thử) Đây là câu trả lời mẫu.', conLai: 4);
    }
    final cheDo = _cheDo[loai];
    if (cheDo == null) {
      return const KetQuaTroLy(loi: 'Tiện ích này chưa dùng được AI.');
    }
    try {
      final ma = await maMay();
      // Mạng chập chờn (rớt sóng, đổi wifi sang 4G) thì tự gửi lại một lần, thầy cô không phải bấm lại
      Future<Map<String, dynamic>> guiMot() => _post(
        '/v1/ai',
        {
          'device_id': ma,
          'mode': cheDo,
          'input': noiDung,
          if (anh.isNotEmpty) 'images': anh,
          if (pdf.isNotEmpty) 'pdfs': pdf,
          if (riengTu) 'private': true,
          if (lichSu.isNotEmpty) 'history': [for (final (q, a) in lichSu.skip(lichSu.length > 4 ? lichSu.length - 4 : 0)) {'q': q, 'a': a}],
        },
        // Giải đề, ra đề tương tự viết lời giải dài, bài trình chiếu viết cả dàn trang: chờ lâu hơn để không báo lỗi khi máy chủ đang đổi sang AI dự phòng
        giay: (loai == 'giai_de' || loai == 'de_tuong_tu' || loai == 'trinh_chieu')
            ? 150
            : (anh.isEmpty && pdf.isEmpty && loai != 'dich' ? 60 : 120),
      );
      Map<String, dynamic> j;
      try {
        j = await guiMot();
      } on TimeoutException {
        rethrow; // đã chờ đủ lâu, gửi lại chỉ làm thầy cô chờ gấp đôi
      } catch (_) {
        await Future.delayed(const Duration(seconds: 1));
        j = await guiMot();
      }
      if (j['ok'] == true) {
        final con = j['remaining'] is int ? j['remaining'] as int : null;
        final thuong = j['bonus'] is int ? j['bonus'] as int : 0;
        if (con != null) await _ghiLuot(cheDo, con + thuong);
        return KetQuaTroLy(traLoi: j['text'] as String?, conLai: con == null ? null : con + thuong);
      }
      if (j['error'] == 'het_luot') await _ghiLuot(cheDo, 0);
      return KetQuaTroLy(loi: (j['message'] as String?) ?? 'Có lỗi, thầy cô thử lại.');
    } on TimeoutException {
      return const KetQuaTroLy(loi: 'AI trả lời lâu quá. Thầy cô bấm Gửi lại hoặc hỏi ngắn hơn.');
    } catch (_) {
      return const KetQuaTroLy(loi: 'Không kết nối được. Thầy cô kiểm tra mạng rồi thử lại.');
    }
  }

  /// Đọc to qua máy chủ (Gemini, hoặc Google Cloud khi có khóa) khi điện thoại không có bộ đọc.
  /// [toc]: 1 là bình thường. Trả về (âm thanh, đuôi tệp 'wav'/'mp3', lời báo lỗi).
  static Future<(Uint8List?, String, String?)> docQuaMang(String chu, {double toc = 1}) async {
    if (diaChiMayChu.isEmpty) return (null, '', 'Chưa nối máy chủ.');
    final ma = await maMay();
    Future<Map<String, dynamic>> guiMot() => _post('/v1/tts', {'device_id': ma, 'text': chu, 'rate': toc}, giay: 45);
    try {
      Map<String, dynamic> j;
      try {
        j = await guiMot();
      } on TimeoutException {
        rethrow;
      } catch (_) {
        await Future.delayed(const Duration(seconds: 1));
        j = await guiMot();
      }
      if (j['ok'] == true && j['audio'] is String) {
        return (base64Decode(j['audio'] as String), j['mime'] == 'audio/mpeg' ? 'mp3' : 'wav', null);
      }
      return (null, '', (j['message'] as String?) ?? 'Chưa đọc được, thầy cô thử lại.');
    } catch (_) {
      return (null, '', 'Máy chưa có giọng đọc tiếng Việt và chưa kết nối được mạng. Thầy cô bật mạng rồi bấm Đọc to lại.');
    }
  }

  static String _homNay() {
    final d = DateTime.now();
    return '${d.year}-${d.month}-${d.day}';
  }

  static Future<void> _ghiLuot(String cheDo, int conLai) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('luot_${_homNay()}_$cheDo', conLai);
  }

  /// Số lượt còn lại hôm nay theo lần gọi gần nhất; chưa dùng lần nào thì trả về [macDinh].
  /// [loai] nhận cả tên trong app ('nhan_xet') lẫn tên chế độ máy chủ ('nhanxet').
  static Future<int> luotConLai(String loai, int macDinh) async {
    final p = await SharedPreferences.getInstance();
    return p.getInt('luot_${_homNay()}_${_cheDo[loai] ?? loai}') ?? macDinh;
  }

  /// Hỏi máy chủ số lượt còn lại hôm nay. Lỗi mạng thì trả về null.
  static Future<LuotHomNay?> layLuot() async {
    if (diaChiMayChu.isEmpty) return null;
    try {
      final res = await http
          .get(Uri.parse('$diaChiMayChu/v1/quota?device_id=${await maMay()}'))
          .timeout(const Duration(seconds: 15));
      final j = jsonDecode(utf8.decode(res.bodyBytes));
      if (j is! Map || j['ok'] != true || j['left'] is! Map) return null;
      final thuong = j['bonus'] is int ? j['bonus'] as int : 0;
      final con = <String, int>{};
      (j['left'] as Map).forEach((k, v) {
        if (v is int) con['$k'] = v;
      });
      for (final e in con.entries) {
        await _ghiLuot(e.key, e.value + thuong);
      }
      return LuotHomNay(con, thuong);
    } catch (_) {
      return null;
    }
  }

  /// Báo cáo nội dung AI không phù hợp (Google Play bắt buộc có).
  static Future<bool> baoCao({
    required String cauHoi,
    required String traLoi,
    required String lyDo,
    String loai = 'hoi',
  }) async {
    if (diaChiMayChu.isEmpty) return true;
    try {
      final j = await _post('/v1/report', {
        'device_id': await maMay(),
        'mode': _cheDo[loai] ?? loai,
        'input': cauHoi,
        'output': traLoi,
        'reason': lyDo,
      }, giay: 20);
      return j['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Xóa bộ đếm lượt và báo cáo của máy này trên máy chủ. Trả về lời nhắn để hiện cho thầy cô.
  static Future<String> xoaDuLieuMayChu() async {
    if (diaChiMayChu.isEmpty) return 'Chưa nối máy chủ, không có dữ liệu để xóa.';
    try {
      final j = await _post('/v1/delete', {'device_id': await maMay()}, giay: 20);
      if (j['ok'] == true) {
        final p = await SharedPreferences.getInstance();
        for (final k in p.getKeys().where((k) => k.startsWith('luot_')).toList()) {
          await p.remove(k);
        }
      }
      return (j['message'] as String?) ?? 'Chưa xóa được, thầy cô thử lại sau.';
    } catch (_) {
      return 'Không kết nối được. Thầy cô kiểm tra mạng rồi thử lại.';
    }
  }
}
