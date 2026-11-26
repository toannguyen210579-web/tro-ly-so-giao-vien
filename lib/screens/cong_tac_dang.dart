import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/lich.dart';
import '../main.dart';
import '../services/tep_pdf.dart';
import '../services/van_ban_dang.dart';
import 'bieu_tuong.dart';
import 'cau_giup_viec.dart';
import 'dieu_huong.dart';
import '../services/chia_se.dart';

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
/// Phần soạn biên bản, nghị quyết chi bộ đang ẩn (thầy chốt 21/11/2026). Bật lại khi dựng app:
/// flutter build ... --dart-define=CHI_BO_VAN_BAN=true
/// Nền tảng chuyển đổi số cho đảng viên: thu nộp đảng phí, chuyển sinh hoạt đảng.
const congDichVuDang = 'https://dichvucong.dcs.vn/web/home';

const coSoanVanBanChiBo = bool.fromEnvironment('CHI_BO_VAN_BAN');

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
      useSafeArea: true, // không đè lên thanh giờ trên đầu máy
      showDragHandle: true,
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

  /// Mở iCPV - Book (Viettel phát triển cho cơ quan Đảng) trên kho ứng dụng; đã cài thì kho có nút "Mở".
  Future<void> _moIcpv() async {
    final url = Platform.isIOS
        ? 'https://apps.apple.com/vn/app/id6744908429'
        : 'https://play.google.com/store/search?q=iCPV%20-%20Book&c=apps';
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không mở được kho ứng dụng. Thầy cô tìm "iCPV - Book" trong App Store hoặc CH Play.')));
    }
  }

  Future<void> _moDichVuCong() async {
    final ok = await launchUrl(Uri.parse(congDichVuDang), mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Không mở được, thầy cô vào dichvucong.dcs.vn bằng trình duyệt.')));
    }
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
          if (coSoanVanBanChiBo) ...[
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
          ],
          // Mỗi việc một biểu tượng kiểu app trên điện thoại (thầy cô yêu cầu 24/11/2026). Ô căn trên, cao theo cỡ chữ.
          // Hai mục mở sang nơi khác dùng biểu tượng riêng của app (không làm giống logo của đơn vị khác, chốt 24/11/2026),
          // có dấu "mở ra ngoài" và dòng ghi đúng nơi sẽ mở.
          GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisExtent: chieuCaoOTienIch(context, size: 60, coChuThich: true, moRaNgoai: true),
              mainAxisSpacing: 6,
            ),
            children: [
              OTienIch(
                  ma: 'dang_lich',
                  icon: Icons.event_available_rounded,
                  ten: 'Lịch họp chi bộ',
                  size: 60,
                  bam: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ManLichHopChiBo()))),
              OTienIch(
                  ma: 'dang_phi',
                  icon: Icons.savings_rounded,
                  ten: 'Tính đảng phí',
                  size: 60,
                  bam: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ManDangPhi()))),
              OTienIch(
                  ma: 'dang_dvc',
                  icon: Icons.assignment_turned_in_rounded,
                  ten: 'Dịch vụ công của Đảng',
                  chuThich: 'Mở trang dichvucong.dcs.vn',
                  moRaNgoai: true,
                  size: 60,
                  bam: _moDichVuCong),
              OTienIch(
                  ma: 'dang_so_tay',
                  icon: Icons.book_rounded,
                  ten: 'Sổ tay đảng viên',
                  chuThich: 'Mở app iCPV - Book',
                  moRaNgoai: true,
                  size: 60,
                  bam: _moIcpv),
              OTienIch(
                  ma: 'dang_hoi',
                  icon: Icons.forum_rounded,
                  ten: 'Hỏi công tác Đảng',
                  size: 60,
                  bam: () => moHoiTroLy(context)),
            ],
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
    await guiTep([f.path], context: context);
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


/// Tính đảng phí hằng tháng theo Quy định số 01-QĐ/TW ngày 03/02/2026 của Bộ Chính trị.
class ManDangPhi extends StatefulWidget {
  const ManDangPhi({super.key});

  @override
  State<ManDangPhi> createState() => _ManDangPhiState();
}

class _ManDangPhiState extends State<ManDangPhi> {
  NhomDangPhi _nhom = NhomDangPhi.coBhxh;
  final _tien = TextEditingController();
  int _vung = 1;
  bool _giam = false;

  @override
  void dispose() {
    _tien.dispose();
    super.dispose();
  }

  bool get _canTien => _nhom == NhomDangPhi.coBhxh || _nhom == NhomDangPhi.nghiOmThaiSan || _nhom == NhomDangPhi.huuTri;
  bool get _canVung => _nhom == NhomDangPhi.chuaDenTuoiHuu || _nhom == NhomDangPhi.duTuoiChuaHuu;

