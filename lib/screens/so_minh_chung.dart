import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../data/luu_tru.dart';
import '../data/minh_chung.dart';
import '../main.dart';
import '../services/tep_pdf.dart';
import '../services/tep_xlsx.dart';
import 'cau_giup_viec.dart';

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

  /// Tạo PDF cho [ds]. Có [soThuTu]: tệp riêng của một minh chứng (tiêu đề là chính minh chứng đó, ảnh to).
  Future<List<int>> _taoPdf(List<MinhChung> ds, {int? soThuTu}) async {
    final theme = await PhongPdf.theme();
    final doc = pw.Document(theme: theme);
    final noiDung = <pw.Widget>[];
    final rieng = soThuTu != null;
    if (!rieng) {
      noiDung.addAll([
        pw.Center(child: pw.Text('SỔ MINH CHỨNG', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold))),
        if (_loc != null) pw.Center(child: pw.Text(_loc!, style: const pw.TextStyle(fontSize: 12))),
        pw.Center(
          child: pw.Text('Xuất ngày ${ngayVN(DateTime.now())}, gồm ${ds.length} minh chứng',
              style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic)),
        ),
        pw.SizedBox(height: 14),
      ]);
    }
    String? nhomTruoc;
    var stt = soThuTu ?? 0;
    for (final m in ds) {
      if (!rieng && m.nhom != nhomTruoc) {
        nhomTruoc = m.nhom;
        noiDung.add(pw.Padding(
          padding: const pw.EdgeInsets.only(top: 8, bottom: 6),
          child: pw.Text(m.nhom.toUpperCase(), style: pw.TextStyle(fontSize: 12.5, fontWeight: pw.FontWeight.bold)),
        ));
      }
      if (!rieng) stt++;
      final ma = m.ma.trim().isEmpty ? '' : '[${m.ma.trim()}] ';
      noiDung.add(pw.Text(rieng ? 'Minh chứng số $stt · ${m.nhom}' : '$stt. $ma${m.tieuDe}',
          style: pw.TextStyle(fontSize: rieng ? 10.5 : 12, fontWeight: rieng ? null : pw.FontWeight.bold)));
      if (rieng) {
        if (ma.isNotEmpty) noiDung.add(pw.Text('Mã minh chứng: ${m.ma.trim()}', style: const pw.TextStyle(fontSize: 10.5)));
        noiDung.add(pw.Padding(
          padding: const pw.EdgeInsets.only(top: 6, bottom: 2),
          child: pw.Text(m.tieuDe, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        ));
      }
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
            // Tệp riêng: ảnh to gần hết trang để hệ thống, người chấm đọc rõ chữ trên giấy khen
            child: pw.Image(pw.MemoryImage(await f.readAsBytes()), height: rieng ? 600 : 300, fit: pw.BoxFit.contain),
          ),
        ));
      }
      noiDung.add(pw.SizedBox(height: 12));
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
    return doc.save();
  }

  /// Hỏi kiểu xuất. Các minh chứng đang hiện (theo nhóm đã chọn) được xếp đúng thứ tự nộp.
  Future<void> _xuat() async {
    final ds = xepDeNop(_dangHien);
    if (ds.isEmpty) {
      _bao(_loc == null ? 'Chưa có minh chứng nào để xuất. Bấm Thêm minh chứng để chụp giấy khen, giấy chứng nhận.' : 'Nhóm này chưa có minh chứng nào.');
      return;
    }
    final kieu = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Xuất ${ds.length} minh chứng${_loc == null ? '' : ' nhóm $_loc'}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            ListTile(
              leading: const Icon(Icons.cloud_upload_outlined),
              title: const Text('Để tải lên hệ thống'),
              subtitle: const Text('Mỗi minh chứng một tệp PDF đặt tên không dấu (01_..., 02_...), kèm danh mục Excel. '
                  'Dùng cho TEMIS, phần mềm kiểm định, hồ sơ thi đua trực tuyến.'),
              onTap: () => Navigator.pop(c, 'tung_tep'),
            ),
            ListTile(
              leading: const Icon(Icons.folder_zip_outlined),
              title: const Text('Gói nén .zip'),
              subtitle: const Text('Cùng các tệp trên, gộp thành một tệp để gửi Zalo, email, mở trên máy tính.'),
              onTap: () => Navigator.pop(c, 'zip'),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('Một tệp PDF gộp'),
              subtitle: const Text('Tất cả minh chứng trong một tệp, xếp theo nhóm, để in hoặc nộp bản giấy.'),
              onTap: () => Navigator.pop(c, 'pdf'),
            ),
            ListTile(
              leading: const Icon(Icons.table_chart_outlined),
              title: const Text('Danh mục Excel'),
              subtitle: const Text('Bảng số thứ tự, mã, tên, ngày, ghi chú, tên tệp: chép sang danh mục của hệ thống.'),
              onTap: () => Navigator.pop(c, 'excel'),
            ),
          ],
        ),
      ),
    );
    if (kieu == null || !mounted) return;
    setState(() => _dangXuat = true);
    try {
      final dau = dauThoiGian(DateTime.now());
      final goc = (await thuMucApp('xuat')).path;
      final excel = taoXlsx(bangDanhMuc(ds), tenTrang: 'Danh mục minh chứng', doRong: [6, 16, 22, 48, 12, 40, 8, 44]);
      if (kieu == 'pdf') {
        final f = File('$goc/So_minh_chung_$dau.pdf');
        await f.writeAsBytes(await _taoPdf(ds));
        await Share.shareXFiles([XFile(f.path)]);
      } else if (kieu == 'excel') {
        final f = File('$goc/Danh_muc_minh_chung_$dau.xlsx');
        await f.writeAsBytes(excel);
        await Share.shareXFiles([XFile(f.path)]);
      } else {
        final thu = Directory('$goc/Minh_chung_$dau');
        await thu.create(recursive: true);
        final tep = <File>[];
        for (var i = 0; i < ds.length; i++) {
          final f = File('${thu.path}/${tenTepMinhChung(i + 1, ds[i])}');
          await f.writeAsBytes(await _taoPdf([ds[i]], soThuTu: i + 1));
          tep.add(f);
        }
        final dm = File('${thu.path}/00_Danh_muc_minh_chung.xlsx');
        await dm.writeAsBytes(excel);
        tep.insert(0, dm);
        if (kieu == 'zip') {
          final a = Archive();
          for (final f in tep) {
            final b = await f.readAsBytes();
            a.addFile(ArchiveFile(f.uri.pathSegments.last, b.length, b));
          }
          final List<int>? z = ZipEncoder().encode(a);
          final fz = File('$goc/Minh_chung_$dau.zip');
          await fz.writeAsBytes(z ?? <int>[]);
          await Share.shareXFiles([XFile(fz.path)]);
        } else {
          _bao('Đã tạo ${ds.length} tệp PDF và danh mục. Thầy cô chọn Lưu vào Tệp hoặc Drive để tải lên hệ thống từng tệp.');
          await Share.shareXFiles([for (final f in tep) XFile(f.path)]);
        }
      }
    } catch (e) {
      _bao('Chưa xuất được: $e');
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
            tooltip: 'Xuất để nộp hồ sơ',
            onPressed: _dangXuat ? null : _xuat,
            icon: _dangXuat
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.ios_share),
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
            'Khi cần nộp hồ sơ thi đua, đánh giá chuẩn hay kiểm định, bấm Xuất để nộp hồ sơ: '
            'app tạo mỗi minh chứng một tệp PDF kèm danh mục Excel để tải lên hệ thống, hoặc một tệp PDF gộp để in.',
            style: TextStyle(fontSize: 12.5, color: MauApp.chuPhu),
          ),
          const SizedBox(height: 10),
          if (_ds.isNotEmpty) ...[
            FilledButton.tonalIcon(
              onPressed: _dangXuat ? null : _xuat,
              icon: _dangXuat
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.ios_share),
              label: Text(_dangXuat ? 'Đang tạo tệp…' : 'Xuất để nộp hồ sơ (${ds.length})'),
            ),
            const SizedBox(height: 10),
          ],
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
                title: Text('${m.ma.trim().isEmpty ? '' : '[${m.ma.trim()}] '}${m.tieuDe}', maxLines: 2, overflow: TextOverflow.ellipsis),
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
  late final TextEditingController _ma;
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
    _ma = TextEditingController(text: g?.ma ?? '');
    _nhom = g?.nhom ?? widget.nhomMacDinh ?? dsNhomMinhChung.first;
    _ngay = g?.ngay ?? DateTime.now();
    _anh = [...?g?.anh];
  }

  @override
  void dispose() {
    _tieuDe.dispose();
    _ghiChu.dispose();
    _ma.dispose();
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
      ma: _ma.text.trim(),
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
              isExpanded: true,
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
            TextField(
              controller: _ma,
              decoration: const InputDecoration(
                labelText: 'Mã minh chứng (nếu hồ sơ yêu cầu)',
                hintText: 'Ví dụ: H1-1.1-01 khi kiểm định, TC3 khi đánh giá chuẩn',
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
