import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/gio_the.dart';
import '../main.dart';
import '../services/tep_pdf.dart';
import '../services/tep_xlsx.dart';
import '../services/the_gio_pdf.dart';
import 'cau_giup_viec.dart';
import 'nhan_xet.dart';
import '../services/chia_se.dart';

const _mauDapAn = {
  'A': Color(0xFFD7261E),
  'B': Color(0xFF1F6FE5),
  'C': Color(0xFF0B8A57),
  'D': Color(0xFFE08A00),
};

/// Đọc ảnh thành ảnh xám để dò chiều mã QR (chạy ở luồng riêng). Ảnh quá lớn thì thu nhỏ cho nhanh.
AnhXam? _docAnhXam(String duong) {
  final goc = img.decodeImage(File(duong).readAsBytesSync());
  if (goc == null) return null;
  final o = img.bakeOrientation(goc);
  const toiDa = 3200;
  final tiLe = o.width > toiDa ? toiDa / o.width : 1.0;
  final x = tiLe < 1 ? img.copyResize(o, width: toiDa) : o;
  final s = Uint8List(x.width * x.height);
  for (final p in x) {
    s[p.y * x.width + p.x] = (0.299 * p.r + 0.587 * p.g + 0.114 * p.b).round().clamp(0, 255).toInt();
  }
  return AnhXam(s, x.width, x.height, tiLe: tiLe);
}

