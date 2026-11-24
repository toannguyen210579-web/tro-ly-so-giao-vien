import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/luu_tru.dart';
import '../data/thu_thach.dart';
import '../main.dart';
import '../services/tro_ly_api.dart';

const _khoa = 'thu_thach';
const _khoaGiay = 'thu_thach_giay';
const _nen = Color(0xFF14233A);

/// Thẻ "Thử thách" trong Công cụ trên lớp: danh sách bộ câu hỏi, chọn thời gian, bấm Chơi.
class ThuThachTab extends StatefulWidget {
  final List<String> ten;
  final String tenLop;
  const ThuThachTab({super.key, required this.ten, required this.tenLop});

  @override
  State<ThuThachTab> createState() => _ThuThachTabState();
}

class _ThuThachTabState extends State<ThuThachTab> {
  List<BoThuThach>? _ds;
  int _giay = 20;

  @override
  void initState() {
    super.initState();
    _tai();
  }

  Future<void> _tai() async {
    var ds = (await LuuTru.docDanhSach(_khoa)).map(BoThuThach.fromJson).toList();
    if (ds.isEmpty) ds = [boThuThachMau()];
    final p = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _ds = ds;
        _giay = p.getInt(_khoaGiay) ?? 20;
      });
    }
  }

  Future<void> _luu() async {
    await LuuTru.ghiDanhSach(_khoa, [for (final b in _ds!) if (b.id != 'mau') b.toJson()]);
    if (mounted) setState(() {});
  }

  Future<void> _sua([BoThuThach? goc, bool nhoAI = false]) async {
    final kq = await Navigator.of(context).push<BoThuThach>(MaterialPageRoute(builder: (_) => _SuaBoThuThach(goc: goc, moNhoAI: nhoAI)));
    if (kq == null) return;
    final ds = _ds!;
    final i = ds.indexWhere((b) => b.id == kq.id);
    if (i >= 0) {
      ds[i] = kq;
    } else {
      ds.insert(0, kq);
    }
    await _luu();
  }

  void _choi(BoThuThach b) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChoiThuThach(bo: b, ten: widget.ten, tenLop: widget.tenLop, giay: _giay),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final ds = _ds;
    if (ds == null) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Text(
          'Chiếu câu hỏi lên lớp, đếm giờ, học sinh ghi đáp án lên bảng con. Em trả lời sai bị loại, em trụ lại đến cuối là người thắng. '
          '${widget.ten.isEmpty ? 'Chưa có lớp: vẫn chơi được, chỉ không theo dõi ai bị loại.' : 'Lớp ${widget.tenLop}: ${widget.ten.length} em cùng chơi.'}',
          style: const TextStyle(fontSize: 13, color: MauApp.chuPhu, height: 1.35),
        ),
        const SizedBox(height: 10),
        const Text('Thời gian mỗi câu', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Wrap(spacing: 8, runSpacing: 6, children: [
          for (final g in [10, 15, 20, 30, 45, 60])
            ChoiceChip(
              label: Text('$g giây'),
              selected: _giay == g,
              onSelected: (_) {
                setState(() => _giay = g);
                SharedPreferences.getInstance().then((p) => p.setInt(_khoaGiay, g));
              },
            ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: FilledButton.icon(onPressed: () => _sua(), icon: const Icon(Icons.add), label: const Text('Bộ câu hỏi mới'))),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.tonalIcon(onPressed: () => _sua(null, true), icon: const Icon(Icons.auto_awesome), label: const Text('Nhờ AI soạn')),
          ),
        ]),
        const SizedBox(height: 12),
        for (final b in ds)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const Icon(Icons.emoji_events_outlined, color: Color(0xFFE5570B)),
              title: Text(b.ten, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${b.cau.length} câu · chạm để sửa'),
              onTap: () => _sua(b),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                FilledButton(onPressed: b.cau.isEmpty ? null : () => _choi(b), child: const Text('Chơi')),
                if (b.id != 'mau')
                  IconButton(
                    tooltip: 'Xóa',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      ds.remove(b);
                      if (ds.isEmpty) ds.add(boThuThachMau());
                      await _luu();
                    },
                  ),
              ]),
            ),
          ),
      ],
    );
  }
}

/// Soạn, sửa bộ câu hỏi: dán chữ từ Word, Zalo, hoặc nhờ AI soạn rồi đọc lại.
class _SuaBoThuThach extends StatefulWidget {
  final BoThuThach? goc;
  final bool moNhoAI;
  const _SuaBoThuThach({this.goc, this.moNhoAI = false});

  @override
  State<_SuaBoThuThach> createState() => _SuaBoThuThachState();
}

