import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Lưu dữ liệu ngay trên máy (không gửi đi đâu).
class LuuTru {
  static Future<List<Map<String, dynamic>>> docDanhSach(String khoa) async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(khoa);
    if (s == null) return [];
    final ds = jsonDecode(s) as List<dynamic>;
    return ds.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<void> ghiDanhSach(String khoa, List<Map<String, dynamic>> ds) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(khoa, jsonEncode(ds));
  }
}
