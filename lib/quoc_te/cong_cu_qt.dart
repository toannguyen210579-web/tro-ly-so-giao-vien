import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../screens/cong_cu_tren_lop.dart' show chiaNhom;
import 'quoc_te.dart';

String _hai(int n) => n.toString().padLeft(2, '0');

/// Sửa danh sách lớp: mỗi dòng một tên.
class DanhSachLopQT extends StatefulWidget {
  const DanhSachLopQT({super.key});

  @override
  State<DanhSachLopQT> createState() => _DanhSachLopQTState();
}

class _DanhSachLopQTState extends State<DanhSachLopQT> {
  final _o = TextEditingController();

  @override
  void initState() {
    super.initState();
    LopQT.doc().then((d) {
      if (mounted) _o.text = d.join('\n');
    });
  }

  @override
  void dispose() {
    _o.dispose();
    super.dispose();
  }

  Future<void> _xong() async {
    await LopQT.ghi(LopQT.tach(_o.text));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(chu('classList'))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('o_ten'),
                controller: _o,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  hintText: chu('listHint'),
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const ValueKey('nut_xong'),
                onPressed: _xong,
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                child: Text(chu('done')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Khung chung cho các công cụ cần danh sách lớp: chưa đủ 2 tên thì mời nhập.
class _CanLop extends StatefulWidget {
  final String khoa;
  final Widget Function(List<String> ten) noiDung;
  const _CanLop({required this.khoa, required this.noiDung});

  @override
  State<_CanLop> createState() => _CanLopState();
}

class _CanLopState extends State<_CanLop> {
  List<String>? _ten;

  @override
  void initState() {
    super.initState();
    _tai();
  }

  Future<void> _tai() async {
    final d = await LopQT.doc();
    if (mounted) setState(() => _ten = d);
  }

  Future<void> _sua() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const DanhSachLopQT()));
    _tai();
  }

  @override
  Widget build(BuildContext context) {
    final ten = _ten;
    return Scaffold(
      appBar: AppBar(
        title: Text(chu(widget.khoa)),
        actions: [IconButton(onPressed: _sua, tooltip: chu('classList'), icon: const Icon(Icons.list_alt_outlined))],
      ),
      body: ten == null
          ? const Center(child: CircularProgressIndicator())
          : ten.length < 2
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(chu('needNames'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: MauApp.chuPhu)),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          key: const ValueKey('nut_nhap_lop'),
                          onPressed: _sua,
                          icon: const Icon(Icons.list_alt_outlined),
                          label: Text(chu('classList')),
                        ),
                      ],
                    ),
                  ),
                )
              : KeyedSubtree(key: ValueKey(ten.join('|')), child: widget.noiDung(ten)),
    );
  }
}

/// Đồng hồ đếm ngược.
class DongHoQT extends StatefulWidget {
  const DongHoQT({super.key});

  @override
  State<DongHoQT> createState() => _DongHoQTState();
}

class _DongHoQTState extends State<DongHoQT> {
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
    const do_ = Color(0xFFD42539);
    return Scaffold(
      appBar: AppBar(title: Text(chu('timer'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final phut in const [1, 2, 3, 5, 10, 15, 20, 30, 45])
                ChoiceChip(
                  label: Text('$phut'),
                  selected: _tong == phut * 60,
                  onSelected: chay
                      ? null
                      : (_) => setState(() {
                            _tong = phut * 60;
                            _con = _tong;
                          }),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 12, left: 4),
                child: Text(chu('minutes'), style: const TextStyle(color: MauApp.chuPhu, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${_hai(_con ~/ 60)}:${_hai(_con % 60)}',
              key: const ValueKey('gio'),
              style: TextStyle(
                fontSize: 104,
                fontWeight: FontWeight.w900,
                color: _con <= 10 ? do_ : MauApp.chu,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          LinearProgressIndicator(value: _tong == 0 ? 0 : _con / _tong, minHeight: 10, borderRadius: BorderRadius.circular(6)),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                key: const ValueKey('nut_chay'),
                onPressed: chay ? _dung : _batDau,
                icon: Icon(chay ? Icons.pause : Icons.play_arrow),
                label: Text(chu(chay ? 'pause' : 'start')),
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
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
                label: Text(chu('reset')),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
          ]),
          if (_con <= 0)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Center(
                child: Text(chu('timeUp'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: do_)),
              ),
            ),
        ],
      ),
    );
  }
}