class _SuaBoThuThachState extends State<_SuaBoThuThach> {
  late final _ten = TextEditingController(text: widget.goc?.ten == 'Mẫu: Kiến thức chung' ? '' : (widget.goc?.ten ?? ''));
  late final _chu = TextEditingController(text: widget.goc == null ? '' : vanBanBo(widget.goc!.cau));
  bool _dangSoan = false;
  bool _coAI = false;

  @override
  void initState() {
    super.initState();
    if (widget.moNhoAI) WidgetsBinding.instance.addPostFrameCallback((_) => _nhoAI());
  }

  @override
  void dispose() {
    _ten.dispose();
    _chu.dispose();
    super.dispose();
  }

  Future<void> _nhoAI() async {
    final yc = await showDialog<(String, String, int)>(context: context, builder: (_) => const _HopNhoAI());
    if (yc == null || !mounted) return;
    final (chuDe, lop, so) = yc;
    setState(() => _dangSoan = true);
    final kq = await TroLyApi.hoi(cauNhoAISoan(chuDe, lop, so), loai: 'hoi');
    if (!mounted) return;
    setState(() => _dangSoan = false);
    final tl = kq.traLoi;
    if (tl == null || tl.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(kq.loi ?? 'AI chưa soạn được, thầy cô thử lại.')));
      return;
    }
    final moi = catTuCau1(boDauMarkdown(tl));
    setState(() {
      _coAI = true;
      if (_ten.text.trim().isEmpty) _ten.text = chuDe;
      _chu.text = _chu.text.trim().isEmpty ? moi : '${_chu.text.trim()}\n\n$moi';
    });
  }

  @override
  Widget build(BuildContext context) {
    final cau = tachCauHoi(_chu.text);
    final thieu = cau.where((c) => c.dapAn.isEmpty).length;
    return Scaffold(
      appBar: AppBar(title: Text(widget.goc == null || widget.goc!.id == 'mau' ? 'Bộ câu hỏi mới' : 'Sửa bộ câu hỏi')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          TextField(
            controller: _ten,
            decoration: const InputDecoration(labelText: 'Tên bộ câu hỏi', hintText: 'Ví dụ: Ôn tập Bài 5, Toán 6', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: _dangSoan ? null : _nhoAI,
            icon: _dangSoan
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.auto_awesome),
            label: Text(_dangSoan ? 'AI đang soạn câu hỏi...' : 'Nhờ AI soạn câu hỏi'),
          ),
          if (_coAI)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Bản do AI soạn: thầy cô đọc lại, sửa câu chưa đúng trước khi lưu.',
                  style: TextStyle(color: Color(0xFFB45309), fontWeight: FontWeight.w700)),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _chu,
            minLines: 8,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Câu hỏi và đáp án',
              alignLabelWithHint: true,
              hintText: 'Dán hoặc gõ, ví dụ:\nCâu 1: Thủ đô của Việt Nam?\nĐáp án: Hà Nội\n\nHoặc mỗi dòng: Câu hỏi | Đáp án',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            cau.isEmpty ? 'Chưa đọc được câu hỏi nào.' : 'Đọc được ${cau.length} câu${thieu > 0 ? ', $thieu câu chưa có đáp án' : ''}.',
            style: TextStyle(fontWeight: FontWeight.w800, color: thieu > 0 || cau.isEmpty ? const Color(0xFFB45309) : MauApp.xanhLa),
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < cau.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text.rich(TextSpan(children: [
                TextSpan(text: '${i + 1}. ', style: const TextStyle(fontWeight: FontWeight.w800)),
                TextSpan(text: cau[i].hoi.split('\n').first),
                TextSpan(
                  text: cau[i].dapAn.isEmpty ? '  (chưa có đáp án)' : '  → ${cau[i].dapAnDayDu}',
                  style: TextStyle(fontWeight: FontWeight.w700, color: cau[i].dapAn.isEmpty ? const Color(0xFFB45309) : MauApp.xanhLa),
                ),
              ])),
            ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: cau.isEmpty
                ? null
                : () {
                    final goc = widget.goc;
                    Navigator.of(context).pop(BoThuThach(
                      id: goc == null || goc.id == 'mau' ? DateTime.now().microsecondsSinceEpoch.toString() : goc.id,
                      ten: _ten.text.trim().isEmpty ? 'Bộ ${cau.length} câu hỏi' : _ten.text.trim(),
                      cau: cau,
                    ));
                  },
            icon: const Icon(Icons.check),
            label: const Text('Lưu bộ câu hỏi'),
          ),
        ],
      ),
    );
  }
}

class _HopNhoAI extends StatefulWidget {
  const _HopNhoAI();

  @override
  State<_HopNhoAI> createState() => _HopNhoAIState();
}

class _HopNhoAIState extends State<_HopNhoAI> {
  final _chuDe = TextEditingController();
  final _lop = TextEditingController();
  int _so = 10;

