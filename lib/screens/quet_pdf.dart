import 'dart:io';

import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../main.dart';

/// Quét giấy tờ bằng máy ảnh (tự nhận mép giấy) rồi gộp thành một tệp PDF.
/// Chạy hoàn toàn trên máy, không cần mạng.
class QuetPdf extends StatefulWidget {
  const QuetPdf({super.key});

  @override
  State<QuetPdf> createState() => _QuetPdfState();
}

class _QuetPdfState extends State<QuetPdf> {
  final _trang = <String>[];
  List<File> _daLuu = [];
  bool _dangTao = false;

  @override
  void initState() {
    super.initState();
    _taiDaLuu();
  }

  Future<Directory> _thuMuc() async {
    final goc = await getApplicationDocumentsDirectory();
    final d = Directory('${goc.path}/quet_pdf');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  Future<void> _taiDaLuu() async {
    final d = await _thuMuc();
    final ds = d.listSync().whereType<File>().where((f) => f.path.endsWith('.pdf')).toList()
      ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    if (mounted) setState(() => _daLuu = ds);
  }

  Future<void> _quet() async {
    try {
      final anh = await CunningDocumentScanner.getPictures();
      if (anh == null || anh.isEmpty) return;
      setState(() => _trang.addAll(anh));
    } catch (_) {
      _bao('Chưa mở được máy ảnh. Thầy cô cho app quyền dùng máy ảnh trong Cài đặt.');
    }
  }

  Future<void> _taoPdf() async {
    if (_trang.isEmpty) return;
    setState(() => _dangTao = true);
    final doc = pw.Document();
    for (final p in _trang) {
      final anh = pw.MemoryImage(await File(p).readAsBytes());
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Center(child: pw.Image(anh, fit: pw.BoxFit.contain)),
        ),
      );
    }
    final now = DateTime.now();
    String hai(int n) => n.toString().padLeft(2, '0');
    final ten = 'Quet_${now.year}${hai(now.month)}${hai(now.day)}_${hai(now.hour)}${hai(now.minute)}${hai(now.second)}.pdf';
    final f = File('${(await _thuMuc()).path}/$ten');
    await f.writeAsBytes(await doc.save());
    if (!mounted) return;
    setState(() {
      _dangTao = false;
      _trang.clear();
    });
    await _taiDaLuu();
    _bao('Đã lưu $ten');
    await Share.shareXFiles([XFile(f.path)]);
  }

  Future<void> _xoa(File f) async {
    await f.delete();
    await _taiDaLuu();
  }

  void _bao(String s) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quét PDF')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          FilledButton.icon(
            onPressed: _quet,
            icon: const Icon(Icons.document_scanner_outlined),
            label: Text(_trang.isEmpty ? 'Quét giấy tờ' : 'Quét thêm trang'),
          ),
          const SizedBox(height: 8),
          const Text(
            'Đặt giấy trên nền tối, app tự nhận mép giấy và làm phẳng trang.',
            style: TextStyle(fontSize: 12.5, color: MauApp.chuPhu),
          ),
          if (_trang.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('${_trang.length} trang đã quét', style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            SizedBox(
              height: 140,
              child: ReorderableListView(
                scrollDirection: Axis.horizontal,
                onReorder: (a, b) => setState(() {
                  if (b > a) b--;
                  _trang.insert(b, _trang.removeAt(a));
                }),
                children: [
                  for (var i = 0; i < _trang.length; i++)
                    Padding(
                      key: ValueKey(_trang[i]),
                      padding: const EdgeInsets.only(right: 8),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.file(File(_trang[i]), height: 140, width: 100, fit: BoxFit.cover),
                          ),
                          Positioned(
                            right: 0,
                            top: 0,
                            child: IconButton(
                              tooltip: 'Bỏ trang này',
                              onPressed: () => setState(() => _trang.removeAt(i)),
                              icon: const Icon(Icons.cancel, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            const Text('Giữ và kéo để đổi thứ tự trang.', style: TextStyle(fontSize: 12, color: MauApp.chuPhu)),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _dangTao ? null : _taoPdf,
              icon: const Icon(Icons.picture_as_pdf),
              label: Text(_dangTao ? 'Đang tạo…' : 'Gộp thành PDF và gửi'),
            ),
          ],
          const SizedBox(height: 24),
          const Text('Tệp PDF đã lưu', style: TextStyle(fontWeight: FontWeight.w800)),
          if (_daLuu.isEmpty)
            const Padding(padding: EdgeInsets.only(top: 8), child: Text('Chưa có tệp nào.')),
          for (final f in _daLuu)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.picture_as_pdf_outlined, color: Color(0xFFA3241C)),
              title: Text(f.uri.pathSegments.last),
              onTap: () => Share.shareXFiles([XFile(f.path)]),
              trailing: IconButton(tooltip: 'Xóa', icon: const Icon(Icons.delete_outline), onPressed: () => _xoa(f)),
            ),
        ],
      ),
    );
  }
}
