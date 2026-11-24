import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';

/// Ảnh, tệp PDF có sẵn trong máy thành các trang ảnh JPEG để gộp vào PDF hoặc lưu làm minh chứng
/// (thầy cô báo 24/11/2026: Quét giấy tờ, Thêm minh chứng chỉ chụp được, chưa đưa tệp có sẵn lên được).

const duoiTrang = ['pdf', 'jpg', 'jpeg', 'png', 'heic', 'heif', 'webp'];

/// Số trang tối đa lấy từ một tệp PDF (tệp dài quá thì máy chậm, tệp xuất ra nặng).
const toiDaTrangPdf = 30;

Uint8List? _jpegTuTep((String, int) v) {
  final (duong, toiDa) = v;
  final goc = img.decodeImage(File(duong).readAsBytesSync());
  if (goc == null) return null;
  var a = img.bakeOrientation(goc);
  if (a.width > toiDa || a.height > toiDa) {
    a = a.width >= a.height ? img.copyResize(a, width: toiDa) : img.copyResize(a, height: toiDa);
  }
  return img.encodeJpg(a, quality: 85);
}

Uint8List _jpegTuRgba((Uint8List, int, int) v) {
  final (b, w, h) = v;
  final a = img.Image.fromBytes(
    width: w,
    height: h,
    bytes: b.buffer,
    bytesOffset: b.offsetInBytes,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );
  return img.encodeJpg(a, quality: 85);
}

Future<String> _ghiTam(Uint8List b, String duoi) async {
  final f = File('${(await getTemporaryDirectory()).path}/trang_${DateTime.now().microsecondsSinceEpoch}.$duoi');
  await f.writeAsBytes(b, flush: true);
  return f.path;
}

/// Đổi một ảnh bất kỳ (JPEG, PNG, WebP, HEIC của iPhone…) thành JPEG cạnh dài tối đa [toiDa] điểm ảnh.
/// Trả về đường dẫn tệp JPEG tạm. Ném [FormatException] khi không mở được ảnh.
Future<String> anhSangJpeg(String duong, {int toiDa = 2200}) async {
  Uint8List? jpg;
  try {
    jpg = await compute(_jpegTuTep, (duong, toiDa));
  } catch (_) {}
  if (jpg == null) {
    // Ảnh HEIC của iPhone và dạng thư viện ảnh chưa đọc được: nhờ bộ giải mã của máy.
    try {
      final buf = await ui.ImmutableBuffer.fromUint8List(await File(duong).readAsBytes());
      final mo = await ui.ImageDescriptor.encoded(buf);
      final tiLe = math.min(1.0, toiDa / math.max(mo.width, mo.height));
      final codec = await mo.instantiateCodec(
        targetWidth: math.max(1, (mo.width * tiLe).round()),
        targetHeight: math.max(1, (mo.height * tiLe).round()),
      );
      final anh = (await codec.getNextFrame()).image;
      final rgba = await anh.toByteData(format: ui.ImageByteFormat.rawRgba);
      final w = anh.width;
      final h = anh.height;
      anh.dispose();
      codec.dispose();
      mo.dispose();
      buf.dispose();
      if (rgba != null) jpg = await compute(_jpegTuRgba, (rgba.buffer.asUint8List(rgba.offsetInBytes, rgba.lengthInBytes), w, h));
    } catch (_) {}
  }
  if (jpg == null) throw const FormatException('Không mở được ảnh này.');
  return _ghiTam(jpg, 'jpg');
}

/// Mỗi trang của tệp PDF thành một ảnh (150 dpi, đủ rõ để in, đọc chữ). Tối đa [toiDaTrangPdf] trang.
Future<List<String>> pdfSangAnh(Uint8List pdf) async {
  final ds = <String>[];
  await for (final p in Printing.raster(pdf, dpi: 150)) {
    ds.add(await _ghiTam(await p.toPng(), 'png'));
    if (ds.length >= toiDaTrangPdf) break;
  }
  if (ds.isEmpty) throw const FormatException('Tệp PDF không có trang nào đọc được.');
  return ds;
}

/// Kết quả chọn tệp: các trang ảnh lấy được và lời nhắn cho thầy cô (tệp bỏ qua, trang bị cắt bớt).
class TrangTuTep {
  final List<String> trang;
  final String? loiNhan;
  const TrangTuTep(this.trang, [this.loiNhan]);
}

/// Mở bộ chọn tệp của máy (ứng dụng Tệp, Drive, Tải về…), chọn được nhiều tệp PDF, ảnh cùng lúc.
/// Trả về null khi thầy cô không chọn gì.
Future<TrangTuTep?> chonTrangTuTep() async {
  final kq = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: duoiTrang, allowMultiple: true);
  if (kq == null || kq.files.isEmpty) return null;
  final trang = <String>[];
  final boQua = <String>[];
  var catBot = false;
  for (final f in kq.files) {
    final p = f.path;
    if (p == null) {
      boQua.add(f.name);
      continue;
    }
    try {
      if (f.name.toLowerCase().endsWith('.pdf')) {
        final ds = await pdfSangAnh(await File(p).readAsBytes());
        if (ds.length >= toiDaTrangPdf) catBot = true;
        trang.addAll(ds);
      } else {
        trang.add(await anhSangJpeg(p));
      }
    } catch (_) {
      boQua.add(f.name);
    }
  }
  final nhan = [
    if (boQua.isNotEmpty) 'Chưa mở được: ${boQua.join(', ')}.',
    if (catBot) 'Tệp PDF dài, app lấy $toiDaTrangPdf trang đầu.',
  ];
  return TrangTuTep(trang, nhan.isEmpty ? null : nhan.join(' '));
}
