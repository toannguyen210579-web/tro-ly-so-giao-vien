import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/cham_diem.dart';
import '../data/luu_tru.dart';
import '../main.dart';
import '../services/tep_pdf.dart';
import 'cau_giup_viec.dart';
import '../services/chia_se.dart';

const _khoa = khoaChamTracNghiem;

/// Chấm trắc nghiệm: nhập đáp án từng mã đề, nhập bài làm của học sinh
/// (chạm ô hoặc gõ nhanh), app tính điểm, thống kê và xuất bảng điểm.
class ChamTracNghiem extends StatefulWidget {
  const ChamTracNghiem({super.key});

  @override
  State<ChamTracNghiem> createState() => _ChamTracNghiemState();
}

class _ChamTracNghiemState extends State<ChamTracNghiem> {
  List<DeThi> _ds = [];

  @override
  void initState() {
    super.initState();
    _tai();
  }

  Future<void> _tai() async {
    final ds = (await LuuTru.docDanhSach(_khoa)).map(DeThi.fromJson).toList();
    if (mounted) setState(() => _ds = ds);
  }

  Future<void> _luu() async {
    await LuuTru.ghiDanhSach(_khoa, _ds.map((e) => e.toJson()).toList());
    if (mounted) setState(() {});
  }

  Future<void> _taoDe() async {
    final ten = TextEditingController();
    final soCau = TextEditingController(text: '40');
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Bài kiểm tra mới'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ten,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Tên bài', hintText: 'Ví dụ: Kiểm tra giữa kỳ I, Toán 9A'),
            ),
            TextField(
              controller: soCau,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Số câu'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Thôi')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Tạo')),
        ],
      ),
    );
    final n = int.tryParse(soCau.text.trim()) ?? 0;
    if (ok != true) return;
    if (ten.text.trim().isEmpty || n < 1 || n > 200) {
      _bao('Thầy cô ghi tên bài và số câu từ 1 đến 200.');
      return;
    }
    final de = DeThi(id: DateTime.now().microsecondsSinceEpoch.toString(), ten: ten.text.trim(), soCau: n);
    _ds.insert(0, de);
    await _luu();
    if (mounted) _moDe(de);
  }

  Future<void> _moDe(DeThi de) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => _ManDe(de: de, luu: _luu)));
    if (mounted) setState(() {});
  }

  Future<void> _xoaDe(DeThi de) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Xóa "${de.ten}"?'),
        content: const Text('Đáp án và điểm của bài này sẽ bị xóa khỏi máy.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Thôi')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Xóa')),
        ],
      ),
    );
    if (ok != true) return;
    _ds.remove(de);
    await _luu();
  }

  void _bao(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chấm trắc nghiệm')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _taoDe,
        icon: const Icon(Icons.add),
        label: const Text('Bài kiểm tra mới'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        children: [
          const CauGiupViec('cham_tn'),
          const Text(
            'Bước 1: tạo bài, nhập đáp án từng mã đề. Bước 2: nhập bài làm của từng em bằng cách chạm ô '
            'hoặc gõ nhanh chuỗi đáp án. App tự tính điểm thang 10 và thống kê cả lớp.',
            style: TextStyle(fontSize: 12.5, color: MauApp.chuPhu),
          ),
          const SizedBox(height: 12),
          if (_ds.isEmpty)
            const Padding(padding: EdgeInsets.only(top: 32), child: Center(child: Text('Chưa có bài kiểm tra nào.'))),
          for (final de in _ds)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                onTap: () => _moDe(de),
                leading: const Icon(Icons.checklist_outlined, color: MauApp.xanhLa),
                title: Text(de.ten),
                subtitle: Text('${de.soCau} câu · ${de.dapAn.length} mã đề · ${de.baiLam.length} bài đã chấm'),
                trailing: IconButton(tooltip: 'Xóa', icon: const Icon(Icons.delete_outline), onPressed: () => _xoaDe(de)),
              ),
            ),
        ],
      ),
    );
  }
}

class _ManDe extends StatefulWidget {
  final DeThi de;
  final Future<void> Function() luu;
  const _ManDe({required this.de, required this.luu});

  @override
  State<_ManDe> createState() => _ManDeState();
}

class _ManDeState extends State<_ManDe> {
  DeThi get de => widget.de;