  @override
  void dispose() {
    _chuDe.dispose();
    _lop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nhờ AI soạn câu hỏi'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(
            controller: _chuDe,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Chủ đề, bài học', hintText: 'Ví dụ: Phân số, Toán 6'),
          ),
          TextField(controller: _lop, decoration: const InputDecoration(labelText: 'Dành cho lớp (không bắt buộc)', hintText: 'Ví dụ: lớp 6')),
          const SizedBox(height: 12),
          const Text('Số câu'),
          Wrap(spacing: 8, children: [
            for (final s in [5, 10, 15, 20]) ChoiceChip(label: Text('$s'), selected: _so == s, onSelected: (_) => setState(() => _so = s)),
          ]),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Thôi')),
        FilledButton(
          onPressed: _chuDe.text.trim().isEmpty ? null : () => Navigator.pop(context, (_chuDe.text.trim(), _lop.text.trim(), _so)),
          child: const Text('Soạn'),
        ),
      ],
    );
  }
}

enum _Buoc { cho, dem, hetGio, dapAn, ketThuc }

/// Màn chơi chiếu lên lớp: câu hỏi chữ lớn, đếm giờ, xem đáp án, chạm tên em trả lời sai.
class ChoiThuThach extends StatefulWidget {
  final BoThuThach bo;
  final List<String> ten;
  final String tenLop;
  final int giay;
  const ChoiThuThach({super.key, required this.bo, required this.ten, required this.tenLop, required this.giay});

  @override
  State<ChoiThuThach> createState() => _ChoiThuThachState();
}

class _ChoiThuThachState extends State<ChoiThuThach> {
  late VanThuThach _v = VanThuThach(widget.ten);
  int _i = 0;
  _Buoc _b = _Buoc.cho;
  late int _con = widget.giay;
  Timer? _t;
  final _sai = <String>{};

