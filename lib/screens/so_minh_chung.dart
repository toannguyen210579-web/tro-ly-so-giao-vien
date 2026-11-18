import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../data/luu_tru.dart';
import '../main.dart';
import '../services/tep_pdf.dart';
import 'cau_giup_viec.dart';

const dsNhomMinhChung = [
  'Chuẩn nghề nghiệp',
  'Thi đua, khen thưởng',
  'Bồi dưỡng, tập huấn',
  'Hoạt động chuyên môn',
  'Kiểm định chất lượng',
  'Khác',
];

/// Một minh chứng: tiêu đề, nhóm, ngày, ghi chú và các ảnh kèm theo.
class MinhChung {
  String id;
  String nhom;
  String tieuDe;
  DateTime ngay;
  String ghiChu;

  /// Tên tệp ảnh trong thư mục minh_chung của app.
  List<String> anh;

  MinhChung({
    required this.id,
    required this.nhom,
    required this.tieuDe,
    required this.ngay,
    this.ghiChu = '',
    List<String>? anh,
  }) : anh = anh ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'nhom': nhom,
        'tieu_de': tieuDe,
        'ngay': ngay.toIso8601String(),
        'ghi_chu': ghiChu,
        'anh': anh,
      };

  factory MinhChung.fromJson(Map<String, dynamic> j) => MinhChung(
        id: j['id'] as String,
        nhom: j['nhom'] as String? ?? 'Khác',
        tieuDe: j['tieu_de'] as String? ?? '',
        ngay: DateTime.tryParse(j['ngay'] as String? ?? '') ?? DateTime.now(),
        ghiChu: j['ghi_chu'] as String? ?? '',
        anh: (j['anh'] as List<dynamic>? ?? []).cast<String>(),
      );
}

const _khoa = 'so_minh_chung';

class SoMinhChung extends StatefulWidget {
  const SoMinhChung({super.key});

  @override
  State<SoMinhChung> createState() => _SoMinhChungState();
}

class _SoMinhChungState extends State<SoMinhChung> {
  List<MinhChung> _ds = [];
  String? _loc;
  String _thuMuc = '';
  bool _dangXuat = false;

  @override
  void initState() {
    super.initState();
    _tai();
  }

  Future<void> _tai() async {
    final d = await thuMucApp('minh_chung');
    final ds = (await LuuTru.docDanhSach(_khoa)).map(MinhChung.fromJson).toList()
      ..sort((a, b) => b.ngay.compareTo(a.ngay));
    if (mounted) {
      setState(() {
        _thuMuc = d.path;
        _ds = ds;
      });
    }
  }

  Future<void> _luu() async {
    _ds.sort((a, b) => b.ngay.compareTo(a.ngay));
    await LuuTru.ghiDanhSach(_khoa, _ds.map((e) => e.toJson()).toList());
    if (mounted) setState(() {});
  }

  List<MinhChung> get _dangHien => _loc == null ? _ds : _ds.where((m) => m.nhom == _loc).toList();

  Future<void> _mo([MinhChung? m]) async {
    final kq = await Navigator.of(context).push<_KetQuaSua>(
      MaterialPageRoute(builder: (_) => _SuaMinhChung(goc: m, thuMuc: _thuMuc, nhomMacDinh: _loc)),
    );
    if (kq == null) return;
    if (kq.xoa) {
      _ds.removeWhere((e) => e.id == kq.minhChung.id);
      for (final a in kq.minhChung.anh) {
        final f = File('$_thuMuc/$a');
        if (await f.exists()) await f.delete();
      }
    } else {
      final i = _ds.indexWhere((e) => e.id == kq.minhChung.id);
      if (i >= 0) {
        _ds[i] = kq.minhChung;
      } else {
        _ds.add(kq.minhChung);
      }
    }
    await _luu();
  }