  Future<void> _suaDapAn([String? ma]) async {
    final kq = await Navigator.of(context).push<(String, String)>(
      MaterialPageRoute(
        builder: (_) => _NhapDapAn(
          tieuDe: ma == null ? 'Đáp án mã đề mới' : 'Đáp án mã đề $ma',
          soCau: de.soCau,
          ma: ma,
          dapAnGoc: ma == null ? null : de.dapAn[ma],
          laDapAn: true,
          dsMa: const [],
        ),
      ),
    );
    if (kq == null) return;
    final (maMoi, chuoi) = kq;
    if (ma != null && ma != maMoi) {
      de.dapAn.remove(ma);
      for (final b in de.baiLam.where((b) => b.maDe == ma)) {
        b.maDe = maMoi;
      }
    }
    de.dapAn[maMoi] = chuoi;
    await widget.luu();
    setState(() {});
  }

  Future<void> _xoaMa(String ma) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Xóa đáp án mã đề $ma?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Thôi')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Xóa')),
        ],
      ),
    );
    if (ok != true) return;
    de.dapAn.remove(ma);
    await widget.luu();
    setState(() {});
  }

  Future<void> _chamBai([BaiLam? goc]) async {
    if (de.dapAn.isEmpty) {
      _bao('Thầy cô nhập đáp án ít nhất một mã đề trước.');
      return;
    }
    final kq = await Navigator.of(context).push<(String, String, String)>(
      MaterialPageRoute(
        builder: (_) => _NhapDapAn(
          tieuDe: goc == null ? 'Chấm bài mới' : 'Sửa bài của ${goc.ten}',
          soCau: de.soCau,
          ma: goc?.maDe ?? de.dapAn.keys.first,
          dapAnGoc: goc?.traLoi,
          tenGoc: goc?.ten,
          laDapAn: false,
          dsMa: de.dapAn.keys.toList(),
          dapAnTheoMa: de.dapAn,
          sttMoi: de.baiLam.length + 1,
        ),
      ),
    );
    if (kq == null) return;
    final (ma, chuoi, ten) = kq;
    if (goc == null) {
      de.baiLam.add(BaiLam(ten: ten, maDe: ma, traLoi: chuoi));
    } else {
      goc
        ..ten = ten
        ..maDe = ma
        ..traLoi = chuoi;
    }
    await widget.luu();
    setState(() {});
    if (goc == null && mounted) _chamBai();
  }

  Future<void> _xoaBai(BaiLam b) async {
    de.baiLam.remove(b);
    await widget.luu();
    setState(() {});
  }

  String _bangTab() {
    final b = StringBuffer('STT\tHọ và tên\tMã đề\tSố câu đúng\tĐiểm\n');
    for (var i = 0; i < de.baiLam.length; i++) {
      final bl = de.baiLam[i];
      final d = de.dapAn[bl.maDe];
      b.write('${i + 1}\t${bl.ten}\t${bl.maDe}\t${d == null ? '' : soCauDung(d, bl.traLoi)}\t'
          '${d == null ? '' : hienDiem(diemThang10(d, bl.traLoi))}\n');
    }
    return b.toString();
  }

  Future<void> _guiCsv() async {
    final b = StringBuffer('﻿STT,Họ và tên,Mã đề,Số câu đúng,Điểm\n');
    for (var i = 0; i < de.baiLam.length; i++) {
      final bl = de.baiLam[i];
      final d = de.dapAn[bl.maDe];
      final ten = bl.ten.replaceAll('"', '""');
      b.write('${i + 1},"$ten",${bl.maDe},${d == null ? '' : soCauDung(d, bl.traLoi)},'
          '"${d == null ? '' : hienDiem(diemThang10(d, bl.traLoi))}"\n');
    }
    final f = File('${(await thuMucApp('xuat')).path}/Diem_${tenTep(de.ten)}_${dauThoiGian(DateTime.now())}.csv');
    await f.writeAsString(b.toString());
    await guiTep([f.path], context: context);
  }

  void _bao(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(de.ten),
          bottom: const TabBar(tabs: [Tab(text: 'Đáp án'), Tab(text: 'Chấm bài'), Tab(text: 'Thống kê')]),
        ),
        body: TabBarView(children: [_tabDapAn(), _tabChamBai(), _tabThongKe()]),
      ),
    );
  }

  Widget _tabDapAn() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('${de.soCau} câu. Mỗi mã đề một dãy đáp án.', style: const TextStyle(color: MauApp.chuPhu)),
        const SizedBox(height: 8),
        for (final ma in de.dapAn.keys)
          Card(
            child: ListTile(
              onTap: () => _suaDapAn(ma),
              title: Text('Mã đề $ma'),
              subtitle: Text(de.dapAn[ma]!, style: const TextStyle(fontFamily: 'monospace', letterSpacing: 1)),
              trailing: IconButton(tooltip: 'Xóa', icon: const Icon(Icons.delete_outline), onPressed: () => _xoaMa(ma)),
            ),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: () => _suaDapAn(), icon: const Icon(Icons.add), label: const Text('Thêm mã đề')),
      ],
    );
  }

  Widget _tabChamBai() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FilledButton.icon(onPressed: () => _chamBai(), icon: const Icon(Icons.edit_note), label: const Text('Chấm bài mới')),
        const SizedBox(height: 8),
        if (de.baiLam.isNotEmpty)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _bangTab()));
                    _bao('Đã chép bảng điểm, dán thẳng vào Excel được.');
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Chép sang Excel'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(onPressed: _guiCsv, icon: const Icon(Icons.ios_share), label: const Text('Gửi tệp')),
              ),
            ],
          ),
        const SizedBox(height: 8),
        if (de.baiLam.isEmpty) const Padding(padding: EdgeInsets.only(top: 24), child: Center(child: Text('Chưa chấm bài nào.'))),
        for (var i = 0; i < de.baiLam.length; i++)
          Builder(builder: (_) {
            final b = de.baiLam[i];
            final d = de.diemCua(b);
            return Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                onTap: () => _chamBai(b),
                leading: CircleAvatar(child: Text('${i + 1}')),
                title: Text(b.ten),
                subtitle: Text('Mã đề ${b.maDe}'
                    '${de.dapAn[b.maDe] == null ? ' (chưa có đáp án)' : ' · đúng ${soCauDung(de.dapAn[b.maDe]!, b.traLoi)}/${soCauTinh(de.dapAn[b.maDe]!)} câu'}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(d == null ? '–' : hienDiem(d),
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: (d ?? 0) >= 5 ? MauApp.xanhLa : const Color(0xFFA3241C))),
                    IconButton(tooltip: 'Xóa', icon: const Icon(Icons.delete_outline), onPressed: () => _xoaBai(b)),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _tabThongKe() {
    final diem = de.baiLam.map(de.diemCua).whereType<double>().toList();
    if (diem.isEmpty) return const Center(child: Text('Chấm vài bài để xem thống kê.'));
    final tb = diem.reduce((a, b) => a + b) / diem.length;
    final nhom = <String, int>{
      'Dưới 5': diem.where((d) => d < 5).length,
      'Từ 5 đến dưới 6,5': diem.where((d) => d >= 5 && d < 6.5).length,
      'Từ 6,5 đến dưới 8': diem.where((d) => d >= 6.5 && d < 8).length,
      'Từ 8 trở lên': diem.where((d) => d >= 8).length,
    };
    // Câu sai nhiều nhất (tính theo thứ tự câu trên từng mã đề).
    final sai = <String, int>{};
    for (final b in de.baiLam) {
      final d = de.dapAn[b.maDe];
      if (d == null) continue;
      for (var i = 0; i < d.length; i++) {
        if (d[i] != '-' && (i >= b.traLoi.length || b.traLoi[i] != d[i])) {
          final k = 'Câu ${i + 1} (mã ${b.maDe})';
          sai[k] = (sai[k] ?? 0) + 1;
        }
      }
    }
    final saiNhieu = sai.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    Widget dong(String a, String b) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [Expanded(child: Text(a)), Text(b, style: const TextStyle(fontWeight: FontWeight.w700))]),
        );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        dong('Số bài đã chấm', '${diem.length}'),
        dong('Điểm trung bình', hienDiem((tb * 100).round() / 100)),
        dong('Cao nhất', hienDiem(diem.reduce((a, b) => a > b ? a : b))),
        dong('Thấp nhất', hienDiem(diem.reduce((a, b) => a < b ? a : b))),
        const Divider(height: 24),
        for (final e in nhom.entries)
          dong(e.key, '${e.value} bài (${(e.value * 100 / diem.length).toStringAsFixed(0)}%)'),
        const Divider(height: 24),
        const Text('Câu nhiều em làm sai', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        for (final e in saiNhieu.take(8)) dong(e.key, '${e.value} em sai'),
      ],
    );
  }
}

