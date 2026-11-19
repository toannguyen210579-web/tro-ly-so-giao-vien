import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/luu_tru.dart';
import '../main.dart';
import '../services/tep_pdf.dart';
import 'cau_giup_viec.dart';
import 'nhan_xet.dart';

/// Chia danh sách thành [soNhom] nhóm đều nhau (đã xáo trộn).
List<List<String>> chiaNhom(List<String> ten, int soNhom, Random r) {
  final ds = [...ten]..shuffle(r);
  final kq = List.generate(soNhom, (_) => <String>[]);
  for (var i = 0; i < ds.length; i++) {
    kq[i % soNhom].add(ds[i]);
  }
  return kq;
}

/// Công cụ trên lớp: gọi tên ngẫu nhiên, chia nhóm, điểm danh, đồng hồ.
/// Dùng lại danh sách lớp đã nhập ở Nhận xét học sinh.
class CongCuTrenLop extends StatefulWidget {
  const CongCuTrenLop({super.key});

  @override
  State<CongCuTrenLop> createState() => _CongCuTrenLopState();
}

class _CongCuTrenLopState extends State<CongCuTrenLop> {
  List<Lop>? _ds;
  int _chon = 0;

  @override
  void initState() {
    super.initState();
    _tai();
  }

  /// Mở lại đúng lớp dùng lần trước (nhớ chung với Giơ thẻ).
  Future<void> _tai() async {
    final d = await docLop();
    final p = await SharedPreferences.getInstance();
    final ten = p.getString('lop_dang_day');
    final i = d.indexWhere((l) => l.ten == ten);
    if (mounted) {
      setState(() {
        _ds = d;
        _chon = i < 0 ? 0 : i;
      });
    }
  }

  List<String> get _ten => (_ds == null || _ds!.isEmpty) ? [] : _ds![_chon].hocSinh.map((h) => h.ten).toList();

  @override
  Widget build(BuildContext context) {
    final ds = _ds;
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Công cụ trên lớp'),
          bottom: const TabBar(isScrollable: true, tabs: [
            Tab(text: 'Gọi tên'),
            Tab(text: 'Chia nhóm'),
            Tab(text: 'Điểm danh'),
            Tab(text: 'Đồng hồ'),
          ]),
        ),
        body: ds == null
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  const CauGiupViec('cong_cu', margin: EdgeInsets.fromLTRB(16, 10, 16, 0)),
                  if (ds.isEmpty)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: Text(
                        'Chưa có lớp nào. Thầy cô tạo lớp ở tiện ích Nhận xét học sinh (dán danh sách tên), rồi quay lại đây. '
                        'Đồng hồ vẫn dùng được ngay.',
                        style: TextStyle(color: MauApp.chuPhu),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: DropdownButtonFormField<int>(
                        value: _chon,
                        decoration: const InputDecoration(labelText: 'Lớp', border: OutlineInputBorder(), isDense: true),
                        items: [
                          for (var i = 0; i < ds.length; i++)
                            DropdownMenuItem(value: i, child: Text('Lớp ${ds[i].ten} · ${ds[i].hocSinh.length} em')),
                        ],
                        onChanged: (v) {
                          setState(() => _chon = v ?? 0);
                          SharedPreferences.getInstance().then((p) => p.setString('lop_dang_day', ds[_chon].ten));
                        },
                      ),
                    ),
                  Expanded(
                    child: TabBarView(children: [
                      _GoiTen(key: ValueKey('g$_chon'), ten: _ten),
                      _ChiaNhom(key: ValueKey('c$_chon'), ten: _ten),
                      _DiemDanh(key: ValueKey('d$_chon'), ten: _ten, tenLop: ds.isEmpty ? '' : ds[_chon].ten),
                      const _DongHo(),
                    ]),
                  ),
                ],
              ),
      ),
    );
  }
}

class _GoiTen extends StatefulWidget {
  final List<String> ten;
  const _GoiTen({super.key, required this.ten});

  @override
  State<_GoiTen> createState() => _GoiTenState();
}

class _GoiTenState extends State<_GoiTen> {
  final _r = Random();
  final _daGoi = <String>{};
  String? _hien;
  bool _dangQuay = false;
  bool _khongLap = true;

