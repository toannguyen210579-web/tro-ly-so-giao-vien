import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/gio_the.dart';
import '../main.dart';
import '../services/tep_pdf.dart';
import 'cau_giup_viec.dart';
import 'nhan_xet.dart';

const _mauDapAn = {
  'A': Color(0xFFD7261E),
  'B': Color(0xFF1F6FE5),
  'C': Color(0xFF0B8A57),
  'D': Color(0xFFE08A00),
};

/// Giơ thẻ: in bộ thẻ QR, học sinh xoay thẻ chọn A/B/C/D, giáo viên chụp một tấm là có đáp án cả lớp.
class GioThe extends StatefulWidget {
  const GioThe({super.key});

  @override
  State<GioThe> createState() => _GioTheState();
}

class _GioTheState extends State<GioThe> {
  List<Lop>? _ds;
  int _chonLop = -1; // -1: không theo lớp, chỉ dùng số thẻ
  int _siSo = 40;
  double _hieuChinh = 0;
  CauGioThe _cau = CauGioThe(tieuDe: 'Câu 1', luc: DateTime.now());
  List<CauGioThe> _daLam = [];
  bool _dangQuet = false;

  @override
  void initState() {
    super.initState();
    _tai();
  }

  Future<void> _tai() async {
    final ds = await docLop();
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _ds = ds;
      _hieuChinh = p.getDouble('gt_xoay') ?? 0;
      final i = ds.indexWhere((l) => l.ten == p.getString('lop_dang_day'));
      _chonLop = ds.isEmpty ? -1 : (i < 0 ? 0 : i);
    });
    await _taiLichSu();
  }

  String get _khoa => 'gio_the_${_chonLop < 0 ? 'so' : _ds![_chonLop].ten}';

  List<String> get _ten => _chonLop < 0 ? [] : _ds![_chonLop].hocSinh.map((h) => h.ten).toList();

  int get _soThe => _chonLop < 0 ? _siSo : _ten.length;

  String _tenEm(int so) => (so >= 1 && so <= _ten.length) ? _ten[so - 1] : 'Thẻ số $so';

  Future<void> _taiLichSu() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_khoa);
    final ds = <CauGioThe>[];
    if (s != null) {
      try {
        ds.addAll((jsonDecode(s) as List).map((e) => CauGioThe.fromJson(Map<String, dynamic>.from(e as Map))));
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _daLam = ds;
      _cau = CauGioThe(tieuDe: 'Câu ${ds.length + 1}', luc: DateTime.now());
    });
  }

  Future<void> _ghiLichSu() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_khoa, jsonEncode(_daLam.map((c) => c.toJson()).toList()));
  }

  // ---------------------------------------------------------------- quét
  Future<void> _quet(ImageSource nguon) async {
    final XFile? anh;
    try {
      anh = await ImagePicker().pickImage(source: nguon, imageQuality: 95);
    } catch (_) {
      _bao('Chưa mở được máy ảnh. Thầy cô cho app quyền dùng máy ảnh.');
      return;
    }
    if (anh == null) return;
    setState(() => _dangQuet = true);
    final may = BarcodeScanner(formats: [BarcodeFormat.qrCode]);
    var moi = 0;
    try {
      final ds = await may.processImage(InputImage.fromFilePath(anh.path));
      for (final b in ds) {
        final so = soTuMa(b.rawValue);
        final g = b.cornerPoints;
        if (so == null || g.length < 2) continue;
        final goc = gocCanhTren(g[0].x.toDouble(), g[0].y.toDouble(), g[1].x.toDouble(), g[1].y.toDouble());
        _cau.traLoi[so] = dapAnTuGoc(goc, hieuChinh: _hieuChinh);
        moi++;
      }
    } catch (_) {
      _bao('Máy này chưa đọc được ảnh. Thầy cô thử chụp lại.');
    } finally {
      await may.close();
    }
    if (!mounted) return;
    setState(() => _dangQuet = false);
    _bao(moi == 0
        ? 'Chưa thấy thẻ nào. Thầy cô đứng gần hơn, đủ sáng, các em giơ thẻ thẳng về phía máy.'
        : 'Đọc được $moi thẻ. Còn thiếu em nào thì chụp thêm, kết quả được cộng dồn.');
  }

  /// Hiệu chỉnh: một em giơ thẻ chữ A lên trên, chụp; app lấy góc đó làm chuẩn.
  Future<void> _hieuChinhMay() async {
    final anh = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 95);
    if (anh == null) return;
    final may = BarcodeScanner(formats: [BarcodeFormat.qrCode]);
    try {
      final ds = (await may.processImage(InputImage.fromFilePath(anh.path))).where((b) => soTuMa(b.rawValue) != null).toList();
      if (ds.isEmpty) {
        _bao('Chưa thấy thẻ trong ảnh.');
        return;
      }
      final g = ds.first.cornerPoints;
      final goc = gocCanhTren(g[0].x.toDouble(), g[0].y.toDouble(), g[1].x.toDouble(), g[1].y.toDouble());
      // Làm tròn về bội số 90 độ gần nhất: chỉ sửa trường hợp ảnh bị xoay sẵn.
      final chuan = (goc / 90).round() * 90.0;
      final p = await SharedPreferences.getInstance();
      await p.setDouble('gt_xoay', chuan);
      if (mounted) setState(() => _hieuChinh = chuan);
      _bao(chuan == 0 ? 'Máy đọc đúng chiều, không cần chỉnh.' : 'Đã chỉnh chiều ảnh ${chuan.toStringAsFixed(0)} độ.');
    } catch (_) {
      _bao('Chưa đọc được ảnh.');
    } finally {
      await may.close();
    }
  }

  Future<void> _cauMoi() async {
    if (_cau.traLoi.isNotEmpty) {
      _daLam.add(_cau);
      await _ghiLichSu();
    }
    setState(() => _cau = CauGioThe(tieuDe: 'Câu ${_daLam.length + 1}', luc: DateTime.now()));
  }

  // ---------------------------------------------------------------- in thẻ
  Future<void> _inThe() async {
    final n = _soThe;
    if (n < 1) {
      _bao('Lớp chưa có học sinh.');
      return;
    }
    final theme = await PhongPdf.theme();
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
                      width: 95 * PdfPageFormat.mm,
                      height: 95 * PdfPageFormat.mm,
                      drawText: false,
                    ),
                  ),
                ),
                chu('B', -pi / 2),
              ]),
            ),
            chu('C', pi),
            pw.SizedBox(height: 4),
            pw.Text('Số $so${so <= _ten.length ? ' · ${_ten[so - 1]}' : ''}', style: const pw.TextStyle(fontSize: 10)),
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
    final tenLop = _chonLop < 0 ? 'so_1_$n' : tenTep(_ds![_chonLop].ten);
    final f = File('${(await thuMucApp('xuat')).path}/The_gio_${tenLop}_${dauThoiGian(DateTime.now())}.pdf');
    await f.writeAsBytes(await doc.save());
    await Share.shareXFiles([XFile(f.path)], text: 'Bộ thẻ giơ đáp án');
  }

  // ---------------------------------------------------------------- xuất
  String _bangKetQua() {
    final ds = [..._daLam, if (_cau.traLoi.isNotEmpty) _cau];
    final b = StringBuffer('STT,Họ và tên,${ds.map((c) => c.tieuDe).join(',')},Số câu đúng\n');
    for (var so = 1; so <= _soThe; so++) {
      var dung = 0;
      final o = <String>[];
      for (final c in ds) {
        final t = c.traLoi[so] ?? '';
        if (c.dapAnDung != null && t == c.dapAnDung) dung++;
        o.add(t);
      }
      b.writeln('$so,"${_tenEm(so).replaceAll('"', "'")}",${o.join(',')},$dung');
    }
    b.writeln('Đáp án đúng,,${ds.map((c) => c.dapAnDung ?? '').join(',')},');
    return b.toString();
  }

  Future<void> _xuatExcel() async {
    final f = File('${(await thuMucApp('xuat')).path}/Gio_the_${tenTep(_chonLop < 0 ? 'so' : _ds![_chonLop].ten)}_${dauThoiGian(DateTime.now())}.csv');
    await f.writeAsString('﻿${_bangKetQua()}');
    await Share.shareXFiles([XFile(f.path)]);
  }

  Future<void> _xoaLichSu() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Xóa kết quả các câu đã làm?'),
        content: const Text('Bộ thẻ in ra vẫn dùng tiếp được.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Thôi')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Xóa')),
        ],
      ),
    );
    if (ok != true) return;
    _daLam = [];
    await _ghiLichSu();
    setState(() => _cau = CauGioThe(tieuDe: 'Câu 1', luc: DateTime.now()));
  }

  void _bao(String s) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  // ---------------------------------------------------------------- giao diện
  @override
  Widget build(BuildContext context) {
    final ds = _ds;
    if (ds == null) {
      return Scaffold(appBar: AppBar(title: const Text('Giơ thẻ')), body: const Center(child: CircularProgressIndicator()));
    }
    final tk = _cau.thongKe;
    final daCo = _cau.traLoi.length;
    final thieu = [for (var so = 1; so <= _soThe; so++) if (!_cau.traLoi.containsKey(so)) so];
    return Scaffold(
      appBar: AppBar(title: const Text('Giơ thẻ'), actions: [
        PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'chinh') _hieuChinhMay();
            if (v == 'xoa') _xoaLichSu();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'chinh', child: Text('Hiệu chỉnh chiều máy ảnh')),
            PopupMenuItem(value: 'xoa', child: Text('Xóa kết quả đã lưu')),
          ],
        ),
      ]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          const CauGiupViec('gio_the'),
          DropdownButtonFormField<int>(
            value: _chonLop,
            decoration: const InputDecoration(labelText: 'Lớp', border: OutlineInputBorder(), isDense: true),
            items: [
              for (var i = 0; i < ds.length; i++) DropdownMenuItem(value: i, child: Text('Lớp ${ds[i].ten} · ${ds[i].hocSinh.length} em')),
              const DropdownMenuItem(value: -1, child: Text('Không theo lớp (chỉ số thẻ)')),
            ],
            onChanged: (v) async {
              setState(() => _chonLop = v ?? -1);
              if (_chonLop >= 0) (await SharedPreferences.getInstance()).setString('lop_dang_day', ds[_chonLop].ten);
              await _taiLichSu();
            },
          ),
          if (_chonLop < 0)
            Row(children: [
              const Text('Số thẻ:'),
              Expanded(
                child: Slider(
                  value: _siSo.toDouble(),
                  min: 5,
                  max: 60,
                  divisions: 55,
                  label: '$_siSo',
                  onChanged: (v) => setState(() => _siSo = v.round()),
                ),
              ),
              Text('$_siSo'),
            ]),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _inThe,
            icon: const Icon(Icons.print_outlined),
            label: Text('In bộ thẻ ($_soThe thẻ, 2 thẻ một trang A4)'),
          ),
          const SizedBox(height: 4),
          const Text(
            'In một lần, dùng cả năm. Em nào số mấy giữ thẻ số đó (theo thứ tự trong danh sách lớp). '
            'Muốn chọn đáp án nào thì xoay thẻ cho chữ đó lên trên, giơ thẻ về phía thầy cô.',
            style: TextStyle(fontSize: 12, color: MauApp.chuPhu),
          ),
          const Divider(height: 28),
          Row(children: [
            Expanded(
              child: TextFormField(
                key: ValueKey(_cau.luc),
                initialValue: _cau.tieuDe,
                decoration: const InputDecoration(labelText: 'Câu hỏi', isDense: true, border: OutlineInputBorder()),
                onChanged: (v) => _cau.tieuDe = v.trim().isEmpty ? 'Câu ${_daLam.length + 1}' : v.trim(),
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(onPressed: _cauMoi, icon: const Icon(Icons.skip_next), label: const Text('Câu mới')),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _dangQuet ? null : () => _quet(ImageSource.camera),
                icon: const Icon(Icons.photo_camera),
                label: const Text('Chụp cả lớp'),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _dangQuet ? null : () => _quet(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Ảnh có sẵn'),
            ),
          ]),
          if (_dangQuet) const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator())),
          const SizedBox(height: 12),
          Text('Đã nhận $daCo/$_soThe em', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 8),
          for (final c in ['A', 'B', 'C', 'D'])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                SizedBox(
                  width: 34,
                  child: Text(c, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: _mauDapAn[c])),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: daCo == 0 ? 0 : tk[c]! / daCo,
                      minHeight: 18,
                      color: _mauDapAn[c],
                      backgroundColor: const Color(0xFFE6EAF0),
                    ),
                  ),
                ),
                SizedBox(width: 44, child: Text('  ${tk[c]}')),
              ]),
            ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            const Text('Đáp án đúng:'),
            for (final c in ['A', 'B', 'C', 'D'])
              ChoiceChip(
                label: Text(c),
                selected: _cau.dapAnDung == c,
                onSelected: (s) => setState(() => _cau.dapAnDung = s ? c : null),
              ),
          ]),
          if (_cau.dapAnDung != null && daCo > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Đúng ${tk[_cau.dapAnDung]}/$daCo em (${(tk[_cau.dapAnDung]! * 100 / daCo).round()}%)',
                style: const TextStyle(fontWeight: FontWeight.w700, color: MauApp.xanhLa),
              ),
            ),
          if (thieu.isNotEmpty && daCo > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Chưa nhận: ${thieu.map((s) => _chonLop < 0 ? '$s' : '$s. ${_tenEm(s)}').join(', ')}',
                style: const TextStyle(fontSize: 13, color: MauApp.chuPhu),
              ),
            ),
          if (daCo > 0) ...[
            const SizedBox(height: 10),
            Card(
              child: Column(children: [
                for (final e in (_cau.traLoi.entries.toList()..sort((a, b) => a.key.compareTo(b.key))))
                  ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor: _mauDapAn[e.value],
                      child: Text(e.value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                    ),
                    title: Text('${e.key}. ${_tenEm(e.key)}'),
                    trailing: _cau.dapAnDung == null
                        ? null
                        : Icon(e.value == _cau.dapAnDung ? Icons.check_circle : Icons.cancel,
                            color: e.value == _cau.dapAnDung ? MauApp.xanhLa : const Color(0xFFD7261E)),
                    onTap: () => _sua(e.key),
                  ),
              ]),
            ),
          ],
          const Divider(height: 28),
          Text('Các câu đã lưu: ${_daLam.length}', style: const TextStyle(fontWeight: FontWeight.w700)),
          for (final c in _daLam.reversed)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(c.tieuDe),
              subtitle: Text(
                '${c.traLoi.length} em · A ${c.thongKe['A']} · B ${c.thongKe['B']} · C ${c.thongKe['C']} · D ${c.thongKe['D']}'
                '${c.dapAnDung == null ? '' : ' · đáp án ${c.dapAnDung}'}',
              ),
            ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: (_daLam.isEmpty && _cau.traLoi.isEmpty) ? null : _xuatExcel,
                icon: const Icon(Icons.table_view_outlined),
                label: const Text('Xuất Excel'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: (_daLam.isEmpty && _cau.traLoi.isEmpty)
                    ? null
                    : () async {
                        await Clipboard.setData(ClipboardData(text: _bangKetQua()));
                        _bao('Đã chép bảng kết quả.');
                      },
                icon: const Icon(Icons.copy),
                label: const Text('Chép bảng'),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  /// Sửa tay một em (thẻ bị che, đọc nhầm).
  Future<void> _sua(int so) async {
    final c = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(children: [
          ListTile(title: Text('$so. ${_tenEm(so)}')),
          for (final d in ['A', 'B', 'C', 'D']) ListTile(title: Text('Chọn $d'), onTap: () => Navigator.pop(ctx, d)),
          ListTile(title: const Text('Bỏ kết quả của em này'), onTap: () => Navigator.pop(ctx, '')),
        ]),
      ),
    );
    if (c == null) return;
    setState(() {
      if (c.isEmpty) {
        _cau.traLoi.remove(so);
      } else {
        _cau.traLoi[so] = c;
      }
    });
  }
}
