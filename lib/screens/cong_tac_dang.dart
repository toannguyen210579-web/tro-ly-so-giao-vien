import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import '../services/tep_pdf.dart';
import '../services/van_ban_dang.dart';
import 'cau_giup_viec.dart';
import 'dieu_huong.dart';

const _khoaChiBo = 'dang_chi_bo';
const _khoaNhap = 'dang_sinh_hoat_nhap';

Future<ThongTinChiBo> docChiBo() async {
  final p = await SharedPreferences.getInstance();
  final s = p.getString(_khoaChiBo);
  if (s == null) return ThongTinChiBo();
  try {
    return ThongTinChiBo.fromJson(Map<String, dynamic>.from(jsonDecode(s) as Map));
  } catch (_) {
    return ThongTinChiBo();
  }
}

Future<void> luuChiBo(ThongTinChiBo cb) async {
  final p = await SharedPreferences.getInstance();
  await p.setString(_khoaChiBo, jsonEncode(cb.toJson()));
}

/// Mục Công tác Đảng: soạn biên bản sinh hoạt chi bộ, nghị quyết chi bộ tháng đúng thể thức văn bản Đảng.
class CongTacDang extends StatefulWidget {
  const CongTacDang({super.key});

  @override
  State<CongTacDang> createState() => _CongTacDangState();
}

class _CongTacDangState extends State<CongTacDang> {
  ThongTinChiBo? _cb;

  @override
  void initState() {
    super.initState();
    docChiBo().then((v) {
      if (mounted) setState(() => _cb = v);
    });
  }

  Future<void> _suaChiBo() async {
    final cb = _cb ?? ThongTinChiBo();
    final ct = TextEditingController(text: cb.capTren);
    final chi = TextEditingController(text: cb.chiBo);
    final dd = TextEditingController(text: cb.diaDanh);
    final bt = TextEditingController(text: cb.biThu);
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(c).viewInsets.bottom + 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Thông tin chi bộ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              const Text('Ghi một lần, app nhớ cho các lần sau.', style: TextStyle(color: MauApp.chuPhu)),
              const SizedBox(height: 12),
              TextField(controller: ct, decoration: const InputDecoration(labelText: 'Cấp ủy cấp trên trực tiếp', hintText: 'Ví dụ: Đảng bộ xã Hòa Thắng')),
              TextField(controller: chi, decoration: const InputDecoration(labelText: 'Tên chi bộ', hintText: 'Ví dụ: Chi bộ Trường THCS Lê Lợi')),
              TextField(controller: dd, decoration: const InputDecoration(labelText: 'Địa danh ghi ở ngày tháng', hintText: 'Ví dụ: Hòa Thắng')),
              TextField(controller: bt, decoration: const InputDecoration(labelText: 'Họ tên Bí thư Chi bộ')),
              const SizedBox(height: 16),
              FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Lưu')),
            ],
          ),
        ),
      ),
    );
    if (ok != true) return;
    final moi = ThongTinChiBo(capTren: ct.text.trim(), chiBo: chi.text.trim(), diaDanh: dd.text.trim(), biThu: bt.text.trim());
    await luuChiBo(moi);
    if (mounted) setState(() => _cb = moi);
  }

  Future<void> _moSoan() async {
    if (!(_cb?.du ?? false)) {
      await _suaChiBo();
      if (!(_cb?.du ?? false)) return;
    }
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => SoanSinhHoatChiBo(chiBo: _cb!)));
  }

  @override
  Widget build(BuildContext context) {
    final cb = _cb;
    return Scaffold(
      appBar: AppBar(title: const Text('Công tác Đảng')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const CauGiupViec('dang'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.groups_rounded),
              title: Text(cb == null || !cb.du ? 'Ghi thông tin chi bộ' : cb.chiBo),
              subtitle: Text(cb == null || !cb.du ? 'Cấp ủy cấp trên, tên chi bộ, địa danh, bí thư' : '${cb.capTren} · ${cb.diaDanh}'),
              trailing: const Icon(Icons.edit_outlined),
              onTap: _suaChiBo,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.description_rounded),
              title: const Text('Sinh hoạt chi bộ thường kỳ'),
              subtitle: const Text('Ghi một lần, xuất cả biên bản và nghị quyết chi bộ tháng (tệp Word đúng thể thức văn bản Đảng)'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _moSoan,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.question_answer_rounded),
              title: const Text('Hỏi về công tác Đảng'),
              subtitle: const Text('Điều lệ Đảng, sinh hoạt chi bộ, thủ tục đảng viên; có dẫn nguồn văn bản'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => moHoiTroLy(context),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Nội dung thầy cô nhập chỉ lưu trên điện thoại, không gửi lên máy chủ. '
            'Không nhập tài liệu có độ mật vào app.',
            style: TextStyle(color: MauApp.chuPhu, height: 1.4),
          ),
        ],
      ),
    );
  }
}

