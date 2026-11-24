import 'dart:io';

import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../main.dart';
import 'cau_giup_viec.dart';
import '../services/anh_trang.dart';
import '../services/chia_se.dart';

/// Quét giấy tờ bằng máy ảnh (tự nhận mép giấy), thêm ảnh, tệp PDF có sẵn, rồi gộp thành một tệp PDF.
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
  bool _dangLay = false; // đang đổi ảnh, tệp PDF có sẵn thành trang

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

  /// Ảnh có sẵn trong thư viện ảnh (chọn nhiều tấm), mỗi ảnh một trang.
  Future<void> _chonAnh() async {
    final List<XFile> ds;
    try {
      ds = await ImagePicker().pickMultiImage(maxWidth: 2200, maxHeight: 2200, imageQuality: 85);
    } catch (_) {
      _bao('Chưa mở được thư viện ảnh. Thầy cô cho app quyền dùng ảnh trong Cài đặt.');
      return;
    }
    if (ds.isEmpty) return;
    setState(() => _dangLay = true);
    final them = <String>[];
    var loi = 0;
    for (final x in ds) {
      try {
        them.add(await anhSangJpeg(x.path));
      } catch (_) {
        loi++;
      }
    }
    if (!mounted) return;
    setState(() {
      _trang.addAll(them);
      _dangLay = false;
    });
    if (loi > 0) _bao('Có $loi ảnh chưa mở được, app bỏ qua.');
  }

  /// Tệp PDF, ảnh có sẵn trong máy (ứng dụng Tệp, Drive, Zalo đã tải về…): PDF thì mỗi trang thành một trang.
  Future<void> _chonTep() async {
    setState(() => _dangLay = true);
    try {
      final kq = await chonTrangTuTep();
      if (!mounted || kq == null) return;
      setState(() => _trang.addAll(kq.trang));
      if (kq.loiNhan != null) _bao(kq.loiNhan!);
    } catch (_) {
      _bao('Chưa mở được tệp, thầy cô thử lại.');
    } finally {
      if (mounted) setState(() => _dangLay = false);
    }
  }

  /// Gộp các trang thành tệp PDF, lưu trong máy rồi báo chỗ lưu kèm nút gửi đi.
  Future<void> _taoPdf() async {
    if (_trang.isEmpty) return;
    setState(() => _dangTao = true);
    final File f;
    try {
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
      f = File('${(await _thuMuc()).path}/$ten');
      await f.writeAsBytes(await doc.save());
    } catch (_) {
      if (mounted) setState(() => _dangTao = false);
      _bao('Chưa tạo được tệp PDF. Thầy cô bỏ bớt trang lạ rồi thử lại.');
      return;
    }
    if (!mounted) return;
    setState(() {
      _dangTao = false;
      _trang.clear();
    });
    await _taiDaLuu();
    if (!mounted) return;
    await baoDaLuuTep(context, f, tieuDe: 'Đã lưu tệp PDF');
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
          const CauGiupViec('quet'),
          FilledButton.icon(
            onPressed: _dangLay ? null : _quet,
            icon: const Icon(Icons.document_scanner_outlined),
            label: Text(_trang.isEmpty ? 'Chụp, quét giấy tờ' : 'Chụp, quét thêm trang'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _dangLay ? null : _chonAnh,
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Chọn ảnh có sẵn')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _dangLay ? null : _chonTep,
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                  icon: const Icon(Icons.upload_file),
                  label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Tải tệp PDF, ảnh')),
                ),
              ),
            ],
          ),
          if (_dangLay)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Row(children: [
                SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 10),
                Text('Đang lấy trang…'),
              ]),
            ),
          const SizedBox(height: 8),
          const Text(
            'Chụp: đặt giấy trên nền tối, app tự nhận mép giấy và làm phẳng trang. '
            'Có thể gộp cả trang chụp, ảnh có sẵn và tệp PDF (từ ứng dụng Tệp, Zalo, Drive) thành một tệp.',
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
              label: Text(_dangTao ? 'Đang tạo…' : 'Lưu thành tệp PDF (${_trang.length} trang)'),
            ),
          ],
          const SizedBox(height: 24),
          const Text('Tệp PDF đã lưu', style: TextStyle(fontWeight: FontWeight.w800)),
          Text(noiLuuTep, style: const TextStyle(fontSize: 12, color: MauApp.chuPhu)),
          if (_daLuu.isEmpty)
            const Padding(padding: EdgeInsets.only(top: 8), child: Text('Chưa có tệp nào.')),
          for (final f in _daLuu)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.picture_as_pdf_outlined, color: Color(0xFFA3241C)),
              title: Text(f.uri.pathSegments.last),
              onTap: () => baoDaLuuTep(context, f, tieuDe: 'Tệp PDF đã lưu'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Builder(
                  builder: (b) => IconButton(
                    tooltip: 'Gửi, lưu ra nơi khác',
                    icon: const Icon(Icons.ios_share),
                    onPressed: () => guiTep([f.path], context: b),
                  ),
                ),
                IconButton(tooltip: 'Xóa', icon: const Icon(Icons.delete_outline), onPressed: () => _xoa(f)),
              ]),
            ),
        ],
      ),
    );
  }
}
