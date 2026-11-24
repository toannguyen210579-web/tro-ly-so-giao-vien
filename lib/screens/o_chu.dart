import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/luu_tru.dart';
import '../data/o_chu.dart';
import '../main.dart';
import 'cau_giup_viec.dart';

const _khoa = 'o_chu';

OChu _mau() => OChu(
      id: 'mau',
      ten: 'Ô chữ mẫu: Quê hương',
      tuKhoa: 'Quê',
      hang: [
        HangO('Loại quả vỏ màu cam, thơm, hay bày trên mâm ngũ quả ngày Tết?', 'Quýt'),
        HangO('Con vật kéo cày quen thuộc của nhà nông?', 'Trâu'),
        HangO('Loại cây thân thẳng, mọc thành lũy quanh làng, dùng đan rổ, làm nhà?', 'Tre'),
      ],
    );

class OChuMan extends StatefulWidget {
  const OChuMan({super.key});

  @override
  State<OChuMan> createState() => _OChuManState();
}

class _OChuManState extends State<OChuMan> {
  List<OChu>? _ds;

  @override
  void initState() {
    super.initState();
    _tai();
  }

  Future<void> _tai() async {
    var ds = (await LuuTru.docDanhSach(_khoa)).map(OChu.fromJson).toList();
    if (ds.isEmpty) ds = [_mau()];
    if (mounted) setState(() => _ds = ds);
  }

  Future<void> _luu() async {
    await LuuTru.ghiDanhSach(_khoa, _ds!.map((e) => e.toJson()).toList());
    if (mounted) setState(() {});
  }

  Future<void> _sua([OChu? goc]) async {
    final kq = await Navigator.of(context).push<OChu>(MaterialPageRoute(builder: (_) => _SuaOChu(goc: goc)));
    if (kq == null) return;
    final i = _ds!.indexWhere((e) => e.id == kq.id);
    if (i >= 0) {
      _ds![i] = kq;
    } else {
      _ds!.insert(0, kq);
    }
    await _luu();
  }

  @override
  Widget build(BuildContext context) {
    final ds = _ds;
    return Scaffold(
      appBar: AppBar(title: const Text('Ô chữ')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: ds == null ? null : () => _sua(),
        icon: const Icon(Icons.add),
        label: const Text('Ô chữ mới'),
      ),
      body: ds == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
              children: [
                const CauGiupViec('o_chu'),
                const Text(
                  'Mỗi hàng ngang là một câu hỏi. Chữ ở cột tô màu của các hàng ghép thành từ khóa. '
                  'Kết nối điện thoại với ti vi hoặc máy chiếu, bấm Chơi, mở từng hàng khi học sinh trả lời.',
                  style: TextStyle(fontSize: 12.5, color: MauApp.chuPhu),
                ),
                const SizedBox(height: 12),
                for (final o in ds)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.grid_on_outlined, color: Color(0xFFE5570B)),
                      title: Text(o.ten, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('${o.hang.length} hàng ngang · từ khóa ${o.khoa.length} chữ'),
                      onTap: () => _sua(o),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        FilledButton(
                          onPressed: o.loi.isEmpty
                              ? () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _ChoiOChu(o: o)))
                              : null,
                          child: const Text('Chơi'),
                        ),
                        IconButton(
                          tooltip: 'Xóa',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            ds.remove(o);
                            await _luu();
                          },
                        ),
                      ]),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _SuaOChu extends StatefulWidget {
  final OChu? goc;
  const _SuaOChu({this.goc});

  @override
  State<_SuaOChu> createState() => _SuaOChuState();
}

class _SuaOChuState extends State<_SuaOChu> {
  late final _ten = TextEditingController(text: widget.goc?.ten ?? '');
  late final _tuKhoa = TextEditingController(text: widget.goc?.tuKhoa ?? '');
  late final List<(TextEditingController, TextEditingController)> _hang = [
    for (final h in widget.goc?.hang ?? <HangO>[]) (TextEditingController(text: h.cauHoi), TextEditingController(text: h.dapAn)),
  ];

  OChu get _hienTai => OChu(
        id: widget.goc?.id == 'mau' ? DateTime.now().microsecondsSinceEpoch.toString() : (widget.goc?.id ?? DateTime.now().microsecondsSinceEpoch.toString()),
        ten: _ten.text.trim().isEmpty ? 'Ô chữ ${_tuKhoa.text.trim()}' : _ten.text.trim(),
        tuKhoa: _tuKhoa.text.trim(),
        hang: [for (final (h, d) in _hang) HangO(h.text.trim(), d.text.trim())],
      );