/// Nhập một dãy đáp án: dùng cho cả đáp án mã đề và bài làm học sinh.
class _NhapDapAn extends StatefulWidget {
  final String tieuDe;
  final int soCau;
  final String? ma;
  final String? dapAnGoc;
  final String? tenGoc;
  final bool laDapAn;
  final List<String> dsMa;
  final Map<String, String>? dapAnTheoMa;
  final int? sttMoi;

  const _NhapDapAn({
    required this.tieuDe,
    required this.soCau,
    required this.ma,
    required this.dapAnGoc,
    required this.laDapAn,
    required this.dsMa,
    this.tenGoc,
    this.dapAnTheoMa,
    this.sttMoi,
  });

  @override
  State<_NhapDapAn> createState() => _NhapDapAnState();
}

class _NhapDapAnState extends State<_NhapDapAn> {
  late List<String> _chon;
  late final TextEditingController _ma;
  late final TextEditingController _ten;
  final _goNhanh = TextEditingController();
  String? _maChon;

  @override
  void initState() {
    super.initState();
    final goc = widget.dapAnGoc ?? ''.padRight(widget.soCau, '-');
    _chon = goc.padRight(widget.soCau, '-').substring(0, widget.soCau).split('');
    _ma = TextEditingController(text: widget.ma ?? '');
    _ten = TextEditingController(text: widget.tenGoc ?? (widget.sttMoi == null ? '' : 'Học sinh ${widget.sttMoi}'));
    _maChon = widget.ma;
  }