  Future<void> _quay() async {
    final con = widget.ten.where((t) => !_khongLap || !_daGoi.contains(t)).toList();
    if (con.isEmpty) {
      setState(() {
        _daGoi.clear();
        _hien = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã gọi hết lớp, bắt đầu lượt mới.')));
      return;
    }
    setState(() => _dangQuay = true);
    for (var i = 0; i < 14; i++) {
      await Future.delayed(Duration(milliseconds: 40 + i * 12));
      if (!mounted) return;
      setState(() => _hien = widget.ten[_r.nextInt(widget.ten.length)]);
    }
    final ten = con[_r.nextInt(con.length)];
    HapticFeedback.mediumImpact();
    setState(() {
      _hien = ten;
      _daGoi.add(ten);
      _dangQuay = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.ten.isEmpty) return const SizedBox.shrink();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 12),
        Container(
          height: 180,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFFFA24C), Color(0xFFEF4A23)]),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _hien ?? 'Bấm Gọi tên',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900),
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _dangQuay ? null : _quay,
          icon: const Icon(Icons.casino_outlined),
          label: const Text('Gọi tên', style: TextStyle(fontSize: 18)),
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _khongLap,
          onChanged: (v) => setState(() => _khongLap = v),
          title: const Text('Không gọi lại em đã được gọi'),
          subtitle: Text('Đã gọi ${_daGoi.length}/${widget.ten.length} em'),
        ),
      ],
    );
  }
}

class _ChiaNhom extends StatefulWidget {
  final List<String> ten;
  const _ChiaNhom({super.key, required this.ten});

  @override
  State<_ChiaNhom> createState() => _ChiaNhomState();
}

class _ChiaNhomState extends State<_ChiaNhom> {
  int _soNhom = 4;
  List<List<String>> _kq = [];

  String _vanBan() {
    final b = StringBuffer();
    for (var i = 0; i < _kq.length; i++) {
      b.writeln('Nhóm ${i + 1}: ${_kq[i].join(', ')}');
    }
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.ten.isEmpty) return const SizedBox.shrink();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          const Text('Số nhóm'),
          Expanded(
            child: Slider(
              value: _soNhom.toDouble(),
              min: 2,
              max: 12,
              divisions: 10,
              label: '$_soNhom',
              onChanged: (v) => setState(() => _soNhom = v.round()),
            ),
          ),
          Text('$_soNhom', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        ]),
        FilledButton.icon(
          onPressed: () => setState(() => _kq = chiaNhom(widget.ten, min(_soNhom, widget.ten.length), Random())),
          icon: const Icon(Icons.shuffle),
          label: Text(_kq.isEmpty ? 'Chia nhóm' : 'Chia lại'),
        ),
        if (_kq.isNotEmpty) ...[
          const SizedBox(height: 12),
          for (var i = 0; i < _kq.length; i++)
            Card(
              child: ListTile(
                leading: CircleAvatar(child: Text('${i + 1}')),
                title: Text('Nhóm ${i + 1} · ${_kq[i].length} em', style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(_kq[i].join(', ')),
              ),
            ),
          OutlinedButton.icon(
            onPressed: () => Share.share(_vanBan()),
            icon: const Icon(Icons.send),
            label: const Text('Gửi danh sách nhóm'),
          ),
        ],
      ],
    );
  }
}

class _DiemDanh extends StatefulWidget {
  final List<String> ten;
  final String tenLop;
  const _DiemDanh({super.key, required this.ten, required this.tenLop});

  @override
  State<_DiemDanh> createState() => _DiemDanhState();
}

class _DiemDanhState extends State<_DiemDanh> {
  // 0 có mặt, 1 vắng có phép, 2 vắng không phép
  late Map<String, int> _tt = {for (final t in widget.ten) t: 0};

  String get _khoa {
    final d = DateTime.now();
    return 'diem_danh_${widget.tenLop}_${d.year}${hai(d.month)}${hai(d.day)}';
  }

  @override
  void initState() {
    super.initState();
    LuuTru.docDanhSach(_khoa).then((ds) {
      if (!mounted || ds.isEmpty) return;
      setState(() => _tt = {
            for (final t in widget.ten) t: (ds.firstWhere((e) => e['ten'] == t, orElse: () => {'tt': 0})['tt'] as int?) ?? 0,
          });
    });
  }