  void _khopSoHang() {
    final n = chuanHoaO(_tuKhoa.text).length;
    setState(() {
      while (_hang.length < n) {
        _hang.add((TextEditingController(), TextEditingController()));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final o = _hienTai;
    final k = o.khoa;
    final loi = o.loi;
    return Scaffold(
      appBar: AppBar(title: Text(widget.goc == null ? 'Ô chữ mới' : 'Sửa ô chữ')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          TextField(controller: _ten, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Tên ô chữ', hintText: 'Ví dụ: Ôn tập Bài 5, Lịch sử 8', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(
            controller: _tuKhoa,
            onChanged: (_) => _khopSoHang(),
            decoration: InputDecoration(
              labelText: 'Từ khóa hàng dọc',
              helperText: k.isEmpty ? 'Ví dụ: Điện Biên → ĐIỆNBIÊN, cần 8 hàng ngang' : 'Gồm ${k.length} chữ: $k',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < _hang.length; i++)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 4, 10),
                child: Column(children: [
                  Row(children: [
                    Text('Hàng ${i + 1}${i < k.length ? ' · có chữ ${k[i]}' : ''}', style: const TextStyle(fontWeight: FontWeight.w800)),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Bỏ hàng',
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _hang.removeAt(i)),
                    ),
                  ]),
                  TextField(controller: _hang[i].$1, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Câu hỏi')),
                  TextField(controller: _hang[i].$2, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Đáp án')),
                ]),
              ),
            ),
          OutlinedButton.icon(
            onPressed: () => setState(() => _hang.add((TextEditingController(), TextEditingController()))),
            icon: const Icon(Icons.add),
            label: const Text('Thêm hàng ngang'),
          ),
          const SizedBox(height: 12),
          if (loi.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFFFF4D6), borderRadius: BorderRadius.circular(10)),
              child: Text(loi.join('\n'), style: const TextStyle(height: 1.4)),
            )
          else ...[
            const Text('Xem trước', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            LuoiOChu(o: o, mo: List.filled(o.hang.length, true), moKhoa: true),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(_hienTai),
            icon: const Icon(Icons.check),
            label: const Text('Lưu ô chữ'),
          ),
        ],
      ),
    );
  }
}

/// Lưới ô chữ: mỗi hàng dịch sang để chữ từ khóa thẳng một cột (tô màu).
class LuoiOChu extends StatelessWidget {
  final OChu o;
  final List<bool> mo;
  final bool moKhoa;
  final int? dangChon;
  final void Function(int)? bamHang;
  const LuoiOChu({super.key, required this.o, required this.mo, required this.moKhoa, this.dangChon, this.bamHang});

  @override
  Widget build(BuildContext context) {
    final lech = o.doLech;
    final vt = o.viTriKhoa;
    final cot = o.soCot + 1;
    return LayoutBuilder(builder: (context, c) {
      final o1 = (c.maxWidth / cot).clamp(16.0, 52.0);
      return Column(
        children: [
          for (var i = 0; i < o.hang.length; i++)
            GestureDetector(
              onTap: bamHang == null ? null : () => bamHang!(i),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(children: [
                  SizedBox(
                    width: o1,
                    child: Text('${i + 1}',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: o1 * 0.45, color: dangChon == i ? const Color(0xFFE5570B) : MauApp.chuPhu)),
                  ),
                  SizedBox(width: o1 * lech[i]),
                  for (var j = 0; j < o.hang[i].chu.length; j++)
                    Container(
                      width: o1 - 2,
                      height: o1 - 2,
                      margin: const EdgeInsets.all(1),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: j == vt[i] ? const Color(0xFFFFC27A) : (dangChon == i ? const Color(0xFFE3ECF8) : Colors.white),
                        border: Border.all(color: j == vt[i] ? const Color(0xFFE5570B) : const Color(0xFF9AA8BA), width: j == vt[i] ? 2 : 1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        mo[i] || (moKhoa && j == vt[i]) ? o.hang[i].chu[j] : '',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: o1 * 0.5, color: MauApp.chu),
                      ),
                    ),
                ]),
              ),
            ),
        ],
      );
    });
  }
}

class _ChoiOChu extends StatefulWidget {
  final OChu o;
  const _ChoiOChu({required this.o});

  @override
  State<_ChoiOChu> createState() => _ChoiOChuState();
}

class _ChoiOChuState extends State<_ChoiOChu> {
  late final List<bool> _mo = List.filled(widget.o.hang.length, false);
  bool _moKhoa = false;
  int? _chon;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight, DeviceOrientation.portraitUp]);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.o;
    final c = _chon;
    return Scaffold(
      backgroundColor: const Color(0xFF14233A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF14233A),
        foregroundColor: Colors.white,
        title: Text(o.ten),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFF3F5F8), borderRadius: BorderRadius.circular(16)),
            child: LuoiOChu(o: o, mo: _mo, moKhoa: _moKhoa, dangChon: c, bamHang: (i) => setState(() => _chon = i)),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Text(
              c == null ? 'Chạm vào số thứ tự của hàng để hiện câu hỏi.' : 'Hàng ${c + 1} (${o.hang[c].chu.length} chữ): ${o.hang[c].cauHoi}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, height: 1.35),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.icon(
              onPressed: c == null ? null : () => setState(() => _mo[c] = true),
              icon: const Icon(Icons.visibility),
              label: const Text('Mở đáp án hàng này'),
            ),
            FilledButton.tonalIcon(
              onPressed: () => setState(() => _moKhoa = true),
              icon: const Icon(Icons.key),
              label: const Text('Mở từ khóa'),
            ),
            // Nền tối: nút viền trong suốt, chữ trắng. Kiểu chung của app tô nền trắng cho nút viền nên trước đây
            // chữ trắng trên nền trắng thành một nút trắng trơn (lỗi thầy cô báo 24/11/2026).
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                side: const BorderSide(color: Colors.white70, width: 1.4),
              ),
              onPressed: () => setState(() {
                for (var i = 0; i < _mo.length; i++) {
                  _mo[i] = false;
                }
                _moKhoa = false;
                _chon = null;
              }),
              icon: const Icon(Icons.replay),
              label: const Text('Chơi lại'),
            ),
          ]),
          if (_moKhoa)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Center(
                child: Text('TỪ KHÓA: ${o.tuKhoa.toUpperCase()}',
                    style: const TextStyle(color: Color(0xFFFFC27A), fontSize: 30, fontWeight: FontWeight.w900)),
              ),
            ),
        ],
      ),
    );
  }
}
