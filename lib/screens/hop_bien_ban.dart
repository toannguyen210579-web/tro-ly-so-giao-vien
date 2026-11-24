import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';

import '../data/luu_tru.dart';
import '../main.dart';
import '../services/chon_tep.dart';
import '../services/tep_pdf.dart';
import '../services/tro_ly_api.dart';
import 'doc_to_ghi_loi.dart';
import 'cau_giup_viec.dart';
import '../services/chia_se.dart';

const dsLoaiHop = [
  'Họp tổ chuyên môn',
  'Họp hội đồng sư phạm',
  'Họp phụ huynh học sinh',
  'Sinh hoạt lớp',
  'Họp khác',
];

class BienBan {
  String id;
  String loai;
  String veViec;
  DateTime batDau;
  String ketThuc;
  String diaDiem;
  String chuTri;
  String thuKy;
  String thanhPhan;
  String noiDung;
  String ketLuan;

  BienBan({
    required this.id,
    required this.loai,
    required this.batDau,
    this.veViec = '',
    this.ketThuc = '',
    this.diaDiem = '',
    this.chuTri = '',
    this.thuKy = '',
    this.thanhPhan = '',
    this.noiDung = '',
    this.ketLuan = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'loai': loai,
        've_viec': veViec,
        'bat_dau': batDau.toIso8601String(),
        'ket_thuc': ketThuc,
        'dia_diem': diaDiem,
        'chu_tri': chuTri,
        'thu_ky': thuKy,
        'thanh_phan': thanhPhan,
        'noi_dung': noiDung,
        'ket_luan': ketLuan,
      };

  factory BienBan.fromJson(Map<String, dynamic> j) => BienBan(
        id: j['id'] as String,
        loai: j['loai'] as String? ?? dsLoaiHop.first,
        veViec: j['ve_viec'] as String? ?? '',
        batDau: DateTime.tryParse(j['bat_dau'] as String? ?? '') ?? DateTime.now(),
        ketThuc: j['ket_thuc'] as String? ?? '',
        diaDiem: j['dia_diem'] as String? ?? '',
        chuTri: j['chu_tri'] as String? ?? '',
        thuKy: j['thu_ky'] as String? ?? '',
        thanhPhan: j['thanh_phan'] as String? ?? '',
        noiDung: j['noi_dung'] as String? ?? '',
        ketLuan: j['ket_luan'] as String? ?? '',
      );
}

const _khoa = 'bien_ban';

class HopBienBan extends StatefulWidget {
  const HopBienBan({super.key});

  @override
  State<HopBienBan> createState() => _HopBienBanState();
}

class _HopBienBanState extends State<HopBienBan> {
  List<BienBan> _ds = [];

  @override
  void initState() {
    super.initState();
    _tai();
  }

  Future<void> _tai() async {
    final ds = (await LuuTru.docDanhSach(_khoa)).map(BienBan.fromJson).toList()
      ..sort((a, b) => b.batDau.compareTo(a.batDau));
    if (mounted) setState(() => _ds = ds);
  }

  Future<void> _luu() async {
    _ds.sort((a, b) => b.batDau.compareTo(a.batDau));
    await LuuTru.ghiDanhSach(_khoa, _ds.map((e) => e.toJson()).toList());
    if (mounted) setState(() {});
  }

