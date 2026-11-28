import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/cham_diem.dart';
import '../data/luu_tru.dart';
import '../main.dart';
import '../services/tep_pdf.dart';
import 'cau_giup_viec.dart';
import '../services/chia_se.dart';
import '../quoc_te/quoc_te.dart';

/// Điểm hiện trên màn: bản Việt thang 10, bản quốc tế theo phần trăm.
String _hd(double d) => laQuocTe ? '${(d * 10).round()}%' : hienDiem(d);

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
        title: Text(tx('Bài kiểm tra mới', 'newQuiz')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ten,
              autofocus: true,
              decoration: InputDecoration(labelText: tx('Tên bài', 'quizName'), hintText: laQuocTe ? null : 'Ví dụ: Kiểm tra giữa kỳ I, Toán 9A'),
            ),
            TextField(
              controller: soCau,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: tx('Số câu', 'numQuestions')),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tx('Thôi', 'cancel'))),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tx('Tạo', 'create'))),
        ],
      ),
    );
    final n = int.tryParse(soCau.text.trim()) ?? 0;
    if (ok != true) return;
    if (ten.text.trim().isEmpty || n < 1 || n > 200) {
      _bao(tx('Thầy cô ghi tên bài và số câu từ 1 đến 200.', 'qzErrNew'));
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
        title: Text(tx('Xóa "${de.ten}"?', 'deleteX', m: de.ten)),
        content: Text(tx('Đáp án và điểm của bài này sẽ bị xóa khỏi máy.', 'qzDeleteNote')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tx('Thôi', 'cancel'))),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tx('Xóa', 'delete'))),
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
      appBar: AppBar(title: Text(tx('Chấm trắc nghiệm', 'quizGrader'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _taoDe,
        icon: const Icon(Icons.add),
        label: Text(tx('Bài kiểm tra mới', 'newQuiz')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        children: [
          if (laQuocTe) const SizedBox(height: 12) else const CauGiupViec('cham_tn'),
          Text(
            tx(
                'Bước 1: tạo bài, nhập đáp án từng mã đề. Bước 2: nhập bài làm của từng em bằng cách chạm ô '
                    'hoặc gõ nhanh chuỗi đáp án. App tự tính điểm thang 10 và thống kê cả lớp.',
                'qzHint'),
            style: const TextStyle(fontSize: 12.5, color: MauApp.chuPhu),
          ),
          const SizedBox(height: 12),
          if (_ds.isEmpty)
            Padding(padding: const EdgeInsets.only(top: 32), child: Center(child: Text(tx('Chưa có bài kiểm tra nào.', 'qzNone')))),
          for (final de in _ds)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                onTap: () => _moDe(de),
                leading: const Icon(Icons.checklist_outlined, color: MauApp.xanhLa),
                title: Text(de.ten),
                subtitle: Text(laQuocTe
                    ? '${chu('qzQuestions', n: de.soCau)} · ${chu('qzVersions', n: de.dapAn.length)} · ${chu('qzGraded', n: de.baiLam.length)}'
                    : '${de.soCau} câu · ${de.dapAn.length} mã đề · ${de.baiLam.length} bài đã chấm'),
                trailing: IconButton(tooltip: tx('Xóa', 'delete'), icon: const Icon(Icons.delete_outline), onPressed: () => _xoaDe(de)),
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
          tieuDe: ma == null ? tx('Đáp án mã đề mới', 'keyNew') : tx('Đáp án mã đề $ma', 'keyFor', m: ma),
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
        title: Text(tx('Xóa đáp án mã đề $ma?', 'deleteKeyX', m: ma)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tx('Thôi', 'cancel'))),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tx('Xóa', 'delete'))),
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
      _bao(tx('Thầy cô nhập đáp án ít nhất một mã đề trước.', 'qzNeedKey'));
      return;
    }
    final kq = await Navigator.of(context).push<(String, String, String)>(
      MaterialPageRoute(
        builder: (_) => _NhapDapAn(
          tieuDe: goc == null ? tx('Chấm bài mới', 'gradeNew') : tx('Sửa bài của ${goc.ten}', 'editPaper', m: goc.ten),
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
    final b = StringBuffer(laQuocTe
        ? '#\t${chu('name')}\t${chu('version')}\t${chu('correctCount')}\t${chu('scoreCol')}\n'
        : 'STT\tHọ và tên\tMã đề\tSố câu đúng\tĐiểm\n');
    for (var i = 0; i < de.baiLam.length; i++) {
      final bl = de.baiLam[i];
      final d = de.dapAn[bl.maDe];
      b.write('${i + 1}\t${bl.ten}\t${bl.maDe}\t${d == null ? '' : soCauDung(d, bl.traLoi)}\t'
          '${d == null ? '' : _hd(diemThang10(d, bl.traLoi))}\n');
    }
    return b.toString();
  }

  Future<void> _guiCsv() async {
    final b = StringBuffer(laQuocTe
        ? '\uFEFF#,${chu('name')},${chu('version')},${chu('correctCount')},${chu('scoreCol')}\n'
        : '\uFEFFSTT,Họ và tên,Mã đề,Số câu đúng,Điểm\n');
    for (var i = 0; i < de.baiLam.length; i++) {
      final bl = de.baiLam[i];
      final d = de.dapAn[bl.maDe];
      final ten = bl.ten.replaceAll('"', '""');
      b.write('${i + 1},"$ten",${bl.maDe},${d == null ? '' : soCauDung(d, bl.traLoi)},'
          '"${d == null ? '' : _hd(diemThang10(d, bl.traLoi))}"\n');
    }
    final f = File('${(await thuMucApp('xuat')).path}/Diem_${tenTep(de.ten)}_${dauThoiGian(DateTime.now())}.csv');
    await f.writeAsString(b.toString());
    if (!mounted) return;
    await baoDaLuuTep(context, f, tieuDe: tx('Đã lưu bảng điểm', 'fileSaved'));
  }

  void _bao(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(de.ten),
          bottom: TabBar(tabs: [Tab(text: tx('Đáp án', 'answerKey')), Tab(text: tx('Chấm bài', 'grading')), Tab(text: tx('Thống kê', 'stats'))]),
        ),
        body: TabBarView(children: [_tabDapAn(), _tabChamBai(), _tabThongKe()]),
      ),
    );
  }

  Widget _tabDapAn() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(tx('${de.soCau} câu. Mỗi mã đề một dãy đáp án.', 'qzKeyInfo', n: de.soCau), style: const TextStyle(color: MauApp.chuPhu)),
        const SizedBox(height: 8),
        for (final ma in de.dapAn.keys)
          Card(
            child: ListTile(
              onTap: () => _suaDapAn(ma),
              title: Text(tx('Mã đề $ma', 'versionX', m: ma)),
              subtitle: Text(de.dapAn[ma]!, style: const TextStyle(fontFamily: 'monospace', letterSpacing: 1)),
              trailing: IconButton(tooltip: tx('Xóa', 'delete'), icon: const Icon(Icons.delete_outline), onPressed: () => _xoaMa(ma)),
            ),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: () => _suaDapAn(), icon: const Icon(Icons.add), label: Text(tx('Thêm mã đề', 'addVersion'))),
      ],
    );
  }

  Widget _tabChamBai() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FilledButton.icon(onPressed: () => _chamBai(), icon: const Icon(Icons.edit_note), label: Text(tx('Chấm bài mới', 'gradeNew'))),
        const SizedBox(height: 8),
        if (de.baiLam.isNotEmpty)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _bangTab()));
                    _bao(tx('Đã chép bảng điểm, dán thẳng vào Excel được.', 'copied'));
                  },
                  icon: const Icon(Icons.copy),
                  label: FittedBox(fit: BoxFit.scaleDown, child: Text(tx('Chép sang Excel', 'copyTable'))),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(onPressed: _guiCsv, icon: const Icon(Icons.ios_share), label: Text(tx('Gửi tệp', 'share'))),
              ),
            ],
          ),
        const SizedBox(height: 8),
        if (de.baiLam.isEmpty) Padding(padding: const EdgeInsets.only(top: 24), child: Center(child: Text(tx('Chưa chấm bài nào.', 'qzNoPapers')))),
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
                subtitle: Text(laQuocTe
                    ? '${chu('versionX', m: b.maDe)}'
                        '${de.dapAn[b.maDe] == null ? ' ${chu('noKey')}' : ' · ${chu('acCorrect', n: soCauDung(de.dapAn[b.maDe]!, b.traLoi), m: soCauTinh(de.dapAn[b.maDe]!))}'}'
                    : 'Mã đề ${b.maDe}'
                        '${de.dapAn[b.maDe] == null ? ' (chưa có đáp án)' : ' · đúng ${soCauDung(de.dapAn[b.maDe]!, b.traLoi)}/${soCauTinh(de.dapAn[b.maDe]!)} câu'}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(d == null ? '–' : _hd(d),
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: (d ?? 0) >= 5 ? MauApp.xanhLa : const Color(0xFFA3241C))),
                    IconButton(tooltip: tx('Xóa', 'delete'), icon: const Icon(Icons.delete_outline), onPressed: () => _xoaBai(b)),
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
    if (diem.isEmpty) return Center(child: Text(tx('Chấm vài bài để xem thống kê.', 'qzStatsNone')));
    final tb = diem.reduce((a, b) => a + b) / diem.length;
    final nhom = <String, int>{
      (laQuocTe ? '< 50%' : 'Dưới 5'): diem.where((d) => d < 5).length,
      (laQuocTe ? '50–64%' : 'Từ 5 đến dưới 6,5'): diem.where((d) => d >= 5 && d < 6.5).length,
      (laQuocTe ? '65–79%' : 'Từ 6,5 đến dưới 8'): diem.where((d) => d >= 6.5 && d < 8).length,
      (laQuocTe ? '≥ 80%' : 'Từ 8 trở lên'): diem.where((d) => d >= 8).length,
    };
    // Câu sai nhiều nhất (tính theo thứ tự câu trên từng mã đề).
    final sai = <String, int>{};
    for (final b in de.baiLam) {
      final d = de.dapAn[b.maDe];
      if (d == null) continue;
      for (var i = 0; i < d.length; i++) {
        if (d[i] != '-' && (i >= b.traLoi.length || b.traLoi[i] != d[i])) {
          final k = laQuocTe ? '${chu('qN', n: i + 1)} (${b.maDe})' : 'Câu ${i + 1} (mã ${b.maDe})';
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
        dong(tx('Số bài đã chấm', 'papers'), '${diem.length}'),
        dong(tx('Điểm trung bình', 'average'), _hd((tb * 100).round() / 100)),
        dong(tx('Cao nhất', 'highest'), _hd(diem.reduce((a, b) => a > b ? a : b))),
        dong(tx('Thấp nhất', 'lowest'), _hd(diem.reduce((a, b) => a < b ? a : b))),
        const Divider(height: 24),
        for (final e in nhom.entries)
          dong(e.key, '${e.value}${laQuocTe ? '' : ' bài'} (${(e.value * 100 / diem.length).toStringAsFixed(0)}%)'),
        const Divider(height: 24),
        Text(tx('Câu nhiều em làm sai', 'mostMissed'), style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        for (final e in saiNhieu.take(8)) dong(e.key, laQuocTe ? '${e.value}' : '${e.value} em sai'),
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
    _ten = TextEditingController(text: widget.tenGoc ?? (widget.sttMoi == null ? '' : tx('Học sinh ${widget.sttMoi}', 'student', n: widget.sttMoi)));
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
        _bao(tx('Thầy cô ghi mã đề, ví dụ 101.', 'qzNeedVersion'));
        return;
      }
      final thieu = _chon.where((c) => c == '-').length;
      if (thieu > 0) _bao(tx('Lưu ý: còn $thieu câu chưa có đáp án, các câu này không tính điểm.', 'qzUnanswered', n: thieu));
      Navigator.of(context).pop((ma, _chuoi));
    } else {
      final ten = _ten.text.trim();
      if (ten.isEmpty || _maChon == null) {
        _bao(tx('Thầy cô ghi tên học sinh và chọn mã đề.', 'qzNeedName'));
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
                    laQuocTe
                        ? '${chu('acCorrect', n: soCauDung(ss, _chuoi), m: soCauTinh(ss))} · ${_hd(diemThang10(ss, _chuoi))}'
                        : 'Đúng ${soCauDung(ss, _chuoi)}/${soCauTinh(ss)} · ${hienDiem(diemThang10(ss, _chuoi))} điểm',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: MauApp.xanhLa),
                  ),
                )
              else
                const Spacer(),
              FilledButton.icon(
                onPressed: _luu,
                icon: const Icon(Icons.check),
                label: Text(widget.laDapAn ? tx('Lưu đáp án', 'save') : tx('Lưu, chấm em tiếp', 'saveNext')),
              ),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        children: [
          if (widget.laDapAn)
            TextField(controller: _ma, decoration: InputDecoration(labelText: tx('Mã đề', 'version'), border: const OutlineInputBorder()))
          else ...[
            TextField(controller: _ten, decoration: InputDecoration(labelText: tx('Họ và tên học sinh', 'studentName'), border: const OutlineInputBorder())),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              children: [
                Padding(padding: const EdgeInsets.only(top: 8), child: Text('${tx('Mã đề', 'version')}: ')),
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
            decoration: InputDecoration(
              labelText: tx('Gõ nhanh cả dãy (không bắt buộc)', 'quickType'),
              hintText: tx('Ví dụ: ABCDA BBCDA… hoặc 1234…; câu bỏ trống gõ dấu -', 'quickHint'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          Text(tx('Hoặc chạm chọn từng câu:', 'orTap'), style: const TextStyle(color: MauApp.chuPhu)),
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
                    Text(laQuocTe ? '✓ ${ss[i]}' : 'đ/a ${ss[i]}', style: const TextStyle(fontSize: 12, color: MauApp.chuPhu)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
