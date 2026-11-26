import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

import '../data/dich.dart';

/// Dịch ngay trên máy bằng ML Kit của Google (không cần mạng, không tốn lượt), chỉ dùng làm phương án phòng hờ
/// cho đoạn chữ ngắn khi mất mạng, cặp Anh ⇄ Việt (chốt 24/11/2026). Chất lượng kém hơn AI, dịch từng câu,
/// nên kết quả luôn ghi "Dịch bởi Google" theo quy định sử dụng của ML Kit.
/// Gói ngôn ngữ (Anh, Việt) chỉ tải khi dùng lần đầu, cần mạng ở lần tải đó.
class DichTrenMay {
  /// Ghi chú bắt buộc dưới bản dịch trên máy.
  static const ghiNguon = 'Dịch bởi Google (dịch trên máy, không cần mạng)';

  /// Đoạn chữ ngắn tối đa dịch trên máy.
  static const toiDaKyTu = 2000;

  /// Dịch được trên máy khi: chữ ngắn, đích là Tiếng Việt hoặc Tiếng Anh.
  static bool dichDuoc(String chu, String den) =>
      chu.trim().isNotEmpty && chu.length <= toiDaKyTu && (den == 'Tiếng Việt' || den == 'Tiếng Anh');

  /// Tải sẵn gói Anh, Việt khi đang dùng wifi (mở tiện ích Dịch lần đầu), để lúc mất mạng vẫn dịch được đoạn ngắn.
  static Future<void> taiSanNeuCan() async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) return; // phép thử trên máy tính: bỏ qua
    try {
      final r = await Connectivity().checkConnectivity();
      if (!r.contains(ConnectivityResult.wifi) && !r.contains(ConnectivityResult.ethernet)) return;
      final ql = OnDeviceTranslatorModelManager();
      for (final l in [TranslateLanguage.english, TranslateLanguage.vietnamese]) {
        if (!await ql.isModelDownloaded(l.bcpCode)) await ql.downloadModel(l.bcpCode);
      }
    } catch (_) {}
  }

  /// Trả về bản dịch, hoặc null khi gói ngôn ngữ chưa có trên máy và không tải được.
  static Future<String?> dich(String chu, String den) async {
    final nguon = den == 'Tiếng Anh' || coDauTiengViet(chu) ? TranslateLanguage.vietnamese : TranslateLanguage.english;
    final dich = den == 'Tiếng Anh' ? TranslateLanguage.english : TranslateLanguage.vietnamese;
    if (nguon == dich) return chu;
    final ql = OnDeviceTranslatorModelManager();
    try {
      for (final l in [nguon, dich]) {
        if (!await ql.isModelDownloaded(l.bcpCode)) {
          if (!await ql.downloadModel(l.bcpCode)) return null;
        }
      }
    } catch (_) {
      return null;
    }
    final may = OnDeviceTranslator(sourceLanguage: nguon, targetLanguage: dich);
    try {
      final kq = <String>[];
      for (final d in tachDoanDich(chu)) {
        kq.add(await may.translateText(d));
      }
      return kq.join('\n\n');
    } catch (_) {
      return null;
    } finally {
      await may.close();
    }
  }
}