  String get _nhanTien => switch (_nhom) {
        NhomDangPhi.nghiOmThaiSan => 'Tiền trợ cấp ốm đau, thai sản BHXH trả trong tháng (đồng)',
        NhomDangPhi.huuTri => 'Lương hưu hằng tháng (đồng)',
        _ => 'Tiền lương làm căn cứ đóng BHXH của tháng trước (đồng)',
      };

  String get _canCu => switch (_nhom) {
        NhomDangPhi.coBhxh => '1% tiền lương làm căn cứ đóng bảo hiểm xã hội của tháng trước',
        NhomDangPhi.nghiOmThaiSan => '1% tiền trợ cấp do cơ quan bảo hiểm xã hội chi trả',
        NhomDangPhi.huuTri => '0,5% mức lương hưu',
        NhomDangPhi.hocSinh => '5.000 đồng mỗi tháng',
        NhomDangPhi.chuaDenTuoiHuu => '0,3% lương tối thiểu vùng (năm 2026, 2027); 0,5% từ năm 2028',
        NhomDangPhi.duTuoiChuaHuu => '0,2% lương tối thiểu vùng (năm 2026, 2027); 0,3% từ năm 2028',
      };

  @override
  Widget build(BuildContext context) {
    final soTien = int.tryParse(_tien.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    final muc = tinhDangPhi(_nhom, soTien: soTien, vung: _vung, nam: DateTime.now().year, giamMotNua: _giam);
    final coKq = !_canTien || soTien > 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Tính đảng phí')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<NhomDangPhi>(
            isExpanded: true,
            initialValue: _nhom,
            decoration: const InputDecoration(labelText: 'Đảng viên thuộc nhóm', border: OutlineInputBorder()),
            items: [
              for (final n in NhomDangPhi.values)
                DropdownMenuItem(value: n, child: Text(tenNhomDangPhi[n]!, maxLines: 2, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) => setState(() => _nhom = v ?? _nhom),
          ),
          const SizedBox(height: 12),
          if (_canTien)
            TextField(
              controller: _tien,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(labelText: _nhanTien, border: const OutlineInputBorder()),
            ),
          if (_canVung)
            DropdownButtonFormField<int>(
              isExpanded: true,
              initialValue: _vung,
              decoration: const InputDecoration(labelText: 'Vùng lương tối thiểu nơi cư trú', border: OutlineInputBorder()),
              items: [
                for (final e in luongToiThieuVung.entries)
                  DropdownMenuItem(value: e.key, child: Text('Vùng ${e.key}: ${tienVN(e.value)}/tháng')),
              ],
              onChanged: (v) => setState(() => _vung = v ?? _vung),
            ),
          if (_nhom != NhomDangPhi.hocSinh)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _giam,
              onChanged: (v) => setState(() => _giam = v),
              title: const Text('Người có công, hưởng trợ cấp bệnh binh, mất sức lao động, bảo trợ xã hội hằng tháng'),
              subtitle: const Text('Đóng bằng 50% mức của nhóm tương ứng'),
            ),
          const SizedBox(height: 12),
          Card(
            color: const Color(0xFFFFF4E5),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Đảng phí mỗi tháng', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(coKq ? tienVN(muc) : 'Nhập số tiền để tính',
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFFC62828))),
                  const SizedBox(height: 6),
                  Text('Cách tính: $_canCu${_giam ? ', giảm 50%' : ''}.', style: const TextStyle(height: 1.4)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () async {
              final ok = await launchUrl(Uri.parse(congDichVuDang), mode: LaunchMode.externalApplication);
              if (!ok && context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('Không mở được, thầy cô vào dichvucong.dcs.vn bằng trình duyệt.')));
              }
            },
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('Nộp đảng phí trực tuyến'),
          ),
          const SizedBox(height: 16),
          const Text('Cách nộp', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: MauApp.xanhDam)),
          const SizedBox(height: 6),
          const Text(
            'Đóng hằng tháng qua Cổng Dịch vụ công quốc gia hoặc nộp trực tiếp cho chi bộ. '
            'Nộp trực tuyến trên Nền tảng chuyển đổi số cho đảng viên (dichvucong.dcs.vn): đăng nhập bằng tài khoản định danh điện tử VNeID, chọn "Thu nộp đảng phí", kiểm tra số tiền kỳ này, chọn ngân hàng để thanh toán, xong có biên lai. Có thể nộp hộ cho đảng viên khác. '
            'Không đóng đảng phí 3 tháng trong năm mà không có lý do chính đáng thì chi bộ xem xét, đề nghị xóa tên.',
            style: TextStyle(height: 1.45),
          ),
          const SizedBox(height: 12),
          const Text(
            'Căn cứ: Quy định số 01-QĐ/TW ngày 03/02/2026 của Bộ Chính trị về chế độ đảng phí (hiệu lực từ 01/02/2026, thay Quyết định số 342-QĐ/TW); '
            'lương tối thiểu vùng theo Nghị định số 293/2025/NĐ-CP. Các trường hợp miễn, giảm đảng phí do cấp ủy xem xét.',
            style: TextStyle(color: MauApp.chuPhu, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }
}


