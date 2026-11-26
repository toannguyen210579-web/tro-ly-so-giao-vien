import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/trinh_chieu.dart';

/// Bản PDF của bài trình chiếu: mỗi trang chiếu một trang 16:9 (960 x 540 điểm), bố cục giống hệt tệp PowerPoint
/// (tep_pptx.dart), phông Be Vietnam Pro (giấy phép SIL OFL, đóng gói trong app) để chiếu, in, gửi Zalo đều đọc được.

const _w = 960.0;
const _h = 540.0;

/// Phông Be Vietnam Pro cho PDF bài trình chiếu.
class PhongTrinhChieu {
  static pw.ThemeData? _theme;

  static Future<pw.ThemeData> theme() async {
    if (_theme != null) return _theme!;
    Future<pw.Font> tai(String ten) async => pw.Font.ttf(await rootBundle.load('assets/fonts/$ten'));
    _theme = pw.ThemeData.withFont(base: await tai('BeVietnamPro-Regular.ttf'), bold: await tai('BeVietnamPro-Bold.ttf'));
    return _theme!;
  }
}

PdfColor _mau(int c) => PdfColor.fromInt(0xFF000000 | c);

/// Khối chữ có bề rộng cố định, tự thu nhỏ khi dài quá khung (không tràn ra ngoài trang).
pw.Widget _vua(double rong, pw.Widget con, {pw.Alignment canh = pw.Alignment.topLeft}) => pw.FittedBox(
      fit: pw.BoxFit.scaleDown,
      alignment: canh,
      child: pw.SizedBox(width: rong, child: con),
    );

pw.Widget _bia(TrangChieu tr, MauTrinhChieu m) {
  final phu = tr.y.where((s) => s.isNotEmpty).join(' · ');
  return pw.Stack(children: [
    pw.Container(width: _w, height: _h, color: _mau(m.chinh)),
    pw.Positioned(left: 0, top: _h * 0.70, child: pw.Container(width: _w, height: _h * 0.30, color: _mau(m.dam))),
    pw.Positioned(
      left: 54,
      top: 126,
      child: pw.SizedBox(
        width: _w - 108,
        height: 189,
        child: _vua(
          _w - 108,
          pw.Text(tr.tieuDe, style: pw.TextStyle(fontSize: 44, fontWeight: pw.FontWeight.bold, color: PdfColors.white, lineSpacing: 4)),
          canh: pw.Alignment.bottomLeft,
        ),
      ),
    ),
    if (phu.isNotEmpty)
      pw.Positioned(
        left: 54,
        top: _h * 0.70 + 24,
        child: pw.SizedBox(
          width: _w - 108,
          height: 94,
          child: _vua(_w - 108, pw.Text(phu, style: const pw.TextStyle(fontSize: 24, color: PdfColors.white))),
        ),
      ),
  ]);
}

pw.Widget _noiDung(TrangChieu tr, int so, int tong, String tenBai, MauTrinhChieu m) {
  final co = coChuNoiDung(tr.y) / 100;
  final nhan = tr.hoatDong.trim();
  const chu = PdfColor.fromInt(0xFF14233A);
  return pw.Column(children: [
    pw.Container(
      width: _w,
      height: 108,
      color: _mau(m.chinh),
      padding: const pw.EdgeInsets.symmetric(horizontal: 43),
      alignment: pw.Alignment.centerLeft,
      child: _vua(
        _w - 86,
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, mainAxisSize: pw.MainAxisSize.min, children: [
          if (nhan.isNotEmpty)
            pw.Text(nhan.toUpperCase(), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: _mau(m.nhat))),
          pw.Text(tr.tieuDe, style: pw.TextStyle(fontSize: 32, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
        ]),
        canh: pw.Alignment.centerLeft,
      ),
    ),
    pw.Container(width: _w, height: 6, color: _mau(m.nhat)),
    pw.Expanded(
      child: pw.Padding(
        padding: const pw.EdgeInsets.fromLTRB(43, 24, 43, 0),
        child: _vua(
          _w - 86,
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, mainAxisSize: pw.MainAxisSize.min, children: [
            for (final y in tr.y)
              pw.Padding(
                padding: pw.EdgeInsets.only(bottom: co * 0.45),
                child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.SizedBox(width: 36, child: pw.Text('•', style: pw.TextStyle(fontSize: co, color: chu))),
                  pw.Expanded(child: pw.Text(y, style: pw.TextStyle(fontSize: co, color: chu, lineSpacing: co * 0.18))),
                ]),
              ),
          ]),
        ),
      ),
    ),
    pw.Container(
      width: _w,
      height: 36,
      padding: const pw.EdgeInsets.symmetric(horizontal: 43),
      alignment: pw.Alignment.centerRight,
      child: pw.Text('$tenBai   ·   $so/$tong', style: const pw.TextStyle(fontSize: 12, color: PdfColor.fromInt(0xFF8A94A6)), maxLines: 1),
    ),
  ]);
}

/// Tạo tệp PDF bài trình chiếu. [theme] để thử (mặc định phông Be Vietnam Pro trong app).
Future<Uint8List> taoPdfTrinhChieu(BaiChieu bai, MauTrinhChieu mau, {pw.ThemeData? theme}) async {
  final doc = pw.Document(theme: theme ?? await PhongTrinhChieu.theme(), title: bai.tieuDe, creator: 'Trợ lý số Giáo viên');
  final n = bai.trang.length;
  for (var i = 0; i < n; i++) {
    final tr = bai.trang[i];
    doc.addPage(pw.Page(
      pageFormat: const PdfPageFormat(_w, _h),
      margin: pw.EdgeInsets.zero,
      build: (_) => tr.laBia ? _bia(tr, mau) : _noiDung(tr, i + 1, n, bai.tieuDe, mau),
    ));
  }
  return doc.save();
}
