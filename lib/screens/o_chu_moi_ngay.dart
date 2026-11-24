import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../data/luu_tru.dart';
import '../data/o_chu.dart';
import '../data/o_chu_moi_ngay.dart';
import '../main.dart';
import 'o_chu.dart';

/// Ô chữ mỗi ngày: thầy cô tự giải bằng cách gõ đáp án từng hàng, đoán từ khóa, giải xong chia sẻ kết quả.
class OChuNgayMan extends StatefulWidget {
  /// Ngày chơi; để trống là hôm nay.
  final DateTime? ngay;
  const OChuNgayMan({super.key, this.ngay});

  @override
  State<OChuNgayMan> createState() => _OChuNgayManState();
}

class _OChuNgayManState extends State<OChuNgayMan> {
  late final DateTime _ngay = widget.ngay ?? DateTime.now();
  late final OChu _o = oChuCuaNgay(_ngay);
  final _go = TextEditingController();
  TienDoNgay? _t;
  int _chuoi = 0;
  int? _chon;
  String? _bao;
  bool _baoDung = false;

  @override
  void initState() {
    super.initState();
    _tai();
  }

  @override
  void dispose() {
    _go.dispose();
    super.dispose();
  }

  Future<void> _tai() async {
    final ma = maNgay(_ngay);
    final daLuu = await LuuOChuNgay.doc(ma);
    final TienDoNgay t;
    if (daLuu == null || daLuu.hang.length != _o.hang.length || daLuu.sai.length != _o.hang.length) {
      t = TienDoNgay.moi(ma, _o.hang.length, DateTime.now());
      await LuuOChuNgay.ghi(t);
    } else {
      t = daLuu;
    }
    final chuoi = chuoiNgay(await LuuOChuNgay.ngayDaXong(), _ngay);
    if (!mounted) return;
    setState(() {
      _t = t;
      _chuoi = chuoi;
      _chon = t.daXong ? null : t.hangKeTiep(-1);
    });
  }

  Future<void> _luu() async {
    final t = _t!;
    await LuuOChuNgay.ghi(t);
    if (t.daXong) {
      final chuoi = chuoiNgay(await LuuOChuNgay.ngayDaXong(), _ngay);
      if (mounted) setState(() => _chuoi = chuoi);
    }
  }

  void _traLoi() {
    final t = _t, c = _chon;
    if (t == null || c == null || _go.text.trim().isEmpty) return;
    final dung = t.traLoi(_o, c, _go.text, DateTime.now());
    if (dung) {
      HapticFeedback.mediumImpact();
      _go.clear();
    } else {
      HapticFeedback.heavyImpact();
    }
    setState(() {
      _baoDung = dung;
      _bao = dung ? 'Chính xác!' : 'Chưa đúng, thử lại nhé.';
      if (dung) _chon = t.hangKeTiep(c);
    });
    _luu();
  }

  void _moDapAn() {
    final t = _t, c = _chon;
    if (t == null || c == null) return;
    t.moDapAn(c, DateTime.now());
    _go.clear();
    setState(() {
      _bao = null;
      _chon = t.hangKeTiep(c);
    });
    _luu();
  }

