import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Địa chỉ máy chủ trung gian (Cloudflare Worker).
/// Để trống thì app chạy chế độ thử: trả lời giả lập, không gọi AI thật.
/// Khóa API Claude KHÔNG bao giờ đặt trong app, chỉ đặt trên máy chủ.
const diaChiMayChu = '';

class KetQuaTroLy {
  final String? traLoi;
  final String? loi;
  final int? conLai;
  const KetQuaTroLy({this.traLoi, this.loi, this.conLai});
}

class TroLyApi {
  static Future<String> _maMay() async {
    final p = await SharedPreferences.getInstance();
    var ma = p.getString('ma_may');
    if (ma == null) {
      final r = Random.secure();
      ma = List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
      await p.setString('ma_may', ma);
    }
    return ma;
  }

  /// loai: 'hoi' (Hỏi Trợ lý), 'nhan_xet' (viết nhận xét), 'tin_ph' (soạn tin phụ huynh).
  /// anh: ảnh JPEG mã base64 (tối đa 4 ảnh), dùng cho 'giai_de' và 'de_tuong_tu'.
  static Future<KetQuaTroLy> hoi(String noiDung, {String loai = 'hoi', List<String> anh = const []}) async {
    if (diaChiMayChu.isEmpty) {
      await Future.delayed(const Duration(milliseconds: 600));
      return const KetQuaTroLy(
        traLoi: '(Chế độ thử) Đây là câu trả lời mẫu. Khi nối máy chủ, Trợ lý sẽ trả lời thật '
            'và ghi rõ văn bản làm căn cứ.',
        conLai: 4,
      );
    }
    try {
      final res = await http
          .post(
            Uri.parse('$diaChiMayChu/hoi'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'may': await _maMay(), 'loai': loai, 'noi_dung': noiDung, if (anh.isNotEmpty) 'anh': anh}),
          )
          .timeout(Duration(seconds: anh.isEmpty ? 60 : 120));
      final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      if (j['con_lai'] is int) await _ghiLuot(loai, j['con_lai'] as int);
      return KetQuaTroLy(
        traLoi: j['tra_loi'] as String?,
        loi: j['loi'] as String?,
        conLai: j['con_lai'] as int?,
      );
    } catch (_) {
      return const KetQuaTroLy(loi: 'Không kết nối được. Thầy cô kiểm tra mạng rồi thử lại.');
    }
  }

  static String _homNay() {
    final d = DateTime.now();
    return '${d.year}-${d.month}-${d.day}';
  }

  static Future<void> _ghiLuot(String loai, int conLai) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('luot_${_homNay()}_$loai', conLai);
  }

  /// Số lượt còn lại hôm nay theo lần gọi gần nhất; chưa dùng lần nào thì trả về [macDinh].
  static Future<int> luotConLai(String loai, int macDinh) async {
    final p = await SharedPreferences.getInstance();
    return p.getInt('luot_${_homNay()}_$loai') ?? macDinh;
  }

  /// Báo cáo nội dung AI không phù hợp (Google Play bắt buộc có).
  static Future<bool> baoCao({required String cauHoi, required String traLoi, required String lyDo}) async {
    if (diaChiMayChu.isEmpty) return true;
    try {
      final res = await http.post(
        Uri.parse('$diaChiMayChu/bao-cao'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'may': await _maMay(), 'cau_hoi': cauHoi, 'tra_loi': traLoi, 'ly_do': lyDo}),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
