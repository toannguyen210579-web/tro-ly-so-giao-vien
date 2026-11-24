import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';

import '../data/tinh_luong.dart';
import '../main.dart';
import '../services/chia_se.dart';
import '../services/tep_pdf.dart';
import '../services/tep_word.dart' show taoDocxBang;
import 'cau_giup_viec.dart';
import 'lich_nhac_han.dart';

/// Nội dung bảng lương để xuất tệp: thông tin chung, các khoản, ghi chú. Chỉ các khoản, không kèm căn cứ
/// (chốt 18/11/2026; màn hình vẫn giữ căn cứ).
class BangLuong {
  final List<String> thongTin;
  final List<(String, int)> khoan;
  final int tong;
  final int baoHiem;
  final int thucNhan;
  final String ghiChu;
  const BangLuong({
    required this.thongTin,
    required this.khoan,
    required this.tong,
    required this.baoHiem,
    required this.thucNhan,
    required this.ghiChu,
  });

  /// Bảng: dòng tiêu đề cột, các khoản, tổng, trừ bảo hiểm, thực nhận.
  List<List<String>> get bang => [
        ['STT', 'Khoản', 'Số tiền (đồng)'],
        for (var i = 0; i < khoan.length; i++) ['${i + 1}', khoan[i].$1, dinhDangTien(khoan[i].$2)],
        ['', 'Tổng thu nhập', dinhDangTien(tong)],
        ['', 'Trừ BHXH, BHYT, BHTN (10,5%)', '- ${dinhDangTien(baoHiem)}'],
        ['', 'Thực nhận (chưa tính thuế TNCN)', dinhDangTien(thucNhan)],
      ];

  Set<int> get dongDam => {khoan.length + 1, khoan.length + 3};

  static const tieuDe = 'BẢNG LƯƠNG THÁNG (THAM KHẢO)';

  String get phuDe => 'Lập ngày ${ngayVN(DateTime.now())} bằng app Trợ lý số GV, lương cơ sở ${dinhDangTien(luongCoSo)} đồng';

  static const luuY = 'Số liệu để tham khảo; số thực nhận tại trường còn tùy các phụ cấp, khoản trừ riêng và quyết định xếp lương.';

  List<int> word() => taoDocxBang(
        tieuDe: tieuDe,
        phuDe: phuDe,
        dongDau: thongTin,
        bang: bang,
        doRong: const [90, 580, 330],
        canPhai: const {2},
        dongDam: dongDam,
        dongCuoi: [ghiChu, luuY],
      );

  Future<List<int>> pdf() async {
    final doc = pw.Document(theme: await PhongPdf.theme());
    final b = bang;
    final dam = dongDam;
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(56, 42, 42, 42),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Center(child: pw.Text(tieuDe, style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold))),
          pw.SizedBox(height: 3),
          pw.Center(child: pw.Text(phuDe, style: pw.TextStyle(fontSize: 10.5, fontStyle: pw.FontStyle.italic))),
          pw.SizedBox(height: 12),
          for (final t in thongTin) pw.Padding(padding: const pw.EdgeInsets.only(bottom: 3), child: pw.Text(t, style: const pw.TextStyle(fontSize: 11.5))),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(width: 0.6),
            columnWidths: const {0: pw.FlexColumnWidth(0.9), 1: pw.FlexColumnWidth(5.8), 2: pw.FlexColumnWidth(3.3)},
            children: [
              for (var i = 0; i < b.length; i++)
                pw.TableRow(
                  decoration: i == 0 ? const pw.BoxDecoration(color: PdfColor.fromInt(0xFFE3ECF8)) : null,
                  children: [
                    for (var j = 0; j < 3; j++)
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: pw.Align(
                          alignment: i == 0 ? pw.Alignment.center : (j == 2 ? pw.Alignment.centerRight : pw.Alignment.centerLeft),
                          child: pw.Text(b[i][j],
                              style: pw.TextStyle(fontSize: 11.5, fontWeight: i == 0 || dam.contains(i) ? pw.FontWeight.bold : null)),
                        ),
                      ),
                  ],
                ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Text(ghiChu, style: pw.TextStyle(fontSize: 10.5, fontStyle: pw.FontStyle.italic)),
          pw.SizedBox(height: 3),
          pw.Text(luuY, style: pw.TextStyle(fontSize: 10.5, fontStyle: pw.FontStyle.italic)),
        ],
      ),
    ));
    return doc.save();
  }
}