  Future<void> _doanKhoa() async {
    final t = _t;
    if (t == null) return;
    final go = await showDialog<String>(context: context, builder: (_) => _HopDoanKhoa(soChu: _o.khoa.length));
    if (go == null || go.trim().isEmpty || !mounted) return;
    final dung = t.doanTuKhoa(_o, go, DateTime.now());
    if (dung) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.heavyImpact();
    }
    setState(() {
      _baoDung = dung;
      _bao = dung ? 'Đoán đúng từ khóa!' : 'Từ khóa chưa đúng, giải thêm vài hàng rồi đoán lại nhé.';
      if (dung) _chon = null;
    });
    _luu();
  }

  Future<void> _luuVaoDanhSach() async {
    final ds = await LuuTru.docDanhSach('o_chu');
    final ten = '${_o.ten} (Ô chữ ngày ${_ngay.day}/${_ngay.month})';
    final daCo = ds.any((e) => e['k'] == _o.tuKhoa && (e['ten'] as String? ?? '').startsWith(_o.ten));
    if (!daCo) {
      ds.insert(0, OChu(id: DateTime.now().microsecondsSinceEpoch.toString(), ten: ten, tuKhoa: _o.tuKhoa, hang: _o.hang).toJson());
      await LuuTru.ghiDanhSach('o_chu', ds);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(daCo ? 'Ô chữ này đã có trong danh sách của thầy cô.' : 'Đã lưu vào danh sách Ô chữ. Bấm "Chơi" ở đó để chiếu lên lớp.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    return Scaffold(
      appBar: AppBar(title: const Text('Ô chữ mỗi ngày')),
      body: t == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [
                Row(children: [
                  Expanded(child: Text(ngayDayDu(_ngay), style: const TextStyle(color: MauApp.chuPhu, fontWeight: FontWeight.w600))),
                  if (_chuoi > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFFFA24C), Color(0xFFEF4A23)]),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('🔥 $_chuoi ngày liền', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                    ),
                ]),
                const SizedBox(height: 6),
                Text('Chủ đề: ${_o.ten}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: MauApp.chu)),
                Text('${_o.hang.length} hàng ngang, cột tô màu ghép thành từ khóa ${_o.khoa.length} chữ cái.',
                    style: const TextStyle(fontSize: 13, color: MauApp.chuPhu)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [
                    BoxShadow(color: Color(0x1A14233A), blurRadius: 10, offset: Offset(0, 3)),
                  ]),
                  child: LuoiOChu(
                    o: _o,
                    mo: [for (final v in t.hang) t.daXong || v != TrangThaiHang.chua],
                    moKhoa: t.daXong,
                    dangChon: t.daXong ? null : _chon,
                    bamHang: t.daXong
                        ? null
                        : (i) => setState(() {
                              if (t.hang[i] == TrangThaiHang.chua) _chon = i;
                              _bao = null;
                            }),
                  ),
                ),
                const SizedBox(height: 14),
                if (t.daXong) _ketQua(t) else ..._dangGiai(t),
              ],
            ),
    );
  }

  List<Widget> _dangGiai(TienDoNgay t) {
    final c = _chon;
    return [
      if (c == null)
        const Text('Chạm vào số thứ tự của hàng để xem câu hỏi.', style: TextStyle(color: MauApp.chuPhu))
      else ...[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF1F6FE5), Color(0xFF14A3A1)]),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Hàng ${c + 1} · ${_o.hang[c].chu.length} chữ cái',
                style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(_o.hang[c].cauHoi, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, height: 1.35)),
          ]),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _go,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _traLoi(),
          decoration: InputDecoration(
            labelText: 'Đáp án hàng ${c + 1}',
            hintText: 'Gõ có dấu hay không dấu đều được',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(tooltip: 'Trả lời', icon: const Icon(Icons.send, color: MauApp.xanhTroi), onPressed: _traLoi),
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: FilledButton.icon(onPressed: _traLoi, icon: const Icon(Icons.check), label: const Text('Trả lời')),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(onPressed: _moDapAn, icon: const Icon(Icons.visibility_outlined), label: const Text('Xem đáp án')),
          ),
        ]),
      ],
      if (_bao != null)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(_bao!,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: _baoDung ? MauApp.xanhLa : const Color(0xFFD42539))),
        ),
      const SizedBox(height: 12),
      FilledButton.tonalIcon(
        onPressed: _doanKhoa,
        icon: const Icon(Icons.key),
        label: const Text('Đoán từ khóa hàng dọc'),
      ),
      const SizedBox(height: 10),
      Text(
        'Đã mở ${t.soHangDaMo}/${_o.hang.length} hàng${t.tongSai > 0 ? ' · sai ${t.tongSai} lần' : ''}. '
        'Đoán đúng từ khóa sớm là xong ô chữ hôm nay.',
        style: const TextStyle(fontSize: 12.5, color: MauApp.chuPhu),
      ),
    ];
  }

  Widget _ketQua(TienDoNgay t) {
    Widget dong(String a, String b) => Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(children: [
            Expanded(child: Text(a, style: const TextStyle(color: Colors.white70))),
            Text(b, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          ]),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFFFA24C), Color(0xFFEF4A23)]),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('🎉 Xong ô chữ hôm nay!', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text('Từ khóa: ${_o.tuKhoa.toUpperCase()}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          dong('Thời gian', thoiGianVN(t.thoiGian)),
          dong('Giải đúng', '${t.soHangGiai}/${_o.hang.length} hàng'),
          dong('Số lần sai', '${t.tongSai}'),
          if (t.doanKhoa) dong('Đoán ra từ khóa', '🔑'),
          dong('Chuỗi ngày', '$_chuoi ngày liền'),
        ]),
      ),
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: () => Share.share(vanBanChiaSe(t, _o, _ngay, _chuoi)),
        icon: const Icon(Icons.share),
        label: const Text('Chia sẻ kết quả'),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: _luuVaoDanhSach,
        icon: const Icon(Icons.cast_for_education),
        label: const Text('Lưu để chiếu lên lớp'),
      ),
      const SizedBox(height: 10),
      const Text('Ô chữ mới có lúc 0 giờ ngày mai.', textAlign: TextAlign.center, style: TextStyle(color: MauApp.chuPhu)),
    ]);
  }
}

class _HopDoanKhoa extends StatefulWidget {
  final int soChu;
  const _HopDoanKhoa({required this.soChu});

  @override
  State<_HopDoanKhoa> createState() => _HopDoanKhoaState();
}

class _HopDoanKhoaState extends State<_HopDoanKhoa> {
  final _o = TextEditingController();

  @override
  void dispose() {
    _o.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Đoán từ khóa'),
      content: TextField(
        controller: _o,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (v) => Navigator.pop(context, v),
        decoration: InputDecoration(labelText: 'Từ khóa ${widget.soChu} chữ cái', border: const OutlineInputBorder()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Thôi')),
        FilledButton(onPressed: () => Navigator.pop(context, _o.text), child: const Text('Đoán')),
      ],
    );
  }
}