/// Gọi tên ngẫu nhiên.
class GoiTenQT extends StatelessWidget {
  const GoiTenQT({super.key});

  @override
  Widget build(BuildContext context) => _CanLop(khoa: 'picker', noiDung: (ten) => _GoiTen(ten: ten));
}

class _GoiTen extends StatefulWidget {
  final List<String> ten;
  const _GoiTen({required this.ten});

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
    if (_khongLap && _daGoi.length >= widget.ten.length) _daGoi.clear();
    final con = widget.ten.where((t) => !_khongLap || !_daGoi.contains(t)).toList();
    setState(() => _dangQuay = true);
    for (var i = 0; i < 12; i++) {
      await Future<void>.delayed(Duration(milliseconds: 40 + i * 12));
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
    final con = widget.ten.length - _daGoi.length;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          height: 200,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFFFA24C), Color(0xFFEF4A23)]),
            borderRadius: BorderRadius.circular(24),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _hien ?? '?',
              key: const ValueKey('ten_duoc_goi'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w900),
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          key: const ValueKey('nut_goi'),
          onPressed: _dangQuay ? null : _quay,
          icon: const Icon(Icons.casino_outlined),
          label: Text(chu('pick'), style: const TextStyle(fontSize: 18)),
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _khongLap,
          onChanged: (v) => setState(() {
            _khongLap = v;
            _daGoi.clear();
          }),
          title: Text(chu('noRepeat')),
          subtitle: _khongLap ? Text(chu('left', n: con)) : null,
        ),
      ],
    );
  }
}

/// Chia nhóm ngẫu nhiên.
class ChiaNhomQT extends StatelessWidget {
  const ChiaNhomQT({super.key});

  @override
  Widget build(BuildContext context) => _CanLop(khoa: 'groups', noiDung: (ten) => _ChiaNhom(ten: ten));
}

class _ChiaNhom extends StatefulWidget {
  final List<String> ten;
  const _ChiaNhom({required this.ten});

  @override
  State<_ChiaNhom> createState() => _ChiaNhomState();
}

class _ChiaNhomState extends State<_ChiaNhom> {
  int _soNhom = 4;
  List<List<String>> _kq = [];

  String _vanBan() {
    final b = StringBuffer();
    for (var i = 0; i < _kq.length; i++) {
      b.writeln('${chu('group', n: i + 1)}: ${_kq[i].join(', ')}');
    }
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          Flexible(child: Text(chu('groupCount'))),
          Expanded(
            flex: 2,
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
          key: const ValueKey('nut_chia'),
          onPressed: () => setState(() => _kq = chiaNhom(widget.ten, min(_soNhom, widget.ten.length), Random())),
          icon: const Icon(Icons.shuffle),
          label: Text(chu('makeGroups')),
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
        ),
        if (_kq.isNotEmpty) ...[
          const SizedBox(height: 12),
          for (var i = 0; i < _kq.length; i++)
            Card(
              child: ListTile(
                leading: CircleAvatar(child: Text('${i + 1}')),
                title: Text(chu('group', n: i + 1)),
                subtitle: Text(_kq[i].join(', ')),
              ),
            ),
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _vanBan()));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(chu('copied'))));
            },
            icon: const Icon(Icons.copy),
            label: Text(chu('copy')),
          ),
        ],
      ],
    );
  }
}

/// Bảng điểm đội.
class BangDiemQT extends StatefulWidget {
  const BangDiemQT({super.key});

