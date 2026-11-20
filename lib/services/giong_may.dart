import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

/// Giọng đọc tiếng Việt chạy ngay trên máy (sherpa-onnx, giọng Piper), không cần mạng, không giới hạn.
/// Phần giọng (khoảng 21 MB) được tải về một lần ở lần đầu cần dùng, rồi lưu trong máy.
class GiongMay {
  // Thử 19/11/2026 trên máy GitHub: nạp 0,9 giây, tạo 0,7 giây cho 7 giây âm thanh.
  static const tenGiong = 'vits-piper-vi_VN-vais1000-medium-int8';
  // Bản nén gzip đặt ở mục Releases của kho app (giải nén nhanh); bản gốc bzip2 của sherpa-onnx giải nén trên điện thoại quá chậm
  static const _diaChi = 'https://github.com/toannguyen210579-web/tro-ly-so-giao-vien/releases/download/giong-doc-1/$tenGiong.tar.gz';
  static const coMB = 21;

  static Future<Directory> _thuMuc() async => Directory('${(await getApplicationSupportDirectory()).path}/giong_doc');

  static Future<String?> _duongMoHinh() async {
    final d = Directory('${(await _thuMuc()).path}/$tenGiong');
    if (!await d.exists()) return null;
    final onnx = d.listSync().whereType<File>().where((f) => f.path.endsWith('.onnx')).toList();
    if (onnx.isEmpty || !File('${d.path}/tokens.txt').existsSync() || !Directory('${d.path}/espeak-ng-data').existsSync()) {
      return null;
    }
    return d.path;
  }

  static Future<bool> sanSang() async => (await _duongMoHinh()) != null;

  static Future<void>? _dangTai;

  /// Tải phần giọng về (gọi nhiều lần vẫn chỉ tải một lần). [tienDo] nhận giá trị 0–1.
  static Future<void> taiVe({void Function(double)? tienDo}) {
    return _dangTai ??= _tai(tienDo).whenComplete(() => _dangTai = null);
  }

  static Future<void> _tai(void Function(double)? tienDo) async {
    if (await sanSang()) return;
    final goc = await _thuMuc();
    await goc.create(recursive: true);
    final tam = File('${goc.path}/tai.tar.gz');
    final kh = http.Client();
    try {
      final res = await kh.send(http.Request('GET', Uri.parse(_diaChi))).timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) throw const HttpException('tải giọng lỗi');
      final tong = res.contentLength ?? coMB * 1024 * 1024;
      var da = 0;
      final ghi = tam.openWrite();
      await for (final c in res.stream.timeout(const Duration(seconds: 30))) {
        ghi.add(c);
        da += c.length;
        tienDo?.call((da / tong).clamp(0, 0.95).toDouble());
      }
      await ghi.close();
    } finally {
      kh.close();
    }
    // Giải nén ở luồng riêng để màn hình không bị đứng
    final dich = goc.path;
    final nguon = tam.path;
    await Isolate.run(() {
      final tar = gzip.decode(File(nguon).readAsBytesSync()); // giải nén gzip bằng thư viện có sẵn của máy, nhanh
      for (final f in TarDecoder().decodeBytes(tar).files) {
        final p = '$dich/${f.name}';
        if (f.isFile) {
          File(p)
            ..createSync(recursive: true)
            ..writeAsBytesSync(f.content as List<int>);
        } else {
          Directory(p).createSync(recursive: true);
        }
      }
    });
    await tam.delete();
    tienDo?.call(1);
    if (!await sanSang()) throw const FileSystemException('Giải nén giọng đọc lỗi');
  }

  /// Đọc [chu] thành tệp WAV. [toc]: 1 là bình thường. Chạy ở luồng riêng để nút Dừng vẫn bấm được.
  static Future<File> tao(String chu, {double toc = 1, required String duongRa}) async {
    final d = await _duongMoHinh();
    if (d == null) throw StateError('Chưa có giọng đọc');
    await Isolate.run(() {
      sherpa.initBindings();
      final onnx = Directory(d).listSync().whereType<File>().firstWhere((f) => f.path.endsWith('.onnx')).path;
      final tts = sherpa.OfflineTts(sherpa.OfflineTtsConfig(
        model: sherpa.OfflineTtsModelConfig(
          vits: sherpa.OfflineTtsVitsModelConfig(model: onnx, tokens: '$d/tokens.txt', dataDir: '$d/espeak-ng-data'),
          numThreads: 2,
          debug: false,
        ),
      ));
      try {
        final a = tts.generate(text: chu, sid: 0, speed: toc.clamp(0.5, 2.0).toDouble());
        if (a.samples.isEmpty) throw StateError('Không tạo được tiếng');
        sherpa.writeWave(filename: duongRa, samples: a.samples, sampleRate: a.sampleRate);
      } finally {
        tts.free();
      }
    });
    return File(duongRa);
  }
}