  Future<void> _xuatPdf() async {
    final ds = _dangHien;
    if (ds.isEmpty) {
      _bao('Chưa có minh chứng nào để xuất.');
      return;
    }
    setState(() => _dangXuat = true);
    try {
      final theme = await PhongPdf.theme();
      final doc = pw.Document(theme: theme);
      final noiDung = <pw.Widget>[
        pw.Center(
          child: pw.Text('SỔ MINH CHỨNG', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        ),
        if (_loc != null) pw.Center(child: pw.Text(_loc!, style: const pw.TextStyle(fontSize: 12))),
        pw.Center(
          child: pw.Text('Xuất ngày ${ngayVN(DateTime.now())}, gồm ${ds.length} minh chứng',
              style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic)),
        ),
        pw.SizedBox(height: 14),
      ];
      final nhomCo = dsNhomMinhChung.where((n) => ds.any((m) => m.nhom == n));
      var stt = 0;
      for (final n in nhomCo) {
        noiDung.add(pw.Padding(
          padding: const pw.EdgeInsets.only(top: 8, bottom: 6),
          child: pw.Text(n.toUpperCase(), style: pw.TextStyle(fontSize: 12.5, fontWeight: pw.FontWeight.bold)),
        ));
        for (final m in ds.where((m) => m.nhom == n)) {
          stt++;
          noiDung.add(pw.Text('$stt. ${m.tieuDe}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)));
          noiDung.add(pw.Text('Ngày: ${ngayVN(m.ngay)}', style: const pw.TextStyle(fontSize: 10.5)));
          if (m.ghiChu.trim().isNotEmpty) {
            noiDung.add(pw.Padding(
              padding: const pw.EdgeInsets.only(top: 2),
              child: pw.Text(m.ghiChu.trim(), style: const pw.TextStyle(fontSize: 11)),
            ));
          }
          for (final a in m.anh) {
            final f = File('$_thuMuc/$a');
            if (!await f.exists()) continue;
            noiDung.add(pw.Padding(
              padding: const pw.EdgeInsets.only(top: 6),
              child: pw.Center(
                child: pw.Image(pw.MemoryImage(await f.readAsBytes()), height: 300, fit: pw.BoxFit.contain),
              ),
            ));
          }
          noiDung.add(pw.SizedBox(height: 12));
        }
      }
      doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(56, 42, 42, 42),
        footer: (c) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('${c.pageNumber}/${c.pagesCount}', style: const pw.TextStyle(fontSize: 9)),
        ),
        build: (_) => noiDung,
      ));
      final ten = 'So_minh_chung_${dauThoiGian(DateTime.now())}.pdf';
      final f = File('${(await thuMucApp('xuat')).path}/$ten');
      await f.writeAsBytes(await doc.save());
      await Share.shareXFiles([XFile(f.path)]);
    } catch (e) {
      _bao('Chưa xuất được PDF: $e');
    } finally {
      if (mounted) setState(() => _dangXuat = false);
    }
  }

  void _bao(String s) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  @override
  Widget build(BuildContext context) {
    final ds = _dangHien;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sổ minh chứng'),
        actions: [
          IconButton(
            tooltip: 'Xuất PDF',
            onPressed: _dangXuat ? null : _xuatPdf,
            icon: _dangXuat
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.picture_as_pdf_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mo(),
        icon: const Icon(Icons.add),
        label: const Text('Thêm minh chứng'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        children: [
          const CauGiupViec('minh_chung'),
          const Text(
            'Chụp giấy khen, ảnh hoạt động, giấy chứng nhận… và xếp theo nhóm. '
            'Khi cần nộp hồ sơ thi đua, đánh giá chuẩn hay kiểm định, bấm biểu tượng PDF ở góc trên để xuất.',
            style: TextStyle(fontSize: 12.5, color: MauApp.chuPhu),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ChoiceChip(label: Text('Tất cả (${_ds.length})'), selected: _loc == null, onSelected: (_) => setState(() => _loc = null)),
              for (final n in dsNhomMinhChung)
                ChoiceChip(
                  label: Text('$n (${_ds.where((m) => m.nhom == n).length})'),
                  selected: _loc == n,
                  onSelected: (_) => setState(() => _loc = n),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (ds.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 32),
              child: Center(child: Text('Chưa có minh chứng nào.')),
            ),
          for (final m in ds)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                onTap: () => _mo(m),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: m.anh.isEmpty
                        ? Container(color: const Color(0xFFE3ECF8), child: const Icon(Icons.description_outlined, color: MauApp.xanhDam))
                        : Image.file(File('$_thuMuc/${m.anh.first}'), fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined)),
                  ),
                ),
                title: Text(m.tieuDe, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text('${m.nhom} · ${ngayVN(m.ngay)}${m.anh.length > 1 ? ' · ${m.anh.length} ảnh' : ''}'),
              ),
            ),
        ],
      ),
    );
  }
}

class _KetQuaSua {
  final MinhChung minhChung;
  final bool xoa;
  const _KetQuaSua(this.minhChung, {this.xoa = false});
}

class _SuaMinhChung extends StatefulWidget {
  final MinhChung? goc;
  final String thuMuc;
  final String? nhomMacDinh;
  const _SuaMinhChung({required this.goc, required this.thuMuc, this.nhomMacDinh});

  @override
  State<_SuaMinhChung> createState() => _SuaMinhChungState();
}

class _SuaMinhChungState extends State<_SuaMinhChung> {
  late final TextEditingController _tieuDe;
  late final TextEditingController _ghiChu;
  late String _nhom;
  late DateTime _ngay;
  late List<String> _anh;
  final _anhMoi = <String>[];

  @override
  void initState() {
    super.initState();
    final g = widget.goc;
    _tieuDe = TextEditingController(text: g?.tieuDe ?? '');
    _ghiChu = TextEditingController(text: g?.ghiChu ?? '');
    _nhom = g?.nhom ?? widget.nhomMacDinh ?? dsNhomMinhChung.first;
    _ngay = g?.ngay ?? DateTime.now();
    _anh = [...?g?.anh];
  }