  Future<void> _mo([BienBan? b]) async {
    final bb = b ?? BienBan(id: DateTime.now().microsecondsSinceEpoch.toString(), loai: dsLoaiHop.first, batDau: DateTime.now());
    final kq = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => _SuaBienBan(bb: bb)));
    if (kq == null) return;
    if (kq) {
      if (!_ds.contains(bb)) _ds.add(bb);
    } else {
      _ds.remove(bb);
    }
    await _luu();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Họp, biên bản')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mo(),
        icon: const Icon(Icons.add),
        label: const Text('Biên bản mới'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        children: [
          const CauGiupViec('hop'),
          const Text(
            'Ghi nhanh ý kiến trong lúc họp (có nút "Nói để ghi" để nói thay gõ). '
            'Họp xong, app xếp thành biên bản đúng mẫu, xuất PDF để in hoặc gửi.',
            style: TextStyle(fontSize: 12.5, color: MauApp.chuPhu),
          ),
          const SizedBox(height: 12),
          if (_ds.isEmpty) const Padding(padding: EdgeInsets.only(top: 32), child: Center(child: Text('Chưa có biên bản nào.'))),
          for (final b in _ds)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                onTap: () => _mo(b),
                leading: const Icon(Icons.mic_none, color: MauApp.xanhDam),
                title: Text(b.veViec.isEmpty ? b.loai : b.veViec, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text('${b.loai} · ${ngayVN(b.batDau)}'),
              ),
            ),
        ],
      ),
    );
  }
}

/// Soạn, sửa một biên bản. Trả về true khi lưu, false khi xóa, null khi thoát.
class _SuaBienBan extends StatefulWidget {
  final BienBan bb;
  const _SuaBienBan({required this.bb});

  @override
  State<_SuaBienBan> createState() => _SuaBienBanState();
}

class _SuaBienBanState extends State<_SuaBienBan> {
  BienBan get bb => widget.bb;
  late final Map<String, TextEditingController> _o;
  final _donViTren = TextEditingController();
  final _donVi = TextEditingController();
  final _diaDanh = TextEditingController();
  late String _loai;
  late DateTime _batDau;
  bool _dangChoAI = false;

  @override
  void initState() {
    super.initState();
    _loai = bb.loai;
    _batDau = bb.batDau;
    _o = {
      've_viec': TextEditingController(text: bb.veViec),
      'ket_thuc': TextEditingController(text: bb.ketThuc),
      'dia_diem': TextEditingController(text: bb.diaDiem),
      'chu_tri': TextEditingController(text: bb.chuTri),
      'thu_ky': TextEditingController(text: bb.thuKy),
      'thanh_phan': TextEditingController(text: bb.thanhPhan),
      'noi_dung': TextEditingController(text: bb.noiDung),
      'ket_luan': TextEditingController(text: bb.ketLuan),
    };
    _taiDonVi();
  }

  Future<void> _taiDonVi() async {
    final p = await SharedPreferences.getInstance();
    _donViTren.text = p.getString('bb_don_vi_tren') ?? '';
    _donVi.text = p.getString('bb_don_vi') ?? '';
    _diaDanh.text = p.getString('bb_dia_danh') ?? '';
  }

  @override
  void dispose() {
    for (final c in _o.values) {
      c.dispose();
    }
    _donViTren.dispose();
    _donVi.dispose();
    _diaDanh.dispose();
    super.dispose();
  }

  void _ghiVao() {
    bb
      ..loai = _loai
      ..batDau = _batDau
      ..veViec = _o['ve_viec']!.text.trim()
      ..ketThuc = _o['ket_thuc']!.text.trim()
      ..diaDiem = _o['dia_diem']!.text.trim()
      ..chuTri = _o['chu_tri']!.text.trim()
      ..thuKy = _o['thu_ky']!.text.trim()
      ..thanhPhan = _o['thanh_phan']!.text.trim()
      ..noiDung = _o['noi_dung']!.text.trim()
      ..ketLuan = _o['ket_luan']!.text.trim();
  }

