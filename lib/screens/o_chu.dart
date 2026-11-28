import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/luu_tru.dart';
import '../data/o_chu.dart';
import '../data/o_chu_moi_ngay.dart';
import '../main.dart';
import 'cau_giup_viec.dart';
import 'o_chu_moi_ngay.dart';
import '../quoc_te/quoc_te.dart';

const _khoa = 'o_chu';

OChu _mau() => laQuocTe
    ? OChu(
        id: 'mau',
        ten: 'Sample: Geography',
        tuKhoa: 'Map',
        hang: [
          HangO("Earth's natural satellite?", 'Moon'),
          HangO('The planet we live on?', 'Earth'),
          HangO('The largest ocean?', 'Pacific'),
        ],
      )
    : OChu(
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
  TienDoNgay? _homNay;
  int _chuoi = 0;

  @override
  void initState() {
    super.initState();
    _tai();
  }

  Future<void> _tai() async {
    var ds = (await LuuTru.docDanhSach(_khoa)).map(OChu.fromJson).toList();
    if (ds.isEmpty) ds = [_mau()];
    final nay = DateTime.now();
    final homNay = await LuuOChuNgay.doc(maNgay(nay));
    final chuoi = chuoiNgay(await LuuOChuNgay.ngayDaXong(), nay);
    if (mounted) {
      setState(() {
        _ds = ds;
        _homNay = homNay;
        _chuoi = chuoi;
      });
    }
  }

  Future<void> _moNgay() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OChuNgayMan()));
    await _tai();
  }

  /// Thẻ Ô chữ hôm nay ở đầu màn: chủ đề, trạng thái, nút giải.
  Widget _theHomNay() {
    final nay = DateTime.now();
    final o = oChuCuaNgay(nay);
    final t = _homNay;
    final String trangThai;
    if (t != null && t.daXong) {
      trangThai = 'Đã xong trong ${thoiGianVN(t.thoiGian)}${_chuoi > 0 ? ' · 🔥 $_chuoi ngày liền' : ''}';
    } else if (t != null && t.daBatDauGiai) {
      trangThai = 'Đang giải: đã mở ${t.soHangDaMo}/${o.hang.length} hàng';
    } else {
      trangThai = _chuoi > 0 ? '🔥 Đang có chuỗi $_chuoi ngày liền, giải tiếp hôm nay nhé' : 'Mỗi ngày một ô chữ mới, giải xong chia sẻ kết quả';
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: _moNgay,
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFFFA24C), Color(0xFFEF4A23)]),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(children: [
            const Icon(Icons.today, color: Colors.white, size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Ô chữ hôm nay · ${nay.day}/${nay.month}', style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
                Text('Chủ đề: ${o.ten}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(trangThai, style: const TextStyle(color: Colors.white, fontSize: 12.5)),
              ]),
            ),
            const SizedBox(width: 8),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFFE5570B)),
              onPressed: _moNgay,
              child: Text(t != null && t.daXong ? 'Xem lại' : (t != null && t.daBatDauGiai ? 'Giải tiếp' : 'Giải ngay')),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _luu() async {
    await LuuTru.ghiDanhSach(_khoa, _ds!.map((e) => e.toJson()).toList());
    if (mounted) setState(() {});
  }

  Future<void> _sua([OChu? goc]) async {
    if (goc == null &&
        !await GoiQT.duocPhep(context,
            trongGioiHan: _ds!.where((e) => e.id != 'mau').length < GoiQT.soOChu, cau: chu('limCrossword', n: GoiQT.soOChu))) {
      return;
    }
    if (!mounted) return;
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
      appBar: AppBar(title: Text(tx('Ô chữ', 'crossword'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: ds == null ? null : () => _sua(),
        icon: const Icon(Icons.add),
        label: Text(tx('Ô chữ mới', 'newCrossword')),
      ),
      body: ds == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
              children: [
                if (laQuocTe) const SizedBox(height: 12) else const CauGiupViec('o_chu'),
                // Ô chữ mỗi ngày chỉ có đề tiếng Việt: bản quốc tế không hiện
                if (!laQuocTe) _theHomNay(),
                const SizedBox(height: 16),
                Text(tx('Ô chữ của tôi', 'myCrosswords'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: MauApp.chu)),
                const SizedBox(height: 2),
                Text(
                  tx(
                      'Mỗi hàng ngang là một câu hỏi. Chữ ở cột tô màu của các hàng ghép thành từ khóa. '
                          'Kết nối điện thoại với ti vi hoặc máy chiếu, bấm Chơi, mở từng hàng khi học sinh trả lời.',
                      'cwHint'),
                  style: const TextStyle(fontSize: 12.5, color: MauApp.chuPhu),
                ),
                const SizedBox(height: 12),
                for (final o in ds)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.grid_on_outlined, color: Color(0xFFE5570B)),
                      title: Text(o.ten, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(tx('${o.hang.length} hàng ngang · từ khóa ${o.khoa.length} chữ', 'cwInfo', n: o.hang.length, m: o.khoa.length)),
                      onTap: () => _sua(o),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        FilledButton(
                          onPressed: o.loi.isEmpty
                              ? () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _ChoiOChu(o: o)))
                              : null,
                          child: Text(tx('Chơi', 'play')),
                        ),
                        IconButton(
                          tooltip: tx('Xóa', 'delete'),
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
        ten: _ten.text.trim().isEmpty ? '${tx('Ô chữ', 'crossword')} ${_tuKhoa.text.trim()}' : _ten.text.trim(),
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
      appBar: AppBar(title: Text(widget.goc == null ? tx('Ô chữ mới', 'newCrossword') : tx('Sửa ô chữ', 'editCrossword'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          TextField(controller: _ten, onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: tx('Tên ô chữ', 'cwName'), hintText: laQuocTe ? null : 'Ví dụ: Ôn tập Bài 5, Lịch sử 8', border: const OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(
            controller: _tuKhoa,
            onChanged: (_) => _khopSoHang(),
            decoration: InputDecoration(
              labelText: tx('Từ khóa hàng dọc', 'keyword'),
              helperText: k.isEmpty ? tx('Ví dụ: Điện Biên → ĐIỆNBIÊN, cần 8 hàng ngang', 'cwKeyHelp') : tx('Gồm ${k.length} chữ: $k', 'cwKeyLetters', n: k.length, m: k),
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
                    Text(i < k.length ? tx('Hàng ${i + 1} · có chữ ${k[i]}', 'rowHas', n: i + 1, m: k[i]) : tx('Hàng ${i + 1}', 'rowN', n: i + 1), style: const TextStyle(fontWeight: FontWeight.w800)),
                    const Spacer(),
                    IconButton(
                      tooltip: tx('Bỏ hàng', 'removeRow'),
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _hang.removeAt(i)),
                    ),
                  ]),
                  TextField(controller: _hang[i].$1, onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: tx('Câu hỏi', 'question'))),
                  TextField(controller: _hang[i].$2, onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: tx('Đáp án', 'answer'))),
                ]),
              ),
            ),
          OutlinedButton.icon(
            onPressed: () => setState(() => _hang.add((TextEditingController(), TextEditingController()))),
            icon: const Icon(Icons.add),
            label: Text(tx('Thêm hàng ngang', 'addRow')),
          ),
          const SizedBox(height: 12),
          if (loi.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFFFF4D6), borderRadius: BorderRadius.circular(10)),
              child: Text(loi.join('\n'), style: const TextStyle(height: 1.4)),
            )
          else ...[
            Text(tx('Xem trước', 'preview'), style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            LuoiOChu(o: o, mo: List.filled(o.hang.length, true), moKhoa: true),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(_hienTai),
            icon: const Icon(Icons.check),
            label: Text(tx('Lưu ô chữ', 'save')),
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
      // Kiểu chữ tiêu đề chung của app (xanh đậm) đè màu trắng, nên đặt riêng chữ trắng cho nền tối (thầy cô báo 24/11/2026)
      appBar: AppBar(
        backgroundColor: const Color(0xFF14233A),
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
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
              c == null
                  ? tx('Chạm vào số thứ tự của hàng để hiện câu hỏi.', 'tapRow')
                  : tx('Hàng ${c + 1} (${o.hang[c].chu.length} chữ): ${o.hang[c].cauHoi}', 'rowQ', n: c + 1, m: '(${o.hang[c].chu.length}) ${o.hang[c].cauHoi}'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, height: 1.35),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.icon(
              // Chưa chọn hàng thì nút mờ nhưng vẫn đọc được chữ trên nền tối
              style: FilledButton.styleFrom(
                disabledBackgroundColor: Colors.white.withValues(alpha: 0.10),
                disabledForegroundColor: Colors.white60,
              ),
              onPressed: c == null ? null : () => setState(() => _mo[c] = true),
              icon: const Icon(Icons.visibility),
              label: Text(tx('Mở đáp án hàng này', 'revealRow')),
            ),
            FilledButton.tonalIcon(
              onPressed: () => setState(() => _moKhoa = true),
              icon: const Icon(Icons.key),
              label: Text(tx('Mở từ khóa', 'revealKey')),
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
              label: Text(tx('Chơi lại', 'playAgain')),
            ),
          ]),
          if (_moKhoa)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Center(
                child: Text(tx('TỪ KHÓA: ${o.tuKhoa.toUpperCase()}', 'keywordIs', m: o.tuKhoa.toUpperCase()),
                    style: const TextStyle(color: Color(0xFFFFC27A), fontSize: 30, fontWeight: FontWeight.w900)),
              ),
            ),
        ],
      ),
    );
  }
}