  @override
  void dispose() {
    _ma.dispose();
    _ten.dispose();
    _goNhanh.dispose();
    super.dispose();
  }

  String get _chuoi => _chon.join();

  String? get _dapAnSoSanh => widget.laDapAn ? null : widget.dapAnTheoMa?[_maChon];

  void _apGoNhanh(String s) {
    setState(() => _chon = chuanHoaDapAn(s, widget.soCau).split(''));
  }

  void _luu() {
    if (widget.laDapAn) {
      final ma = _ma.text.trim();
      if (ma.isEmpty) {
        _bao('Thầy cô ghi mã đề, ví dụ 101.');
        return;
      }
      final thieu = _chon.where((c) => c == '-').length;
      if (thieu > 0) _bao('Lưu ý: còn $thieu câu chưa có đáp án, các câu này không tính điểm.');
      Navigator.of(context).pop((ma, _chuoi));
    } else {
      final ten = _ten.text.trim();
      if (ten.isEmpty || _maChon == null) {
        _bao('Thầy cô ghi tên học sinh và chọn mã đề.');
        return;
      }
      Navigator.of(context).pop((_maChon!, _chuoi, ten));
    }
  }

  void _bao(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  @override
  Widget build(BuildContext context) {
    final ss = _dapAnSoSanh;
    return Scaffold(
      appBar: AppBar(title: Text(widget.tieuDe)),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              if (ss != null)
                Expanded(
                  child: Text(
                    'Đúng ${soCauDung(ss, _chuoi)}/${soCauTinh(ss)} · ${hienDiem(diemThang10(ss, _chuoi))} điểm',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: MauApp.xanhLa),
                  ),
                )
              else
                const Spacer(),
              FilledButton.icon(
                onPressed: _luu,
                icon: const Icon(Icons.check),
                label: Text(widget.laDapAn ? 'Lưu đáp án' : 'Lưu, chấm em tiếp'),
              ),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        children: [
          if (widget.laDapAn)
            TextField(controller: _ma, decoration: const InputDecoration(labelText: 'Mã đề', border: OutlineInputBorder()))
          else ...[
            TextField(controller: _ten, decoration: const InputDecoration(labelText: 'Họ và tên học sinh', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              children: [
                const Padding(padding: EdgeInsets.only(top: 8), child: Text('Mã đề: ')),
                for (final m in widget.dsMa)
                  ChoiceChip(label: Text(m), selected: _maChon == m, onSelected: (_) => setState(() => _maChon = m)),
              ],
            ),
          ],
          const SizedBox(height: 10),
          TextField(
            controller: _goNhanh,
            onChanged: _apGoNhanh,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Gõ nhanh cả dãy (không bắt buộc)',
              hintText: 'Ví dụ: ABCDA BBCDA… hoặc 1234…; câu bỏ trống gõ dấu -',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          const Text('Hoặc chạm chọn từng câu:', style: TextStyle(color: MauApp.chuPhu)),
          const SizedBox(height: 6),
          for (var i = 0; i < widget.soCau; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  SizedBox(
                    width: 44,
                    child: Text('${i + 1}.', style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: ss == null || ss[i] == '-'
                          ? MauApp.chu
                          : (ss[i] == _chon[i] ? MauApp.xanhLa : const Color(0xFFA3241C)),
                    )),
                  ),
                  for (final c in chuLuaChon)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => setState(() => _chon[i] = _chon[i] == c ? '-' : c),
                        child: Container(
                          width: 38,
                          height: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _chon[i] == c ? MauApp.xanhDam : Colors.white,
                            border: Border.all(color: _chon[i] == c ? MauApp.xanhDam : const Color(0xFFC5CED9)),
                          ),
                          child: Text(c, style: TextStyle(fontWeight: FontWeight.w700, color: _chon[i] == c ? Colors.white : MauApp.chu)),
                        ),
                      ),
                    ),
                  if (ss != null && ss[i] != '-' && ss[i] != _chon[i])
                    Text('đ/a ${ss[i]}', style: const TextStyle(fontSize: 12, color: MauApp.chuPhu)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