  Future<void> _luuDonVi() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('bb_don_vi_tren', _donViTren.text.trim());
    await p.setString('bb_don_vi', _donVi.text.trim());
    await p.setString('bb_dia_danh', _diaDanh.text.trim());
  }

  Future<void> _chonGio() async {
    final d = await showDatePicker(context: context, initialDate: _batDau, firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (d == null || !mounted) return;
    final g = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_batDau));
    setState(() => _batDau = DateTime(d.year, d.month, d.day, g?.hour ?? _batDau.hour, g?.minute ?? _batDau.minute));
  }

  void _chenGio() {
    final c = _o['noi_dung']!;
    final now = DateTime.now();
    final chen = '${c.text.isEmpty || c.text.endsWith('\n') ? '' : '\n'}[${hai(now.hour)}:${hai(now.minute)}] ';
    final viTri = c.selection.isValid ? c.selection.end : c.text.length;
    c.text = c.text.substring(0, viTri) + chen + c.text.substring(viTri);
    c.selection = TextSelection.collapsed(offset: viTri + chen.length);
  }

  Future<void> _noiDeGhi() async {
    final t = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const DocToGhiLoi(chiGhiDeTraVe: true)),
    );
    if (t == null || t.isEmpty) return;
    final c = _o['noi_dung']!;
    c.text = c.text.trim().isEmpty ? t : '${c.text.trimRight()}\n$t';
  }

  /// Gửi phần ghi chép lên AI để sắp xếp lại, chỉ khi thầy cô đồng ý.
  Future<void> _nhoAI() async {
    final ghi = _o['noi_dung']!.text.trim();
    if (diaChiMayChu.isEmpty) {
      _bao('Máy chủ AI chưa được nối. Thầy cô vẫn lưu và xuất biên bản bình thường.');
      return;
    }
    if (ghi.length < 30) {
      _bao('Thầy cô ghi thêm diễn biến, ý kiến cuộc họp rồi mới nhờ AI sắp xếp.');
      return;
    }
    // Chỉ hỏi lần đầu; thầy cô đồng ý rồi thì các lần sau gửi luôn
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    final daDongY = p.getBool('bb_dong_y_ai') ?? false;
    final bool? dongY = daDongY ? true : await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Gửi ghi chép cho AI?'),
        content: const Text(
          'Phần "Diễn biến, ý kiến" sẽ được gửi lên máy chủ AI để sắp xếp thành câu văn biên bản. '
          'Tên trường, người chủ trì, thư ký không được gửi. Thầy cô nên bỏ bớt thông tin nhạy cảm trước khi gửi, '
          'và đọc lại bản AI viết trước khi lưu. App chỉ hỏi lần này.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Thôi')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Đồng ý gửi')),
        ],
      ),
    );
    if (dongY != true) return;
    if (!daDongY) await p.setBool('bb_dong_y_ai', true);
    if (!mounted) return;
    setState(() => _dangChoAI = true);
    final kq = await TroLyApi.hoi('Loại cuộc họp: $_loai. Về việc: ${_o['ve_viec']!.text.trim()}.\nGhi chép:\n$ghi', loai: 'bien_ban');
    if (!mounted) return;
    setState(() => _dangChoAI = false);
    final t = kq.traLoi;
    if (t == null) {
      _bao(kq.loi ?? 'Chưa sắp xếp được, thầy cô thử lại.');
      return;
    }
    // AI trả về hai phần, ngăn cách bằng dòng "KẾT LUẬN:".
    final i = t.toUpperCase().indexOf('KẾT LUẬN:');
    final noiDung = (i >= 0 ? t.substring(0, i) : t).replaceFirst(RegExp(r'^\s*NỘI DUNG:\s*', caseSensitive: false), '').trim();
    final ketLuan = i >= 0 ? t.substring(i + 'KẾT LUẬN:'.length).trim() : '';
    final cu = _o['noi_dung']!.text;
    setState(() {
      _o['noi_dung']!.text = noiDung;
      if (ketLuan.isNotEmpty) _o['ket_luan']!.text = ketLuan;
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('AI đã sắp xếp xong. Thầy cô đọc lại, sửa trước khi lưu.'),
      action: SnackBarAction(label: 'Lấy lại bản cũ', onPressed: () => _o['noi_dung']!.text = cu),
    ));
  }

  Future<void> _luu() async {
    _ghiVao();
    await _luuDonVi();
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _xoa() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Xóa biên bản này?'),
        content: const Text('Biên bản sẽ bị xóa khỏi máy, không lấy lại được.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Thôi')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Xóa')),
        ],
      ),
    );
    if (ok == true && mounted) Navigator.of(context).pop(false);
  }

  String _cauKetThuc() {
    final kt = bb.ketThuc.isEmpty ? '…… giờ …… phút' : bb.ketThuc;
    return 'Cuộc họp kết thúc vào lúc $kt cùng ngày. Biên bản đã được thông qua trước '
        'các thành viên dự họp và nhất trí với nội dung biên bản.';
  }

  String _vanBan() {
    _ghiVao();
    final b = StringBuffer()
      ..writeln('BIÊN BẢN ${bb.loai.toUpperCase()}')
      ..writeln(bb.veViec.isEmpty ? '' : 'Về việc ${bb.veViec}')
      ..writeln()
      ..writeln('Thời gian bắt đầu: ${hai(bb.batDau.hour)} giờ ${hai(bb.batDau.minute)} phút, ngày ${ngayVN(bb.batDau)}.')
      ..writeln('Địa điểm: ${bb.diaDiem}')
      ..writeln('Chủ trì: ${bb.chuTri}')
      ..writeln('Thư ký: ${bb.thuKy}')
      ..writeln('Thành phần tham dự: ${bb.thanhPhan}')
      ..writeln()
      ..writeln('NỘI DUNG')
      ..writeln(bb.noiDung)
      ..writeln()
      ..writeln('KẾT LUẬN')
      ..writeln(bb.ketLuan)
      ..writeln()
      ..writeln(_cauKetThuc());
    return b.toString();
  }

  Future<void> _xuatPdf() async {
    _ghiVao();
    await _luuDonVi();
    final theme = await PhongPdf.theme();
    final doc = pw.Document(theme: theme);
    const co = 13.0;
    pw.TextStyle st({bool dam = false, bool nghieng = false, double size = co}) => pw.TextStyle(
          fontSize: size,
          fontWeight: dam ? pw.FontWeight.bold : pw.FontWeight.normal,
          fontStyle: nghieng ? pw.FontStyle.italic : pw.FontStyle.normal,
          lineSpacing: 3,
        );
    pw.Widget doan(String s, {bool dam = false}) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 4),
          child: pw.Text(s, style: st(dam: dam), textAlign: pw.TextAlign.justify),
        );
    final d = bb.batDau;
    final diaDanh = _diaDanh.text.trim().isEmpty ? '……' : _diaDanh.text.trim();
    final donViTren = _donViTren.text.trim().toUpperCase();
    final donVi = _donVi.text.trim().isEmpty ? 'TÊN ĐƠN VỊ' : _donVi.text.trim().toUpperCase();

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(85, 57, 57, 57), // lề trái 30 mm, trên dưới phải 20 mm
      build: (_) => [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              flex: 5,
              child: pw.Column(children: [
                if (donViTren.isNotEmpty) pw.Text(donViTren, style: st(size: 12.5), textAlign: pw.TextAlign.center),
                pw.Text(donVi, style: st(dam: true, size: 12.5), textAlign: pw.TextAlign.center),
                pw.Container(width: 60, height: 0.6, color: PdfColors.black, margin: const pw.EdgeInsets.only(top: 2)),
              ]),
            ),
            pw.Expanded(
              flex: 7,
              child: pw.Column(children: [
                pw.Text('CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM', style: st(dam: true, size: 12.5), textAlign: pw.TextAlign.center),
                pw.Text('Độc lập - Tự do - Hạnh phúc', style: st(dam: true)),
                pw.Container(width: 150, height: 0.6, color: PdfColors.black, margin: const pw.EdgeInsets.only(top: 2)),
                pw.SizedBox(height: 8),
                pw.Text('$diaDanh, ngày ${hai(d.day)} tháng ${hai(d.month)} năm ${d.year}', style: st(nghieng: true)),
              ]),
            ),
          ],
        ),
        pw.SizedBox(height: 18),
        pw.Center(child: pw.Text('BIÊN BẢN', style: st(dam: true, size: 14))),
        pw.Center(
          child: pw.Text(bb.veViec.isEmpty ? bb.loai : '${bb.loai}\n${bb.veViec}', style: st(dam: true), textAlign: pw.TextAlign.center),
        ),
        pw.SizedBox(height: 12),
        doan('I. THỜI GIAN, ĐỊA ĐIỂM, THÀNH PHẦN', dam: true),
        doan('Thời gian bắt đầu: ${hai(d.hour)} giờ ${hai(d.minute)} phút, ngày ${ngayVN(d)}.'),
        doan('Địa điểm: ${bb.diaDiem.isEmpty ? '……' : bb.diaDiem}.'),
        doan('Chủ trì: ${bb.chuTri.isEmpty ? '……' : bb.chuTri}.'),
        doan('Thư ký: ${bb.thuKy.isEmpty ? '……' : bb.thuKy}.'),
        doan('Thành phần tham dự: ${bb.thanhPhan.isEmpty ? '……' : bb.thanhPhan}'),
        pw.SizedBox(height: 6),
        doan('II. NỘI DUNG', dam: true),
        for (final dong in bb.noiDung.split('\n').where((s) => s.trim().isNotEmpty)) doan(dong.trim()),
        pw.SizedBox(height: 6),
        doan('III. KẾT LUẬN', dam: true),
        for (final dong in bb.ketLuan.split('\n').where((s) => s.trim().isNotEmpty)) doan(dong.trim()),
        pw.SizedBox(height: 6),
        doan(_cauKetThuc()),
        pw.SizedBox(height: 18),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            for (final (chuc, ten) in [('THƯ KÝ', bb.thuKy), ('CHỦ TRÌ', bb.chuTri)])
              pw.Expanded(
                child: pw.Column(children: [
                  pw.Text(chuc, style: st(dam: true)),
                  pw.Text('(Ký, ghi rõ họ tên)', style: st(nghieng: true, size: 11)),
                  pw.SizedBox(height: 60),
                  pw.Text(ten, style: st(dam: true)),
                ]),
              ),
          ],
        ),
      ],
    ));
    final ten = 'Bien_ban_${tenTep(bb.veViec.isEmpty ? bb.loai : bb.veViec)}_${dauThoiGian(d)}.pdf';
    final f = File('${(await thuMucApp('xuat')).path}/$ten');
    await f.writeAsBytes(await doc.save());
    await guiTep([f.path], context: context);
  }

  void _bao(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  Future<void> _layTuTep() async {
    try {
      final t = await chonTep(duoiChu);
      if (t?.chu == null) return;
      final o = _o['noi_dung']!;
      setState(() => o.text = [o.text.trim(), t!.chu!].where((x) => x.isNotEmpty).join('\n'));
      _bao('Đã lấy ghi chép từ ${t!.ten}.');
    } on FormatException catch (e) {
      _bao(e.message);
    } catch (_) {
      _bao('Chưa mở được tệp, thầy cô thử lại.');
    }
  }

  Widget _o1(String khoa, String nhan, {String? goiY, int dong = 1, int toiDa = 1}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: _o[khoa],
          minLines: dong,
          maxLines: toiDa,
          decoration: InputDecoration(labelText: nhan, hintText: goiY, border: const OutlineInputBorder(), alignLabelWithHint: true),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Biên bản'),
        actions: [
          IconButton(
            tooltip: 'Chép nội dung',
            icon: const Icon(Icons.copy),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _vanBan()));
              _bao('Đã chép biên bản, dán vào Word hoặc Zalo được.');
            },
          ),
          IconButton(tooltip: 'Xuất PDF', icon: const Icon(Icons.picture_as_pdf_outlined), onPressed: _xuatPdf),
          IconButton(tooltip: 'Xóa', icon: const Icon(Icons.delete_outline), onPressed: _xoa),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          DropdownButtonFormField<String>(
            isExpanded: true,
            value: _loai,
            decoration: const InputDecoration(labelText: 'Loại cuộc họp', border: OutlineInputBorder()),
            items: [for (final l in dsLoaiHop) DropdownMenuItem(value: l, child: Text(l))],
            onChanged: (v) => setState(() => _loai = v ?? _loai),
          ),
          const SizedBox(height: 12),
          _o1('ve_viec', 'Về việc', goiY: 'Ví dụ: đánh giá hoạt động chuyên môn tháng 11'),
          InkWell(
            onTap: _chonGio,
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Bắt đầu lúc', border: OutlineInputBorder()),
              child: Text('${hai(_batDau.hour)}:${hai(_batDau.minute)}, ngày ${ngayVN(_batDau)}'),
            ),
          ),
          const SizedBox(height: 12),
          _o1('dia_diem', 'Địa điểm', goiY: 'Ví dụ: Phòng họp Hội đồng'),
          Row(
            children: [
              Expanded(child: _o1('chu_tri', 'Chủ trì (họ tên, chức vụ)')),
              const SizedBox(width: 8),
              Expanded(child: _o1('thu_ky', 'Thư ký')),
            ],
          ),
          _o1('thanh_phan', 'Thành phần tham dự', goiY: 'Ví dụ: 12/13 giáo viên tổ Toán; vắng 01 (có phép): cô …', dong: 2, toiDa: 4),
          Row(
            children: [
              const Expanded(child: Text('Diễn biến, ý kiến', style: TextStyle(fontWeight: FontWeight.w800))),
              TextButton.icon(onPressed: _noiDeGhi, icon: const Icon(Icons.mic_none, size: 18), label: const Text('Nói để ghi')),
              TextButton.icon(onPressed: _chenGio, icon: const Icon(Icons.schedule, size: 18), label: const Text('Chèn giờ')),
            ],
          ),
          const Text(
            'Mỗi ý kiến một dòng, ví dụ "Cô Lan: đề nghị tăng tiết ôn tập". Bấm "Nói để ghi" để nói thay gõ.',
            style: TextStyle(fontSize: 12, color: MauApp.chuPhu),
          ),
          const SizedBox(height: 6),
          _o1('noi_dung', 'Ghi chép', dong: 8, toiDa: 30),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _layTuTep,
                icon: const Icon(Icons.upload_file, size: 18),
                label: const Text('Lấy ghi chép từ tệp Word'),
              ),
              FilledButton.tonalIcon(
              onPressed: _dangChoAI ? null : _nhoAI,
              icon: _dangChoAI
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.auto_awesome, size: 18),
              label: const Text('Nhờ AI sắp xếp thành biên bản'),
            ),
            ],
          ),
          const SizedBox(height: 12),
          _o1('ket_luan', 'Kết luận của chủ trì', dong: 3, toiDa: 12),
          _o1('ket_thuc', 'Kết thúc lúc', goiY: 'Ví dụ: 16 giờ 30 phút'),
          const Divider(height: 28),
          const Text('Thông tin đơn vị (app tự nhớ cho lần sau)', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          TextField(controller: _donViTren, decoration: const InputDecoration(labelText: 'Cơ quan cấp trên', hintText: 'Ví dụ: UBND xã/phường (MN, TH, THCS) hoặc Sở GD&ĐT (THPT)')),
          TextField(controller: _donVi, decoration: const InputDecoration(labelText: 'Tên trường, tổ', hintText: 'Ví dụ: Trường THCS …')),
          TextField(controller: _diaDanh, decoration: const InputDecoration(labelText: 'Địa danh ghi ngày tháng', hintText: 'Ví dụ: Hà Nội')),
          const SizedBox(height: 20),
          FilledButton.icon(onPressed: _luu, icon: const Icon(Icons.check), label: const Text('Lưu biên bản')),
        ],
      ),
    );
  }
}