  Future<void> _luu() => LuuTru.ghiDanhSach(_khoa, [for (final e in _tt.entries) {'ten': e.key, 'tt': e.value}]);

  String _baoCao() {
    final co = _tt.values.where((v) => v == 0).length;
    final p = _tt.entries.where((e) => e.value == 1).map((e) => e.key).toList();
    final k = _tt.entries.where((e) => e.value == 2).map((e) => e.key).toList();
    return 'Điểm danh lớp ${widget.tenLop} ngày ${ngayVN(DateTime.now())}: có mặt $co/${_tt.length}.'
        '${p.isEmpty ? '' : '\nVắng có phép (${p.length}): ${p.join(', ')}.'}'
        '${k.isEmpty ? '' : '\nVắng không phép (${k.length}): ${k.join(', ')}.'}';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.ten.isEmpty) return const SizedBox.shrink();
    const nhan = ['Có mặt', 'Vắng P', 'Vắng KP'];
    const mau = [MauApp.xanhLa, Color(0xFFF08C00), Color(0xFFD42539)];
    final co = _tt.values.where((v) => v == 0).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text('Có mặt $co/${_tt.length} · chạm vào tên để đổi', style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        for (final t in widget.ten)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(t),
            trailing: Chip(
              label: Text(nhan[_tt[t] ?? 0], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              backgroundColor: mau[_tt[t] ?? 0],
            ),
            onTap: () {
              setState(() => _tt[t] = ((_tt[t] ?? 0) + 1) % 3);
              _luu();
            },
          ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _baoCao()));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã chép kết quả điểm danh.')));
              },
              icon: const Icon(Icons.copy),
              label: const Text('Chép'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.icon(
              onPressed: () => Share.share(_baoCao()),
              icon: const Icon(Icons.send),
              label: const Text('Gửi'),
            ),
          ),
        ]),
      ],
    );
  }
}

class _DongHo extends StatefulWidget {
  const _DongHo();

  @override
  State<_DongHo> createState() => _DongHoState();
}

class _DongHoState extends State<_DongHo> {
  int _tong = 300;
  int _con = 300;
  Timer? _t;

  void _batDau() {
    _t?.cancel();
    if (_con <= 0) _con = _tong;
    _t = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _con--);
      if (_con <= 0) {
        t.cancel();
        HapticFeedback.heavyImpact();
        SystemSound.play(SystemSoundType.alert);
      }
    });
    setState(() {});
  }

  void _dung() {
    _t?.cancel();
    setState(() => _t = null);
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chay = _t?.isActive ?? false;
    final p = _con ~/ 60, g = _con % 60;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final phut in [1, 3, 5, 10, 15, 45])
              ChoiceChip(
                label: Text('$phut phút'),
                selected: _tong == phut * 60,
                onSelected: chay
                    ? null
                    : (_) => setState(() {
                          _tong = phut * 60;
                          _con = _tong;
                        }),
              ),
          ],
        ),
        const SizedBox(height: 24),
        Center(
          child: Text(
            '${hai(p)}:${hai(g)}',
            style: TextStyle(fontSize: 96, fontWeight: FontWeight.w900, color: _con <= 10 ? const Color(0xFFD42539) : MauApp.chu,
                fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ),
        LinearProgressIndicator(value: _tong == 0 ? 0 : _con / _tong, minHeight: 10, borderRadius: BorderRadius.circular(6)),
        const SizedBox(height: 24),
        Row(children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: chay ? _dung : _batDau,
              icon: Icon(chay ? Icons.pause : Icons.play_arrow),
              label: Text(chay ? 'Tạm dừng' : (_con < _tong && _con > 0 ? 'Chạy tiếp' : 'Bắt đầu')),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                _t?.cancel();
                setState(() {
                  _t = null;
                  _con = _tong;
                });
              },
              icon: const Icon(Icons.replay),
              label: const Text('Đặt lại'),
            ),
          ),
        ]),
        if (_con <= 0)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Center(child: Text('Hết giờ!', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFFD42539)))),
          ),
      ],
    );
  }
}
