import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../services/tro_ly_api.dart';

/// Địa chỉ trang Facebook của kênh (để Hỏi Trợ lý hiện nút mở trang). Để trống thì không hiện nút.
const trangKenhFacebook = 'https://www.facebook.com/profile.php?id=61596048104555';

/// Một tin từ kênh Việt Nam Tiêu Điểm.
class TinKenh {
  final String id;
  final DateTime ngay;
  final String tit;
  final String tomTat;

  /// "asset:assets/tin/…jpg" (ảnh đóng gói sẵn) hoặc đường dẫn https.
  final String anhBia;

  /// Đường dẫn bài đăng trên Facebook (để dồn lượt xem cho kênh).
  final String? linkFacebook;

  /// Đường dẫn tệp mp4 (Cloudflare R2) để phát ngay trong app.
  final String? video;

  /// Tin tức lấy từ báo, cổng thông tin (không phải clip của kênh): tên nguồn và đường dẫn bài gốc.
  final String? nguon;
  final String? link;

  const TinKenh({
    required this.id,
    required this.ngay,
    required this.tit,
    required this.tomTat,
    required this.anhBia,
    this.linkFacebook,
    this.video,
    this.nguon,
    this.link,
  });

  factory TinKenh.fromJson(Map<String, dynamic> j) => TinKenh(
        id: j['id'] as String,
        ngay: DateTime.tryParse(j['ngay'] as String? ?? '') ?? DateTime.now(),
        tit: j['tit'] as String? ?? '',
        tomTat: j['tom_tat'] as String? ?? '',
        anhBia: j['anh_bia'] as String? ?? '',
        linkFacebook: (j['link_facebook'] as String?)?.trim().isEmpty ?? true ? null : j['link_facebook'] as String,
        video: (j['video'] as String?)?.trim().isEmpty ?? true ? null : j['video'] as String,
        nguon: (j['nguon'] as String?)?.trim().isEmpty ?? true ? null : j['nguon'] as String,
        link: (j['link'] as String?)?.trim().isEmpty ?? true ? null : j['link'] as String,
      );

  /// Tin từ báo (có nguồn), không phải clip của kênh
  bool get laTinBao => nguon != null;

  bool get anhDongGoi => anhBia.startsWith('asset:');
  String get duongDanAnh => anhDongGoi ? anhBia.substring(6) : anhBia;
}

/// Đọc danh sách tin: từ máy chủ khi đã nối, lưu lại để xem khi mất mạng;
/// chưa nối máy chủ thì dùng tin mẫu đóng gói trong app.
class NguonTin {
  static const _khoaLuu = 'tin_kenh_luu';
  static const _khoaThich = 'tin_kenh_thich';

  static List<TinKenh> _doc(String s) {
    final ds = (jsonDecode(s) as List<dynamic>)
        .map((e) => TinKenh.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList()
      ..sort((a, b) => b.ngay.compareTo(a.ngay));
    return ds;
  }

  static Future<List<TinKenh>> tai() async {
    final p = await SharedPreferences.getInstance();
    if (diaChiMayChu.isNotEmpty) {
      try {
        final res = await http.get(Uri.parse('$diaChiMayChu/tin')).timeout(const Duration(seconds: 15));
        if (res.statusCode == 200) {
          final s = utf8.decode(res.bodyBytes);
          final ds = _doc(s);
          await p.setString(_khoaLuu, s);
          return ds;
        }
      } catch (_) {}
      final luu = p.getString(_khoaLuu);
      if (luu != null) return _doc(luu);
    }
    return _doc(await rootBundle.loadString('assets/tin/tin_mau.json'));
  }

  static Future<Set<String>> daThich() async {
    final p = await SharedPreferences.getInstance();
    return (p.getStringList(_khoaThich) ?? const []).toSet();
  }

  static Future<void> datThich(String id, bool thich) async {
    final p = await SharedPreferences.getInstance();
    final s = (p.getStringList(_khoaThich) ?? const []).toSet();
    thich ? s.add(id) : s.remove(id);
    await p.setStringList(_khoaThich, s.toList());
  }
}