  @override
  void dispose() {
    _tieuDe.dispose();
    _ghiChu.dispose();
    super.dispose();
  }

  Future<void> _themAnh(ImageSource nguon) async {
    final picker = ImagePicker();
    try {
      final List<XFile> ds;
      if (nguon == ImageSource.camera) {
        final x = await picker.pickImage(source: nguon, maxWidth: 1800, imageQuality: 80);
        ds = x == null ? [] : [x];
      } else {
        ds = await picker.pickMultiImage(maxWidth: 1800, imageQuality: 80);
      }
      for (final x in ds) {
        final duoi = x.path.contains('.') ? x.path.substring(x.path.lastIndexOf('.')) : '.jpg';
        final ten = 'mc_${DateTime.now().microsecondsSinceEpoch}$duoi';
        await File(x.path).copy('${widget.thuMuc}/$ten');
        _anhMoi.add(ten);
        setState(() => _anh.add(ten));
      }
    } catch (_) {
      _bao('Chưa lấy được ảnh. Thầy cô cho app quyền dùng máy ảnh, ảnh trong Cài đặt.');
    }
  }

  Future<void> _boAnh(String ten) async {
    setState(() => _anh.remove(ten));
    if (_anhMoi.remove(ten)) {
      final f = File('${widget.thuMuc}/$ten');
      if (await f.exists()) await f.delete();
    }
  }

  Future<void> _chonNgay() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _ngay,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _ngay = d);
  }

  void _luu() {
    if (_tieuDe.text.trim().isEmpty) {
      _bao('Thầy cô ghi tiêu đề minh chứng, ví dụ "Giấy khen giáo viên dạy giỏi cấp huyện".');
      return;
    }
    // Ảnh bị bỏ khỏi minh chứng cũ: xóa tệp khi lưu.
    for (final a in widget.goc?.anh ?? const <String>[]) {
      if (!_anh.contains(a)) {
        final f = File('${widget.thuMuc}/$a');
        if (f.existsSync()) f.deleteSync();
      }
    }
    Navigator.of(context).pop(_KetQuaSua(MinhChung(
      id: widget.goc?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      nhom: _nhom,
      tieuDe: _tieuDe.text.trim(),
      ngay: _ngay,
      ghiChu: _ghiChu.text.trim(),
      anh: _anh,
    )));
  }

  Future<void> _xoa() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Xóa minh chứng này?'),
        content: const Text('Minh chứng và ảnh kèm theo sẽ bị xóa khỏi máy, không lấy lại được.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Thôi')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Xóa')),
        ],
      ),
    );
    if (ok == true && mounted) Navigator.of(context).pop(_KetQuaSua(widget.goc!, xoa: true));
  }

  /// Thoát mà không lưu: dọn ảnh vừa thêm.
  Future<void> _huy() async {
    for (final a in _anhMoi) {
      final f = File('${widget.thuMuc}/$a');
      if (await f.exists()) await f.delete();
    }
  }

  void _bao(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (daThoat, kq) {
        if (daThoat && kq == null) _huy();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.goc == null ? 'Thêm minh chứng' : 'Sửa minh chứng'),
          actions: [
            if (widget.goc != null) IconButton(tooltip: 'Xóa', onPressed: _xoa, icon: const Icon(Icons.delete_outline)),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            DropdownButtonFormField<String>(
              value: _nhom,
              decoration: const InputDecoration(labelText: 'Nhóm', border: OutlineInputBorder()),
              items: [for (final n in dsNhomMinhChung) DropdownMenuItem(value: n, child: Text(n))],
              onChanged: (v) => setState(() => _nhom = v ?? _nhom),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tieuDe,
              decoration: const InputDecoration(
                labelText: 'Tiêu đề',
                hintText: 'Ví dụ: Giấy chứng nhận bồi dưỡng thường xuyên 2025-2026',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _chonNgay,
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Ngày', border: OutlineInputBorder()),
                child: Text(ngayVN(_ngay)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ghiChu,
              minLines: 2,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Ghi chú (số quyết định, cấp khen, tiêu chí đáp ứng…)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _themAnh(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Chụp ảnh'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _themAnh(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Chọn ảnh'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final a in _anh)
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.file(File('${widget.thuMuc}/$a'), width: 100, height: 130, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const SizedBox(width: 100, height: 130, child: Icon(Icons.broken_image_outlined))),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: IconButton(
                          tooltip: 'Bỏ ảnh',
                          onPressed: () => _boAnh(a),
                          icon: const Icon(Icons.cancel, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton.icon(onPressed: _luu, icon: const Icon(Icons.check), label: const Text('Lưu')),
          ],
        ),
      ),
    );
  }
}
