import 'dart:math';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/gio_the.dart';
import '../quoc_te/quoc_te.dart' as qt;

/// Bộ thẻ Giơ thẻ: mỗi thẻ một mã QR, bốn cạnh ghi A, B, C, D; 2 thẻ một trang A4.
/// [ten]: tên học sinh theo thứ tự lớp (thẻ số mấy ghi tên em số đó), không có thì chỉ ghi số.
/// Tách khỏi màn hình để chạy thử trên máy tính (phép thử test/gio_the_test.dart).
Future<Uint8List> taoPdfBoThe(int n, List<String> ten, {pw.ThemeData? theme}) {
  final doc = pw.Document(theme: theme);
  pw.Widget chu(String c, double goc) => pw.Transform.rotate(
        angle: goc,
        child: pw.Text(c, style: pw.TextStyle(fontSize: 34, fontWeight: pw.FontWeight.bold)),
      );
  pw.Widget the(int so) => pw.Container(
        padding: const pw.EdgeInsets.all(10),
        child: pw.Column(children: [
          chu('A', 0),
          pw.Expanded(
            child: pw.Row(children: [
              chu('D', pi / 2),
              pw.Expanded(
                child: pw.Center(
                  child: pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: maThe(so),
                    width: 90 * PdfPageFormat.mm,
                    height: 90 * PdfPageFormat.mm,
                    drawText: false,
                  ),
                ),
              ),
              chu('B', -pi / 2),
            ]),
          ),
          chu('C', pi),
          pw.SizedBox(height: 4),
          pw.Text('${qt.laQuocTe ? '#' : 'Số '}$so${so <= ten.length ? ' · ${ten[so - 1]}' : ''}', style: const pw.TextStyle(fontSize: 10)),
        ]),
      );
  for (var i = 1; i <= n; i += 2) {
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(12 * PdfPageFormat.mm),
      build: (_) => pw.Column(children: [
        pw.Expanded(child: the(i)),
        pw.Divider(borderStyle: pw.BorderStyle.dashed),
        pw.Expanded(child: i + 1 <= n ? the(i + 1) : pw.SizedBox()),
      ]),
    ));
  }
  return doc.save();
}