  @override
  State<BangDiemQT> createState() => _BangDiemQTState();
}

class _BangDiemQTState extends State<BangDiemQT> {
  List<int> _d = [0, 0];
  static const _mau = [Color(0xFF1F6FE5), Color(0xFFD42539), Color(0xFF0B8A6A), Color(0xFFEF6A23), Color(0xFF8A4FD3), Color(0xFF00838F)];

  @override
  void initState() {
    super.initState();
    DiemDoiQT.doc().then((d) {
      if (mounted && d.isNotEmpty) setState(() => _d = d);
    });
  }

  void _doi(void Function() f) {
    setState(f);
    DiemDoiQT.ghi(_d);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(chu('score'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (var i = 0; i < _d.length; i++)
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(children: [
                  Expanded(
                    child: Text(
                      chu('team', n: i + 1),
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: _mau[i % _mau.length]),
                    ),
                  ),
                  IconButton.filledTonal(
                    key: ValueKey('tru_$i'),
                    onPressed: () => _doi(() => _d[i]--),
                    icon: const Icon(Icons.remove),
                  ),
                  SizedBox(
                    width: 72,
                    child: Text(
                      '${_d[i]}',
                      key: ValueKey('diem_$i'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: MauApp.chu),
                    ),
                  ),
                  IconButton.filled(
                    key: ValueKey('cong_$i'),
                    onPressed: () => _doi(() => _d[i]++),
                    icon: const Icon(Icons.add),
                  ),
                ]),
              ),
            ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const ValueKey('nut_them_doi'),
                onPressed: _d.length >= 8 ? null : () => _doi(() => _d = [..._d, 0]),
                icon: const Icon(Icons.add),
                label: Text(chu('addTeam')),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _doi(() => _d = [0, 0]),
                icon: const Icon(Icons.replay),
                label: Text(chu('resetScores')),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

/// Điểm danh: chạm vào tên để đổi Có mặt → Đi muộn → Vắng.
class DiemDanhQT extends StatelessWidget {
  const DiemDanhQT({super.key});

  @override
  Widget build(BuildContext context) => _CanLop(khoa: 'attendance', noiDung: (ten) => _DiemDanh(ten: ten));
}

class _DiemDanh extends StatefulWidget {
  final List<String> ten;
  const _DiemDanh({required this.ten});

  @override
  State<_DiemDanh> createState() => _DiemDanhState();
}

class _DiemDanhState extends State<_DiemDanh> {
  // 0 có mặt, 1 đi muộn, 2 vắng
  late final Map<String, int> _tt = {for (final t in widget.ten) t: 0};
  static const _khoa = ['present', 'late', 'absent'];
  static const _mau = [Color(0xFF0B6553), Color(0xFFF08C00), Color(0xFFD42539)];

  String _baoCao() {
    final d = DateTime.now();
    final b = StringBuffer('${chu('attendance')} ${d.year}-${_hai(d.month)}-${_hai(d.day)}\n');
    for (var k = 0; k < 3; k++) {
      final ds = _tt.entries.where((e) => e.value == k).map((e) => e.key).toList();
      b.writeln('${chu(_khoa[k])}: ${ds.length}${k == 0 || ds.isEmpty ? '' : ' (${ds.join(', ')})'}');
    }
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    final co = _tt.values.where((v) => v == 0).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text('${chu('present')}: $co/${_tt.length}', key: const ValueKey('so_co_mat'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 6),
        for (final t in widget.ten)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(t),
            trailing: Chip(
              label: Text(chu(_khoa[_tt[t] ?? 0]), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              backgroundColor: _mau[_tt[t] ?? 0],
            ),
            onTap: () => setState(() => _tt[t] = ((_tt[t] ?? 0) + 1) % 3),
          ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: _baoCao()));
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(chu('copied'))));
          },
          icon: const Icon(Icons.copy),
          label: Text(chu('copy')),
        ),
      ],
    );
  }
}