  bool get _coLop => widget.ten.isNotEmpty;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight, DeviceOrientation.portraitUp]);
  }

  @override
  void dispose() {
    _t?.cancel();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  void _batDau() {
    _t?.cancel();
    setState(() {
      _b = _Buoc.dem;
      _con = widget.giay;
    });
    _t = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _con--);
      if (_con <= 0) {
        t.cancel();
        HapticFeedback.heavyImpact();
        SystemSound.play(SystemSoundType.alert);
        setState(() => _b = _Buoc.hetGio);
      }
    });
  }

  void _xemDapAn() {
    _t?.cancel();
    setState(() => _b = _Buoc.dapAn);
  }

  void _tiep() {
    if (_coLop && _sai.isNotEmpty && !_v.loai(_sai)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tất cả các em còn lại đều trả lời sai, nên không loại ai ở câu này.')),
      );
    }
    _sai.clear();
    final hetCau = _i >= widget.bo.cau.length - 1;
    setState(() {
      if (hetCau || (_coLop && _v.conLai.length <= 1)) {
        _b = _Buoc.ketThuc;
      } else {
        _i++;
        _b = _Buoc.cho;
        _con = widget.giay;
      }
    });
  }

  Future<void> _cuuTro() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Cứu trợ'),
        content: Text('Cho ${_v.biLoai.length} em đã bị loại vào chơi tiếp?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Thôi')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Cứu trợ')),
        ],
      ),
    );
    if (ok == true) setState(() => _v.cuuTro());
  }

  void _choiLai() {
    _t?.cancel();
    setState(() {
      _v = VanThuThach(widget.ten);
      _i = 0;
      _b = _Buoc.cho;
      _con = widget.giay;
      _sai.clear();
    });
  }

  Widget _nhan(String s, {Color mau = const Color(0xFF2B3E5C)}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: mau, borderRadius: BorderRadius.circular(20)),
        child: Text(s, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
      );

  @override
  Widget build(BuildContext context) {
    final bo = widget.bo;
    return Scaffold(
      backgroundColor: _nen,
      appBar: AppBar(
        backgroundColor: _nen,
        foregroundColor: Colors.white,
        title: Text(bo.ten),
        actions: [
          if (_coLop && _v.biLoai.isNotEmpty && _b != _Buoc.ketThuc)
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: const Color(0xFFFFC27A)),
              onPressed: _cuuTro,
              icon: const Icon(Icons.favorite),
              label: const Text('Cứu trợ'),
            ),
        ],
      ),
      body: LayoutBuilder(builder: (context, c) {
        final co = (c.maxWidth / 20).clamp(20.0, 36.0);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: _b == _Buoc.ketThuc ? _ketThuc(co) : _dangChoi(co),
        );
      }),
    );
  }

  List<Widget> _dangChoi(double co) {
    final cau = widget.bo.cau[_i];
    return [
      Wrap(spacing: 8, runSpacing: 8, children: [
        _nhan('Câu ${_i + 1}/${widget.bo.cau.length}', mau: const Color(0xFFE5570B)),
        if (_coLop) _nhan('Còn ${_v.conLai.length}/${widget.ten.length} em'),
      ]),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
        child: Text(cau.hoi, style: TextStyle(fontSize: co, fontWeight: FontWeight.w800, color: MauApp.chu, height: 1.3)),
      ),
      const SizedBox(height: 16),
      if (_b == _Buoc.cho)
        FilledButton.icon(
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: const Color(0xFF14A3A1)),
          onPressed: _batDau,
          icon: const Icon(Icons.play_arrow),
          label: Text('Bắt đầu tính giờ (${widget.giay} giây)', style: const TextStyle(fontSize: 18)),
        ),
      if (_b == _Buoc.dem) ...[
        Center(
          child: Text('$_con',
              style: TextStyle(
                fontSize: co * 3,
                fontWeight: FontWeight.w900,
                color: _con <= 5 ? const Color(0xFFFF6B6B) : Colors.white,
                fontFeatures: const [FontFeature.tabularFigures()],
              )),
        ),
        LinearProgressIndicator(
          value: widget.giay == 0 ? 0 : _con / widget.giay,
          minHeight: 10,
          borderRadius: BorderRadius.circular(6),
          color: _con <= 5 ? const Color(0xFFFF6B6B) : const Color(0xFF14A3A1),
          backgroundColor: const Color(0xFF2B3E5C),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
          onPressed: _xemDapAn,
          child: const Text('Dừng giờ, xem đáp án'),
        ),
      ],
      if (_b == _Buoc.hetGio) ...[
        Center(child: Text('Hết giờ! Các em giơ bảng.', style: TextStyle(color: const Color(0xFFFFC27A), fontSize: co, fontWeight: FontWeight.w900))),
        const SizedBox(height: 12),
        FilledButton.icon(
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
          onPressed: _xemDapAn,
          icon: const Icon(Icons.visibility),
          label: const Text('Xem đáp án', style: TextStyle(fontSize: 18)),
        ),
      ],
      if (_b == _Buoc.dapAn) ...[
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: MauApp.xanhLa, borderRadius: BorderRadius.circular(18)),
          child: Text(cau.dapAn.isEmpty ? 'Câu này chưa có đáp án.' : 'Đáp án: ${cau.dapAnDayDu}',
              style: TextStyle(color: Colors.white, fontSize: co, fontWeight: FontWeight.w900)),
        ),
        if (_coLop) ...[
          const SizedBox(height: 14),
          Text(_sai.isEmpty ? 'Chạm tên các em trả lời sai (không ai sai thì bấm Câu tiếp theo):' : 'Loại ${_sai.length} em trả lời sai:',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final t in _v.conLai)
              FilterChip(
                label: Text(t),
                selected: _sai.contains(t),
                selectedColor: const Color(0xFFFFB4B4),
                onSelected: (c) => setState(() => c ? _sai.add(t) : _sai.remove(t)),
              ),
          ]),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: const Color(0xFFE5570B)),
          onPressed: _tiep,
          icon: const Icon(Icons.arrow_forward),
          label: Text(_i >= widget.bo.cau.length - 1 ? 'Xem kết quả' : 'Câu tiếp theo', style: const TextStyle(fontSize: 18)),
        ),
      ],
    ];
  }

  List<Widget> _ketThuc(double co) {
    final con = _v.conLai;
    final soCau = _i + 1;
    return [
      const SizedBox(height: 8),
      const Center(child: Icon(Icons.emoji_events, color: Color(0xFFFFC27A), size: 96)),
      Center(child: Text('Kết thúc thử thách', style: TextStyle(color: Colors.white, fontSize: co, fontWeight: FontWeight.w900))),
      const SizedBox(height: 8),
      if (_coLop) ...[
        Center(
          child: Text('Qua $soCau câu, ${con.length} em trụ lại đến cuối:',
              textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 16)),
        ),
        const SizedBox(height: 10),
        Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
          for (final t in con) _nhan(t, mau: const Color(0xFFE5570B)),
        ]),
      ] else
        Center(child: Text('Đã chơi xong $soCau câu hỏi.', style: const TextStyle(color: Colors.white70, fontSize: 16))),
      const SizedBox(height: 20),
      FilledButton.icon(
        onPressed: () => Share.share(ketQuaThuThach(
          tenBo: widget.bo.ten,
          tenLop: widget.tenLop,
          soCau: soCau,
          conLai: con,
          siSo: widget.ten.length,
        )),
        icon: const Icon(Icons.send),
        label: const Text('Gửi kết quả'),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
        onPressed: _choiLai,
        icon: const Icon(Icons.replay),
        label: const Text('Chơi lại'),
      ),
    ];
  }
}