/// Màn soạn một buổi sinh hoạt chi bộ: điền nhanh, xuất biên bản và nghị quyết.
class SoanSinhHoatChiBo extends StatefulWidget {
  final ThongTinChiBo chiBo;
  const SoanSinhHoatChiBo({super.key, required this.chiBo});

  @override
  State<SoanSinhHoatChiBo> createState() => _SoanSinhHoatChiBoState();
}

class _SoanSinhHoatChiBoState extends State<SoanSinhHoatChiBo> {
  DateTime _ngay = DateTime.now();
  final _o = <String, TextEditingController>{
    for (final k in ['gbd', 'gkt', 'dd', 'ct', 'cvct', 'tk', 'tong', 'comat', 'vcl', 'vkl', 'tt', 'kq', 'tl', 'ph', 'kl', 'tan', 'sobb', 'sonq'])
      k: TextEditingController(),
  };

  @override
  void initState() {
    super.initState();
    _o['cvct']!.text = 'Bí thư Chi bộ';
    _o['ct']!.text = widget.chiBo.biThu;
    _docNhap();
  }

  Future<void> _docNhap() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_khoaNhap);
    if (s == null) return;
    try {
      final j = Map<String, dynamic>.from(jsonDecode(s) as Map);
      for (final e in _o.entries) {
        final v = j[e.key];
        if (v is String && v.isNotEmpty) e.value.text = v;
      }
      final n = DateTime.tryParse(j['ngay'] as String? ?? '');
      if (n != null && mounted) setState(() => _ngay = n);
    } catch (_) {}
  }

  Future<void> _luuNhap() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_khoaNhap, jsonEncode({for (final e in _o.entries) e.key: e.value.text, 'ngay': _ngay.toIso8601String()}));
  }

  @override
  void dispose() {
    _luuNhap();
    for (final c in _o.values) {
      c.dispose();
    }
    super.dispose();
  }

  int _so(String k) => int.tryParse(_o[k]!.text.trim()) ?? 0;

  SinhHoatChiBo get _sh => SinhHoatChiBo(
        ngay: _ngay,
        gioBatDau: _o['gbd']!.text.trim(),
        gioKetThuc: _o['gkt']!.text.trim(),
        diaDiem: _o['dd']!.text.trim(),
        chuTri: _o['ct']!.text.trim(),
        chucVuChuTri: _o['cvct']!.text.trim(),
        thuKy: _o['tk']!.text.trim(),
        tongSo: _so('tong'),
        coMat: _so('comat'),
        vangCoLyDo: _o['vcl']!.text.trim(),
        vangKhongLyDo: _o['vkl']!.text.trim(),
        thongTin: _o['tt']!.text,
        ketQua: _o['kq']!.text,
        thaoLuan: _o['tl']!.text,
        phuongHuong: _o['ph']!.text,
        ketLuan: _o['kl']!.text,
        tanThanh: _o['tan']!.text.trim().isEmpty ? _so('comat') : _so('tan'),
      );

  Future<void> _xuat(bool bienBan) async {
    final sh = _sh;
    if (sh.tongSo <= 0 || sh.coMat <= 0 || sh.coMat > sh.tongSo) {
      _bao('Thầy cô ghi tổng số đảng viên và số có mặt (số có mặt không lớn hơn tổng số).');
      return;
    }
    await _luuNhap();
    // Số nhỏ hơn 10 thêm số 0 phía trước (Hướng dẫn 05-HD/VPTW)
    String so(String k) {
      final n = int.tryParse(_o[k]!.text.trim());
      return n == null ? '' : (n < 10 ? '0$n' : '$n');
    }

    final vb = bienBan ? bienBanChiBo(widget.chiBo, sh, so: so('sobb')) : nghiQuyetChiBo(widget.chiBo, sh, so: so('sonq'));
    final ten = '${bienBan ? 'Bien_ban' : 'Nghi_quyet'}_chi_bo_thang_${sh.ngay.month}_${sh.ngay.year}_${dauThoiGian(DateTime.now())}.docx';
    final f = File('${(await thuMucApp('xuat')).path}/$ten');
    await f.writeAsBytes(taoDocxDang(vb));
    await Share.shareXFiles([XFile(f.path)]);
  }

  void _bao(String s) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  Widget _o1(String k, String nhan, {String? goiY, int dong = 1, bool so = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: _o[k],
          minLines: dong,
          maxLines: dong == 1 ? 1 : null,
          keyboardType: so ? TextInputType.number : (dong > 1 ? TextInputType.multiline : TextInputType.text),
          decoration: InputDecoration(labelText: nhan, hintText: goiY, border: const OutlineInputBorder(), alignLabelWithHint: dong > 1),
        ),
      );

  Widget _tieuDe(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 10, 0, 8),
        child: Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: MauApp.xanhDam)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sinh hoạt chi bộ')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          Text(widget.chiBo.chiBo, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          _tieuDe('Thời gian, thành phần'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_rounded),
            title: Text('Ngày sinh hoạt: ${_ngay.day}/${_ngay.month}/${_ngay.year}'),
            trailing: const Icon(Icons.edit_calendar_rounded),
            onTap: () async {
              final d = await showDatePicker(context: context, initialDate: _ngay, firstDate: DateTime(2020), lastDate: DateTime(2100));
              if (d != null) setState(() => _ngay = d);
            },
          ),
          Row(children: [
            Expanded(child: _o1('gbd', 'Bắt đầu lúc', goiY: '14 giờ 00')),
            const SizedBox(width: 8),
            Expanded(child: _o1('gkt', 'Kết thúc lúc', goiY: '16 giờ 30')),
          ]),
          _o1('dd', 'Địa điểm', goiY: 'Phòng họp nhà trường'),
          _o1('ct', 'Chủ trì (họ tên)'),
          _o1('cvct', 'Chức vụ người chủ trì'),
          _o1('tk', 'Thư ký (họ tên)'),
          Row(children: [
            Expanded(child: _o1('tong', 'Tổng số đảng viên', so: true)),
            const SizedBox(width: 8),
            Expanded(child: _o1('comat', 'Có mặt', so: true)),
          ]),
          _o1('vcl', 'Vắng có lý do (tên, lý do)', goiY: 'Ví dụ: đ/c Hoa (ốm)'),
          _o1('vkl', 'Vắng không lý do'),
          _tieuDe('Nội dung (mỗi ý một dòng)'),
          _o1('tt', '1. Thông tin thời sự, văn bản cấp trên', dong: 3),
          _o1('kq', '2. Kết quả thực hiện nhiệm vụ tháng', dong: 4),
          _o1('tl', '3. Ý kiến thảo luận', goiY: 'Đ/c ...: ...', dong: 3),
          _o1('ph', '4. Phương hướng, nhiệm vụ tháng tới', dong: 4),
          _o1('kl', '5. Kết luận của chủ trì', dong: 3),
          _o1('tan', 'Số đảng viên tán thành (để trống = tất cả có mặt)', so: true),
          _tieuDe('Số văn bản (không bắt buộc)'),
          Row(children: [
            Expanded(child: _o1('sobb', 'Số biên bản', goiY: '05', so: true)),
            const SizedBox(width: 8),
            Expanded(child: _o1('sonq', 'Số nghị quyết', goiY: '05', so: true)),
          ]),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _xuat(true),
                icon: const Icon(Icons.description_rounded),
                label: const Text('Xuất biên bản'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _xuat(false),
                icon: const Icon(Icons.gavel_rounded),
                label: const Text('Xuất nghị quyết'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