/// Cắt ảnh thành [cot] x [hang] mảnh chồng nhau, lưu tạm để bộ đọc mã quét lại (mã nhỏ ở lớp đông).
List<(String, int, int)> _catManh((String, String, int, int) v) {
  final (duong, thuMuc, cot, hang) = v;
  final goc = img.decodeImage(File(duong).readAsBytesSync());
  if (goc == null) return [];
  final o = img.bakeOrientation(goc);
  final ds = <(String, int, int)>[];
  var k = 0;
  for (final (x, y, w, h) in chiaManh(o.width, o.height, cot, hang)) {
    final f = '$thuMuc/gio_the_manh_${cot}x${hang}_${k++}.jpg';
    File(f).writeAsBytesSync(img.encodeJpg(img.copyCrop(o, x: x, y: y, width: w, height: h), quality: 92));
    ds.add((f, x, y));
  }
  return ds;
}

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
    final daDoc = <int>{}; // thẻ đã đọc được chiều trong ảnh này
    final chuaRo = <int>{}; // thấy mã nhưng chưa rõ chiều thẻ
    try {
      final xam = await compute(_docAnhXam, anh.path);
      Future<void> doc(String duong, int dx, int dy) async {
        for (final b in await may.processImage(InputImage.fromFilePath(duong))) {
          final so = soTuMa(b.rawValue);
          if (so == null || daDoc.contains(so)) continue;
          final g = [for (final p in b.cornerPoints) (p.x.toDouble() + dx, p.y.toDouble() + dy)];
          final goc = xam == null ? null : gocTuAnh(xam, g);
          if (goc == null) {
            chuaRo.add(so);
            continue;
          }
          _cau.traLoi[so] = dapAnTuGoc(goc, hieuChinh: _hieuChinh);
          daDoc.add(so);
          chuaRo.remove(so);
        }
      }

      await doc(anh.path, 0, 0);
      // Lớp đông, mã nhỏ: quét lại theo từng mảnh ảnh cho đủ thẻ
      if (xam != null && _cau.traLoi.length < _soThe) {
        final thuMuc = (await getTemporaryDirectory()).path;
        for (final (cot, hang) in const [(2, 2), (3, 3)]) {
          if (_cau.traLoi.length >= _soThe) break;
          for (final (duong, x, y) in await compute(_catManh, (anh.path, thuMuc, cot, hang))) {
            await doc(duong, x, y);
          }
        }
      }
    } catch (_) {
      _bao('Máy này chưa đọc được ảnh. Thầy cô thử chụp lại.');
    } finally {
      await may.close();
    }
    if (!mounted) return;
    setState(() => _dangQuet = false);
    final moi = daDoc.length;
    _bao(moi == 0
        ? (chuaRo.isEmpty
            ? 'Chưa thấy thẻ nào. Thầy cô đứng gần hơn, đủ sáng, các em giơ thẻ thẳng về phía máy.'
            : 'Thấy ${chuaRo.length} thẻ nhưng chưa rõ chiều. Thầy cô chụp gần hơn, đủ sáng.')
        : 'Đọc được $moi thẻ.${chuaRo.isEmpty ? '' : ' ${chuaRo.length} thẻ chưa rõ chiều.'} Còn thiếu em nào thì chụp thêm, kết quả được cộng dồn.');
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
      final xam = await compute(_docAnhXam, anh.path);
      final goc = xam == null ? null : gocTuAnh(xam, [for (final p in ds.first.cornerPoints) (p.x.toDouble(), p.y.toDouble())]);
      if (goc == null) {
        _bao('Chưa rõ chiều thẻ. Thầy cô chụp gần hơn, đủ sáng.');
        return;
      }
      // Ảnh chụp thẻ chữ A lên trên: góc đọc được chính là độ xoay sẵn của ảnh.
      final chuan = goc;
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
  bool _dangIn = false;

  /// Tạo bộ thẻ PDF, lưu vào máy, rồi cho chọn In ngay (máy in qua wifi) hoặc gửi tệp đi in ở nơi khác.
  /// Trước 24/11/2026 bấm nút không thấy gì: tạo tệp mất vài giây không có báo, bảng gửi lỗi im lặng trên iPhone.
  Future<void> _inThe() async {
    final n = _soThe;
    if (n < 1) {
      _bao('Lớp chưa có học sinh.');
      return;
    }
    setState(() => _dangIn = true);
    _bao('Đang tạo bộ $n thẻ, thầy cô chờ vài giây…');
    final File f;
    final Uint8List pdf;
    try {
      pdf = await taoPdfBoThe(n, _ten, theme: await PhongPdf.theme());
      final tenLop = _chonLop < 0 ? 'so_1_$n' : tenTep(_ds![_chonLop].ten);
      f = File('${(await thuMucApp('xuat')).path}/The_gio_${tenLop}_${dauThoiGian(DateTime.now())}.pdf');
      await f.writeAsBytes(pdf, flush: true);
    } catch (_) {
      if (mounted) setState(() => _dangIn = false);
      _bao('Chưa tạo được bộ thẻ, thầy cô thử lại.');
      return;
    }
    if (!mounted) return;
    setState(() => _dangIn = false);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    await baoDaLuuTep(
      context,
      f,
      tieuDe: 'Đã tạo bộ $n thẻ (${(n + 1) ~/ 2} trang A4)',
      nutThem: [
        FilledButton.tonalIcon(
          onPressed: () async {
            try {
              await Printing.layoutPdf(onLayout: (_) async => pdf, name: f.uri.pathSegments.last);
            } catch (_) {
              _bao('Máy chưa mở được bảng in. Thầy cô bấm Gửi để in ở máy tính.');
            }
          },
          icon: const Icon(Icons.print_outlined),
          label: const Text('In ngay (máy in nối wifi)'),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // ---------------------------------------------------------------- xuất
  /// Bảng kết quả: mỗi em một dòng, mỗi câu một cột, cột cuối số câu đúng; dòng cuối là đáp án đúng.
  List<List<String>> _bangKetQua() {
    final ds = [..._daLam, if (_cau.traLoi.isNotEmpty) _cau];
    final bang = <List<String>>[
      ['STT', 'Họ và tên', for (final c in ds) c.tieuDe, 'Số câu đúng'],
    ];
    for (var so = 1; so <= _soThe; so++) {
      var dung = 0;
      final o = <String>[];
      for (final c in ds) {
        final t = c.traLoi[so] ?? '';
        if (c.dapAnDung != null && t == c.dapAnDung) dung++;
        o.add(t);
      }
      bang.add(['$so', _tenEm(so), ...o, '$dung']);
    }
    bang.add(['', 'Đáp án đúng', for (final c in ds) c.dapAnDung ?? '', '']);
    return bang;
  }

  bool get _coKetQua => _daLam.isNotEmpty || _cau.traLoi.isNotEmpty;

  void _baoChuaCoKetQua() => _bao('Chưa có kết quả để xuất. Thầy cô bấm Chụp cả lớp khi các em giơ thẻ, '
      'app đọc đáp án từng em rồi mới có bảng kết quả.');

  /// Xuất tệp Excel thật (.xlsx), mở được bằng Excel, Google Trang tính, WPS.
  Future<void> _xuatExcel() async {
    if (!_coKetQua) {
      _baoChuaCoKetQua();
      return;
    }
    try {
      final bang = _bangKetQua();
      final f = File('${(await thuMucApp('xuat')).path}/Gio_the_${tenTep(_chonLop < 0 ? 'so' : _ds![_chonLop].ten)}_${dauThoiGian(DateTime.now())}.xlsx');
      await f.writeAsBytes(taoXlsx(bang, tenTrang: 'Giơ thẻ', doRong: [6, 26, for (var i = 2; i < bang.first.length - 1; i++) 10, 12]), flush: true);
      if (!mounted) return;
      await baoDaLuuTep(context, f, tieuDe: 'Đã xuất bảng kết quả Excel');
    } catch (_) {
      _bao('Chưa xuất được tệp Excel, thầy cô thử lại.');
    }
  }

  /// Chép bảng (các cột cách nhau bằng phím Tab) để dán thẳng vào Excel, Google Trang tính.
  Future<void> _chepBang() async {
    if (!_coKetQua) {
      _baoChuaCoKetQua();
      return;
    }
    await Clipboard.setData(ClipboardData(text: _bangKetQua().map((d) => d.join('\t')).join('\n')));
    _bao('Đã chép bảng kết quả. Mở Excel, bấm vào ô A1 rồi dán.');
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
            isExpanded: true,
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
            onPressed: _dangIn ? null : _inThe,
            icon: _dangIn
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.print_outlined),
            label: Text(_dangIn ? 'Đang tạo bộ thẻ…' : 'In bộ thẻ ($_soThe thẻ, 2 thẻ một trang A4)'),
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
          // Hai nút luôn bấm được (trước đây mờ đi khi chưa có kết quả, thầy cô tưởng bị ẩn): chưa có kết quả thì app nói rõ
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _xuatExcel,
                icon: const Icon(Icons.table_view_outlined),
                label: const Text('Xuất Excel'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _chepBang,
                icon: const Icon(Icons.copy),
                label: const Text('Chép bảng'),
              ),
            ),
          ]),
          if (!_coKetQua)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Bảng kết quả có sau khi thầy cô chụp cả lớp giơ thẻ: mỗi em một dòng, mỗi câu một cột, có số câu đúng.',
                style: TextStyle(fontSize: 12, color: MauApp.chuPhu),
              ),
            ),
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
