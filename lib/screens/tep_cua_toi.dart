import 'dart:io';

import 'package:flutter/material.dart';

import '../main.dart';
import '../services/tep_pdf.dart';
import '../services/chia_se.dart';
import 'thanh_duoi.dart';

/// Các thư mục app lưu tệp đã tạo, kèm tên hiển thị.
const _thuMucTep = {
  'xuat': 'Biên bản, sổ minh chứng, bảng điểm',
  'quet_pdf': 'Quét PDF',
  'anh_the': 'Ảnh thẻ',
};

class _Tep {
  final File tep;
  final String nhom;
  final DateTime sua;
  _Tep(this.tep, this.nhom, this.sua);
  String get ten => tep.uri.pathSegments.last;
}

/// Tệp của tôi: mọi tệp PDF, ảnh, bảng điểm app đã tạo, mới nhất trước.
class TepCuaToi extends StatefulWidget {
  const TepCuaToi({super.key});

  @override
  State<TepCuaToi> createState() => _TepCuaToiState();
}

class _TepCuaToiState extends State<TepCuaToi> {
  List<_Tep>? _ds;

  @override
  void initState() {
    super.initState();
    _tai();
  }

  Future<void> _tai() async {
    final ds = <_Tep>[];
    for (final e in _thuMucTep.entries) {
      final d = await thuMucApp(e.key);
      for (final f in d.listSync().whereType<File>()) {
        ds.add(_Tep(f, e.value, f.statSync().modified));
      }
    }
    ds.sort((a, b) => b.sua.compareTo(a.sua));
    if (mounted) setState(() => _ds = ds);
  }

  Future<void> _xoa(_Tep t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Xóa tệp này?'),
        content: Text('${t.ten} sẽ bị xóa khỏi máy, không lấy lại được.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Thôi')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Xóa')),
        ],
      ),
    );
    if (ok != true) return;
    await t.tep.delete();
    await _tai();
  }

  IconData _bieuTuong(String ten) {
    final t = ten.toLowerCase();
    if (t.endsWith('.pdf')) return Icons.picture_as_pdf_outlined;
    if (t.endsWith('.csv')) return Icons.table_chart_outlined;
    if (t.endsWith('.jpg') || t.endsWith('.jpeg') || t.endsWith('.png')) return Icons.image_outlined;
    return Icons.insert_drive_file_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final ds = _ds;
    return Scaffold(
      appBar: AppBar(title: const Text('Tệp của tôi')),
      bottomNavigationBar: const ThanhDuoi(chon: nutTep),
      body: ds == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _tai,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  const Text(
                    'Tệp PDF, ảnh thẻ, bảng điểm app đã tạo đều nằm ở đây. Bấm vào tệp để gửi qua Zalo, email.',
                    style: TextStyle(fontSize: 12.5, color: MauApp.chuPhu),
                  ),
                  const SizedBox(height: 12),
                  if (ds.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: Center(child: Text('Chưa có tệp nào.')),
                    ),
                  for (final t in ds)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(_bieuTuong(t.ten), color: MauApp.xanhDam),
                        title: Text(t.ten, maxLines: 2, overflow: TextOverflow.ellipsis),
                        subtitle: Text('${t.nhom} · ${ngayVN(t.sua)}'),
                        onTap: () => guiTep([t.tep.path], context: context),
                        trailing: IconButton(
                          tooltip: 'Xóa',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _xoa(t),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