const _mucUuDai = <(String, int?)>[
  ('Theo cấp dạy (mầm non, tiểu học 45%; THCS, THPT 40%)', null),
  ('THCS, THPT ở xã khu vực I, II vùng dân tộc thiểu số: 45%', 45),
  ('Vùng có điều kiện kinh tế - xã hội đặc biệt khó khăn: 70%', 70),
  ('Trường PTDTNT, phổ thông nội trú, THPT chuyên: 80%', 80),
];

const _khuVuc = [0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.7, 1.0];

class TinhLuong extends StatefulWidget {
  const TinhLuong({super.key});

  @override
  State<TinhLuong> createState() => _TinhLuongState();
}

class _TinhLuongState extends State<TinhLuong> {
  String _cap = 'THCS';
  String _hang = 'Hạng III';
  int _bac = 1;
  int _mucUD = 0;
  double _kv = 0;
  DateTime _vaoNghe = DateTime(2015, 9, 1);
  DateTime _xepBac = DateTime(2024, 9, 1);
  final _chucVu = TextEditingController(text: '0');
  final _baoLuu = TextEditingController(text: '0');
  final _vuotKhung = TextEditingController(text: '0');
  bool _dangXuat = false;

  /// Hỏi kiểu tệp (Word để sửa, PDF để in, gửi), lưu vào máy rồi báo chỗ lưu kèm nút gửi.
  Future<void> _xuat(BangLuong b) async {
    final kieu = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text('Xuất bảng lương', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined, color: Color(0xFF2353D6)),
            title: const Text('Tệp Word'),
            subtitle: const Text('Sửa thêm được, in hoặc gửi kèm hồ sơ'),
            onTap: () => Navigator.pop(c, 'word'),
          ),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_outlined, color: Color(0xFFA3241C)),
            title: const Text('Tệp PDF'),
            subtitle: const Text('Xem, in, gửi Zalo giữ nguyên trình bày'),
            onTap: () => Navigator.pop(c, 'pdf'),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (kieu == null || !mounted) return;
    setState(() => _dangXuat = true);
    try {
      final duoi = kieu == 'word' ? 'docx' : 'pdf';
      final f = File('${(await thuMucApp('xuat')).path}/Bang_luong_${dauThoiGian(DateTime.now())}.$duoi');
      await f.writeAsBytes(kieu == 'word' ? b.word() : await b.pdf(), flush: true);
      if (!mounted) return;
      setState(() => _dangXuat = false);
      await baoDaLuuTep(context, f, tieuDe: 'Đã xuất bảng lương');
    } catch (_) {
      if (mounted) {
        setState(() => _dangXuat = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chưa xuất được bảng lương, thầy cô thử lại.')));
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _tai();
  }

  Future<void> _tai() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _cap = p.getString('l_cap') ?? _cap;
      _hang = p.getString('l_hang') ?? _hang;
      _bac = p.getInt('l_bac') ?? _bac;
      _mucUD = p.getInt('l_ud') ?? _mucUD;
      _kv = p.getDouble('l_kv') ?? _kv;
      _vaoNghe = DateTime.tryParse(p.getString('l_vao') ?? '') ?? _vaoNghe;
      _xepBac = DateTime.tryParse(p.getString('l_xep') ?? '') ?? _xepBac;
      _chucVu.text = p.getString('l_cv') ?? '0';
      _baoLuu.text = p.getString('l_bl') ?? '0';
      _vuotKhung.text = p.getString('l_vk') ?? '0';
      final n = ngachCua(_cap, _hang);
      if (_bac > n.soBac) _bac = n.soBac;
    });
  }

  Future<void> _luu() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('l_cap', _cap);
    await p.setString('l_hang', _hang);
    await p.setInt('l_bac', _bac);
    await p.setInt('l_ud', _mucUD);
    await p.setDouble('l_kv', _kv);
    await p.setString('l_vao', _vaoNghe.toIso8601String());
    await p.setString('l_xep', _xepBac.toIso8601String());
    await p.setString('l_cv', _chucVu.text);
    await p.setString('l_bl', _baoLuu.text);
    await p.setString('l_vk', _vuotKhung.text);
  }

  @override
  void dispose() {
    _chucVu.dispose();
    _baoLuu.dispose();
    _vuotKhung.dispose();
    super.dispose();
  }

  double _so(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '.')) ?? 0;

  Future<void> _chonNgay(bool vaoNghe) async {
    final d = await showDatePicker(
      context: context,
      initialDate: vaoNghe ? _vaoNghe : _xepBac,
      firstDate: DateTime(1970),
      lastDate: DateTime(2100),
      helpText: vaoNghe ? 'Ngày bắt đầu dạy, có đóng BHXH' : 'Ngày hưởng bậc lương hiện tại',
    );
    if (d == null) return;
    setState(() {
      if (vaoNghe) {
        _vaoNghe = d;
      } else {
        _xepBac = d;
      }
    });
    _luu();
  }

  @override
  Widget build(BuildContext context) {
    final ngach = ngachCua(_cap, _hang);
    final heSo = ngach.heSo(_bac);
    final soNam = soNamTron(_vaoNghe, DateTime.now());
    final tn = phanTramThamNien(soNam);
    final ud = _mucUuDai[_mucUD].$2 ?? uuDaiMacDinh(_cap);
    final kq = tinhLuong(
      heSo: heSo,
      heSoBaoLuu: _so(_baoLuu),
      heSoChucVu: _so(_chucVu),
      heSoKhuVuc: _kv,
      phanTramVuotKhung: _so(_vuotKhung).round(),
      phanTramUuDai: ud,
      phanTramThamNienNghe: tn,
    );
    final bacCuoi = _bac >= ngach.soBac;
    final cauThamNien = soNam < 5
        ? 'Phụ cấp thâm niên 5% bắt đầu từ ${ngayVN(DateTime(_vaoNghe.year + 5, _vaoNghe.month, _vaoNghe.day))}.'
        : 'Phụ cấp thâm niên lên ${tn + 1}% từ ${ngayVN(DateTime(_vaoNghe.year + soNam + 1, _vaoNghe.month, _vaoNghe.day))}.';
    final nangBac = ngayNangBacKe(_xepBac);

    Widget dong(String a, int v, {bool dam = false, Color? mau}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Expanded(child: Text(a, style: TextStyle(fontWeight: dam ? FontWeight.w800 : FontWeight.w500))),
            Text('${dinhDangTien(v)} đ',
                style: TextStyle(fontWeight: dam ? FontWeight.w900 : FontWeight.w600, color: mau, fontSize: dam ? 18 : 15)),
          ]),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Tính lương')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          const CauGiupViec('luong'),
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                value: _cap,
                decoration: const InputDecoration(labelText: 'Cấp dạy', border: OutlineInputBorder()),
                items: [for (final c in capDay) DropdownMenuItem(value: c, child: Text(c))],
                onChanged: (v) => setState(() {
                  _cap = v ?? _cap;
                  _bac = _bac.clamp(1, ngachCua(_cap, _hang).soBac);
                  _luu();
                }),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                value: _hang,
                decoration: const InputDecoration(labelText: 'Hạng', border: OutlineInputBorder()),
                items: [for (final h in hangGV) DropdownMenuItem(value: h, child: Text(h))],
                onChanged: (v) => setState(() {
                  _hang = v ?? _hang;
                  _bac = _bac.clamp(1, ngachCua(_cap, _hang).soBac);
                  _luu();
                }),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            isExpanded: true,
            value: _bac,
            decoration: InputDecoration(labelText: 'Bậc lương (hệ số ${ngach.ma})', border: const OutlineInputBorder()),
            items: [
              for (var b = 1; b <= ngach.soBac; b++)
                DropdownMenuItem(value: b, child: Text('Bậc $b · hệ số ${ngach.heSo(b).toStringAsFixed(2).replaceAll('.', ',')}')),
            ],
            onChanged: (v) => setState(() {
              _bac = v ?? _bac;
              _luu();
            }),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: _mucUD,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Phụ cấp ưu đãi theo nghề', border: OutlineInputBorder()),
            items: [for (var i = 0; i < _mucUuDai.length; i++) DropdownMenuItem(value: i, child: Text(_mucUuDai[i].$1, overflow: TextOverflow.ellipsis))],
            onChanged: (v) => setState(() {
              _mucUD = v ?? 0;
              _luu();
            }),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: InkWell(
                onTap: () => _chonNgay(true),
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Bắt đầu dạy (có BHXH)', border: OutlineInputBorder()),
                  child: Text('${ngayVN(_vaoNghe)} · $soNam năm'),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: InkWell(
                onTap: () => _chonNgay(false),
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Hưởng bậc hiện tại từ', border: OutlineInputBorder()),
                  child: Text(ngayVN(_xepBac)),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Phụ cấp khác (nếu có)', style: TextStyle(fontWeight: FontWeight.w700)),
            children: [
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _chucVu,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) {
                      setState(() {});
                      _luu();
                    },
                    decoration: const InputDecoration(labelText: 'Hệ số phụ cấp chức vụ', hintText: 'Tổ trưởng 0,2'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _baoLuu,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) {
                      setState(() {});
                      _luu();
                    },
                    decoration: const InputDecoration(labelText: 'Hệ số chênh lệch bảo lưu'),
                  ),
                ),
              ]),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _vuotKhung,
                    keyboardType: TextInputType.number,
                    onChanged: (_) {
                      setState(() {});
                      _luu();
                    },
                    decoration: const InputDecoration(labelText: 'Thâm niên vượt khung (%)'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<double>(
                    isExpanded: true,
                    value: _khuVuc.contains(_kv) ? _kv : 0,
                    decoration: const InputDecoration(labelText: 'Hệ số phụ cấp khu vực'),
                    items: [for (final k in _khuVuc) DropdownMenuItem(value: k, child: Text(k == 0 ? 'Không' : k.toString().replaceAll('.', ',')))],
                    onChanged: (v) => setState(() {
                      _kv = v ?? 0;
                      _luu();
                    }),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Lương tháng · hệ số ${heSo.toStringAsFixed(2).replaceAll('.', ',')} × ${dinhDangTien(luongCoSo)} đ',
                    style: const TextStyle(color: MauApp.chuPhu, fontSize: 12.5)),
                const SizedBox(height: 6),
                dong('Lương theo hệ số', kq.luongHeSo),
                if (kq.phuCapChucVu > 0) dong('Phụ cấp chức vụ', kq.phuCapChucVu),
                if (kq.chenhLechBaoLuu > 0) dong('Chênh lệch bảo lưu', kq.chenhLechBaoLuu),
                if (kq.thamNienVuotKhung > 0) dong('Thâm niên vượt khung', kq.thamNienVuotKhung),
                dong('Phụ cấp ưu đãi $ud%', kq.uuDai),
                dong(tn > 0 ? 'Phụ cấp thâm niên $tn%' : 'Phụ cấp thâm niên (chưa đủ 5 năm)', kq.thamNien),
                if (kq.khuVuc > 0) dong('Phụ cấp khu vực', kq.khuVuc),
                const Divider(),
                dong('Tổng thu nhập', kq.tongThuNhap, dam: true),
                dong('Trừ BHXH, BHYT, BHTN (10,5%)', -kq.baoHiem, mau: const Color(0xFFA3241C)),
                const Divider(),
                dong('Thực nhận (chưa tính thuế TNCN)', kq.thucNhan, dam: true, mau: MauApp.xanhLa),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFFE3ECF8), borderRadius: BorderRadius.circular(14)),
            child: Text(
              bacCuoi
                  ? 'Thầy cô đang ở bậc cuối của hạng. Đủ 3 năm ở bậc cuối (từ ${ngayVN(nangBac)}) thì được xét thâm niên vượt khung 5%, sau đó mỗi năm thêm 1%.'
                  : 'Nâng bậc kế tiếp (bậc ${_bac + 1}, hệ số ${ngach.heSo(_bac + 1).toStringAsFixed(2).replaceAll('.', ',')}) dự kiến từ ${ngayVN(nangBac)}, '
                      'nếu đủ 3 năm hoàn thành nhiệm vụ, không bị kỷ luật. $cauThamNien',
              style: const TextStyle(height: 1.4),
            ),
          ),
          if (!bacCuoi && nangBac.isAfter(DateTime.now()))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => LichNhacHan(tenMoi: 'Nâng bậc lương lên bậc ${_bac + 1}', hanMoi: DateTime(nangBac.year, nangBac.month, nangBac.day, 8)),
                )),
                icon: const Icon(Icons.event_available_outlined),
                label: const Text('Nhắc ngày nâng bậc vào Lịch'),
              ),
            ),
          const SizedBox(height: 12),
          // Thay nút Chép kết quả (thầy cô thấy không rõ chép để làm gì, 24/11/2026): xuất ra văn bản
          FilledButton.icon(
            onPressed: _dangXuat
                ? null
                : () => _xuat(BangLuong(
                      thongTin: [
                        'Giáo viên $_cap, $_hang, bậc $_bac, hệ số ${heSo.toStringAsFixed(2).replaceAll('.', ',')}.',
                        'Bắt đầu dạy (có đóng BHXH): ${ngayVN(_vaoNghe)}, $soNam năm. Hưởng bậc hiện tại từ ${ngayVN(_xepBac)}.',
                        'Phụ cấp ưu đãi theo nghề $ud%; phụ cấp thâm niên nhà giáo $tn%.',
                      ],
                      khoan: [
                        ('Lương theo hệ số', kq.luongHeSo),
                        if (kq.phuCapChucVu > 0) ('Phụ cấp chức vụ', kq.phuCapChucVu),
                        if (kq.chenhLechBaoLuu > 0) ('Chênh lệch bảo lưu', kq.chenhLechBaoLuu),
                        if (kq.thamNienVuotKhung > 0) ('Thâm niên vượt khung', kq.thamNienVuotKhung),
                        ('Phụ cấp ưu đãi $ud%', kq.uuDai),
                        (tn > 0 ? 'Phụ cấp thâm niên $tn%' : 'Phụ cấp thâm niên (chưa đủ 5 năm)', kq.thamNien),
                        if (kq.khuVuc > 0) ('Phụ cấp khu vực', kq.khuVuc),
                      ],
                      tong: kq.tongThuNhap,
                      baoHiem: kq.baoHiem,
                      thucNhan: kq.thucNhan,
                      ghiChu: bacCuoi
                          ? 'Đang ở bậc cuối của hạng; đủ 3 năm ở bậc cuối (từ ${ngayVN(nangBac)}) được xét thâm niên vượt khung 5%.'
                          : 'Nâng bậc kế tiếp (bậc ${_bac + 1}, hệ số ${ngach.heSo(_bac + 1).toStringAsFixed(2).replaceAll('.', ',')}) dự kiến từ ${ngayVN(nangBac)}.',
                    )),
            icon: _dangXuat
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.description_outlined),
            label: const Text('Xuất bảng lương ra văn bản'),
          ),
          const SizedBox(height: 16),
          Text('Căn cứ (cập nhật $ngayCapNhatLuong)', style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          for (final c in canCuLuong)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('• $c', style: const TextStyle(fontSize: 12.5, color: MauApp.chuPhu, height: 1.35)),
            ),
          const SizedBox(height: 8),
          const Text(
            'Kết quả để tham khảo. Số thực nhận tại trường còn tùy phụ cấp thu hút, trách nhiệm, các khoản trừ khác và quyết định xếp lương của thầy cô. '
            'Hệ số lương đặc thù của nhà giáo hiện mới là dự thảo nên chưa tính.',
            style: TextStyle(fontSize: 12, color: MauApp.chuPhu, height: 1.35),
          ),
        ],
      ),
    );
  }
}