/// Nhắc họp chi bộ thường kỳ: tạo 12 buổi họp tới trong Lịch công tác, nhắc trước một ngày.
class ManLichHopChiBo extends StatefulWidget {
  const ManLichHopChiBo({super.key});

  @override
  State<ManLichHopChiBo> createState() => _ManLichHopChiBoState();
}

class _ManLichHopChiBoState extends State<ManLichHopChiBo> {
  static const _khoa = 'dang_lich_hop';
  static const _tienTo = 'chibo_';
  int _ngay = 5;
  TimeOfDay _gio = const TimeOfDay(hour: 14, minute: 0);
  bool _bat = false;
  List<ViecHan> _sap = [];

  @override
  void initState() {
    super.initState();
    _doc();
  }

  Future<void> _doc() async {
    final p = await SharedPreferences.getInstance();
    final j = p.getString(_khoa);
    final ds = (await docViec()).where((v) => v.id.startsWith(_tienTo) && !v.xong && v.han.isAfter(DateTime.now())).toList();
    if (!mounted) return;
    setState(() {
      if (j != null) {
        final m = jsonDecode(j) as Map<String, dynamic>;
        _ngay = m['ngay'] as int? ?? 5;
        _gio = TimeOfDay(hour: m['gio'] as int? ?? 14, minute: m['phut'] as int? ?? 0);
        _bat = m['bat'] as bool? ?? false;
      }
      _sap = ds;
    });
  }

  Future<void> _luu(bool bat) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_khoa, jsonEncode({'ngay': _ngay, 'gio': _gio.hour, 'phut': _gio.minute, 'bat': bat}));
    final ds = await docViec();
    for (final v in ds.where((v) => v.id.startsWith(_tienTo))) {
      await NhacHan.huy(v);
    }
    ds.removeWhere((v) => v.id.startsWith(_tienTo));
    final moi = <ViecHan>[];
    if (bat) {
      for (final d in lichHopChiBo(_ngay, _gio.hour, _gio.minute)) {
        moi.add(ViecHan(
          id: '$_tienTo${d.year}${d.month.toString().padLeft(2, '0')}',
          ten: 'Họp chi bộ thường kỳ tháng ${d.month}/${d.year}',
          han: d,
          ghiChu: 'Chuẩn bị dự thảo nghị quyết, biên bản trong mục Công tác Đảng',
        ));
      }
      await NhacHan.xinQuyen();
      for (final v in moi) {
        await NhacHan.datNhac(v);
      }
    }
    await ghiViec([...ds, ...moi]);
    if (!mounted) return;
    setState(() {
      _bat = bat;
      _sap = moi;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(bat ? 'Đã đặt nhắc 12 buổi họp chi bộ tới, xem trong Lịch công tác' : 'Đã tắt nhắc họp chi bộ')));
  }

  String _hai(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lịch nhắc họp chi bộ')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<int>(
            initialValue: _ngay,
            decoration: const InputDecoration(labelText: 'Ngày họp hằng tháng', border: OutlineInputBorder()),
            items: [for (var d = 1; d <= 31; d++) DropdownMenuItem(value: d, child: Text('Ngày $d'))],
            onChanged: (v) => setState(() => _ngay = v ?? _ngay),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule_rounded),
            title: Text('Giờ họp: ${_hai(_gio.hour)}:${_hai(_gio.minute)}'),
            trailing: const Icon(Icons.edit_rounded),
            onTap: () async {
              final g = await showTimePicker(context: context, initialTime: _gio);
              if (g != null) setState(() => _gio = g);
            },
          ),
          const Text('Tháng không có ngày đã chọn (ví dụ ngày 31) thì họp vào ngày cuối tháng. Điện thoại nhắc trước một ngày.',
              style: TextStyle(color: MauApp.chuPhu, height: 1.4)),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _luu(true),
            icon: const Icon(Icons.alarm_on_rounded),
            label: Text(_bat ? 'Cập nhật lịch nhắc' : 'Bật nhắc họp chi bộ'),
          ),
          if (_bat)
            TextButton.icon(
              onPressed: () => _luu(false),
              icon: const Icon(Icons.alarm_off_rounded),
              label: const Text('Tắt nhắc'),
            ),
          if (_sap.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Các buổi họp tới', style: TextStyle(fontWeight: FontWeight.w900, color: MauApp.xanhDam)),
            for (final v in _sap.take(4))
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_rounded),
                title: Text(v.ten),
                subtitle: Text('${_hai(v.han.hour)}:${_hai(v.han.minute)} ngày ${_hai(v.han.day)}/${_hai(v.han.month)}/${v.han.year}'),
              ),
          ],
        ],
      ),
    );
  }
}
