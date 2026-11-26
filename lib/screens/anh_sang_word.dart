import 'dart:io';

import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../main.dart';
import '../services/tep_pdf.dart';
import '../services/tep_word.dart';
import 'cau_giup_viec.dart';
import '../services/chia_se.dart';

/// Ảnh sang Word: chụp hoặc chọn ảnh văn bản, nhận chữ ngay trên máy, sửa rồi xuất tệp Word.
class AnhSangWord extends StatefulWidget {
  const AnhSangWord({super.key});

  @override
  State<AnhSangWord> createState() => _AnhSangWordState();
}

class _AnhSangWordState extends State<AnhSangWord> {
  final _anh = <String>[];
  final _chu = TextEditingController();
  final _tieuDe = TextEditingController();
  bool _dangNhan = false;

  @override
  void dispose() {
    _chu.dispose();
    _tieuDe.dispose();
    super.dispose();
  }

  Future<void> _chup() async {
    try {
      final ds = await CunningDocumentScanner.getPictures();
      if (ds == null || ds.isEmpty) return;
      await _nhan(ds);
    } catch (_) {
      _bao('Chưa mở được máy ảnh. Thầy cô cho app quyền dùng máy ảnh, hoặc bấm Chọn ảnh.');
    }
  }

  Future<void> _chon() async {
    try {
      final ds = await ImagePicker().pickMultiImage(imageQuality: 95);
      if (ds.isEmpty) return;
      await _nhan(ds.map((x) => x.path).toList());
    } catch (_) {
      _bao('Chưa lấy được ảnh.');
    }
  }

  Future<void> _nhan(List<String> duongDan) async {
    setState(() => _dangNhan = true);
    final may = TextRecognizer(script: TextRecognitionScript.latin);
    final ketQua = <String>[];
    try {
      for (final p in duongDan) {
        final r = await may.processImage(InputImage.fromFilePath(p));
        // Mỗi khối chữ là một đoạn; các dòng trong khối nối lại thành câu.
        final doan = r.blocks.map((b) => b.lines.map((l) => l.text.trim()).join(' ')).where((t) => t.isNotEmpty);
        ketQua.add(doan.join('\n\n'));
      }
    } catch (_) {
      _bao('Máy này chưa nhận chữ được. Thầy cô thử ảnh rõ hơn.');
    } finally {
      await may.close();
    }
    if (!mounted) return;
    setState(() {
      _dangNhan = false;
      _anh.addAll(duongDan);
      final moi = ketQua.where((t) => t.trim().isNotEmpty).join('\n\n');
      _chu.text = _chu.text.trim().isEmpty ? moi : '${_chu.text.trim()}\n\n$moi';
    });
    if (ketQua.every((t) => t.trim().isEmpty)) _bao('Không thấy chữ trong ảnh. Thầy cô chụp gần, đủ sáng, giấy phẳng.');
  }

  Future<void> _xuatWord() async {
    final doan = tachDoan(_chu.text);
    if (doan.isEmpty) {
      _bao('Chưa có chữ nào để xuất.');
      return;
    }
    final ten = 'Van_ban_${tenTep(_tieuDe.text.trim().isEmpty ? 'tu_anh' : _tieuDe.text.trim())}_${dauThoiGian(DateTime.now())}.docx';
    final f = File('${(await thuMucApp('xuat')).path}/$ten');
    await f.writeAsBytes(taoDocx(doan, tieuDe: _tieuDe.text));
    if (!mounted) return;
    await baoDaLuuTep(context, f, tieuDe: 'Đã lưu tệp Word');
  }

  void _bao(String s) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ảnh sang Word')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          const CauGiupViec('sang_word'),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _dangNhan ? null : _chup,
                icon: const Icon(Icons.document_scanner_outlined),
                label: const Text('Chụp văn bản'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _dangNhan ? null : _chon,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Chọn ảnh'),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          const Text(
            'Nhận chữ ngay trên máy, không gửi ảnh đi đâu. Chữ có dấu đôi chỗ có thể sai, thầy cô đọc lại và sửa trước khi xuất.',
            style: TextStyle(fontSize: 12, color: MauApp.chuPhu),
          ),
          if (_dangNhan) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
          if (_anh.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 90,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                for (final a in _anh)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.file(File(a), width: 68, height: 90, fit: BoxFit.cover)),
                  ),
              ]),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _tieuDe,
            decoration: const InputDecoration(labelText: 'Tiêu đề văn bản (không bắt buộc)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _chu,
            minLines: 10,
            maxLines: 40,
            decoration: const InputDecoration(
              labelText: 'Chữ nhận được (sửa trực tiếp được)',
              hintText: 'Mỗi đoạn cách nhau một dòng trống',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _chu.text));
                  _bao('Đã chép chữ.');
                },
                icon: const Icon(Icons.copy),
                label: const Text('Chép'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed: _xuatWord,
                icon: const Icon(Icons.description_outlined),
                label: const Text('Xuất Word'),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
