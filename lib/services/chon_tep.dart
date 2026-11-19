import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;

import 'van_phong_cu.dart';

/// Tệp thầy cô tải lên, đã chuyển sẵn sang dạng gửi được cho AI.
class TepTaiLen {
  final String ten;

  /// Chữ đọc được từ tệp Word (.docx, .doc) hoặc .txt
  final String? chu;

  /// Ảnh JPEG mã base64 (đã thu nhỏ cạnh dài tối đa 1568 điểm ảnh)
  final String? anh;

  /// Tệp PDF mã base64 (máy chủ gửi thẳng cho AI đọc)
  final String? pdf;

  const TepTaiLen(this.ten, {this.chu, this.anh, this.pdf});
}

const duoiAnh = ['jpg', 'jpeg', 'png', 'webp', 'heic'];
const duoiChu = ['docx', 'doc', 'txt'];
const gioiHanPdf = 4 * 1024 * 1024; // 4 MB

/// Mở bộ chọn tệp. [cho] là các đuôi được chọn, ví dụ ['pdf', 'docx', 'txt', ...duoiAnh].
/// Trả về null khi thầy cô không chọn; ném [FormatException] với lời nhắn tiếng Việt khi tệp không đọc được.
Future<TepTaiLen?> chonTep(List<String> cho) async {
  final kq = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: cho);
  final f = kq?.files.single;
  if (f == null || f.path == null) return null;
  final ten = f.name;
  final duoi = ten.split('.').last.toLowerCase();
  final byte = await File(f.path!).readAsBytes();

  if (duoi == 'pdf') {
    if (byte.length > gioiHanPdf) throw const FormatException('Tệp PDF lớn quá (tối đa 4 MB). Thầy cô tách bớt trang rồi thử lại.');
    return TepTaiLen(ten, pdf: base64Encode(byte));
  }
  if (duoi == 'txt') return TepTaiLen(ten, chu: utf8.decode(byte, allowMalformed: true).trim());
  if (duoi == 'docx') {
    final chu = docChuDocx(byte);
    if (chu.isEmpty) throw const FormatException('Tệp Word không có chữ đọc được.');
    return TepTaiLen(ten, chu: chu);
  }
  if (duoi == 'doc') {
    final String chu;
    try {
      chu = docChuDoc(byte);
    } on LoiTepCu catch (e) {
      throw FormatException(e.message);
    }
    if (chu.isEmpty) throw const FormatException('Tệp Word không có chữ đọc được.');
    return TepTaiLen(ten, chu: chu);
  }
  if (duoiAnh.contains(duoi)) {
    final anh = img.decodeImage(byte);
    if (anh == null) throw const FormatException('Không mở được ảnh này.');
    final nho = (anh.width > 1568 || anh.height > 1568)
        ? img.copyResize(anh, width: anh.width >= anh.height ? 1568 : null, height: anh.height > anh.width ? 1568 : null)
        : anh;
    return TepTaiLen(ten, anh: base64Encode(img.encodeJpg(nho, quality: 80)));
  }
  throw const FormatException('Loại tệp này chưa hỗ trợ.');
}

/// Lấy chữ từ tệp Word .docx (tệp nén chứa word/document.xml), giữ xuống dòng theo đoạn.
String docChuDocx(List<int> byte) {
  final kho = ZipDecoder().decodeBytes(byte);
  final f = kho.findFile('word/document.xml');
  if (f == null) return '';
  final xml = utf8.decode(f.content as List<int>, allowMalformed: true);
  final b = StringBuffer();
  for (final p in RegExp(r'<w:p[ >].*?</w:p>', dotAll: true).allMatches(xml)) {
    final doan = p.group(0)!.replaceAll(RegExp(r'<w:tab/>'), '\t').replaceAll(RegExp(r'<w:br/>'), '\n');
    final chu = RegExp(r'<w:t(?: [^>]*)?>(.*?)</w:t>', dotAll: true).allMatches(doan).map((m) => m.group(1)!).join();
    b.writeln(chu
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&amp;', '&'));
  }
  return b.toString().replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
}
