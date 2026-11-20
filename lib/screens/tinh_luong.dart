import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/tinh_luong.dart';
import '../main.dart';
import '../services/tep_pdf.dart';
import 'cau_giup_viec.dart';
import 'lich_nhac_han.dart';

const _mucUuDai = <(String, int?)>[
  ('Theo cấp dạy (mầm non, tiểu học 45%; THCS, THPT 40%)', null),
  ('THCS, THPT ở xã khu vực I, II vùng dân tộc thiểu số: 45%', 45),
  ('Vùng có điều kiện kinh tế - xã hội đặc biệt khó khăn: 70%', 70),
  ('Trường PTDTNT, phổ thông nội trú, THPT chuyên: 80%', 80),
];

const _khuVuc = [0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.7, 1.0];

class TinhLuong extends StatefulWidget {
  const TinhLuong({super.key});

  @override
  State<TinhLuong> createState() => _TinhLuongState();
}

class _TinhLuongState extends State<TinhLuong> {
  String _cap = 'THCS';
  String _hang = 'Hạng III';
  int _bac = 1;
  int _mucUD = 0;
  double _kv = 0;
  DateTime _vaoNghe = DateTime(2015, 9, 1);
  DateTime _xepBac = DateTime(2024, 9, 1);
  final _chucVu = TextEditingController(text: '0');
  final _baoLuu = TextEditingController(text: '0');
  final _vuotKhung = TextEditingController(text: '0');

  @override
  void initState() {
    super.initState();
    _tai();
  }

  Future<void> _tai() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _cap = p.getString('l_cap') ?? _cap;
      _hang = p.getString('l_hang') ?? _hang;
      _bac = p.getInt('l_bac') ?? _bac;
      _mucUD = p.getInt('l_ud') ?? _mucUD;
      _kv = p.getDouble('l_kv') ?? _kv;
      _vaoNghe = DateTime.tryParse(p.getString('l_vao') ?? '') ?? _vaoNghe;
      _xepBac = DateTime.tryParse(p.getString('l_xep') ?? '') ?? _xepBac;
      _chucVu.text = p.getString('l_cv') ?? '0';
      _baoLuu.text = p.getString('l_bl') ?? '0';
      _vuotKhung.text = p.getString('l_vk') ?? '0';
      final n = ngachCua(_cap, _hang);
      if (_bac > n.soBac) _bac = n.soBac;
    });
  }

  Future<void> _luu() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('l_cap', _cap);
    await p.setString('l_hang', _hang);
    await p.setInt('l_bac', _bac);
    await p.setInt('l_ud', _mucUD);
    await p.setDouble('l_kv', _kv);
    await p.setString('l_vao', _vaoNghe.toIso8601String());
    await p.setString('l_xep', _xepBac.toIso8601String());
    await p.setString('l_cv', _chucVu.text);
    await p.setString('l_bl', _baoLuu.text);
    await p.setString('l_vk', _vuotKhung.text);
  }

  @override
  void dispose() {
    _chucVu.dispose();
    _baoLuu.dispose();
    _vuotKhung.dispose();
    super.dispose();
  }

  double _so(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '.')) ?? 0;

  Future<void> _chonNgay(bool vaoNghe) async {
    final d = await showDatePicker(
      context: context,
      initialDate: vaoNghe ? _vaoNghe : _xepBac,
      firstDate: DateTime(1970),
      lastDate: DateTime(2100),
      helpText: vaoNghe ? 'Ngày bắt đầu dạy, có đóng BHXH' : 'Ngày hưởng bậc lương hiện tại',
    );
    if (d == null) return;
    setState(() {
      if (vaoNghe) {
        _vaoNghe = d;
      } else {
        _xepBac = d;
      }
    });
    _luu();
  }

  @override
  Widget build(BuildContext context) {
    final ngach = ngachCua(_cap, _hang);
    final heSo = ngach.heSo(_bac);
    final soNam = soNamTron(_vaoNghe, DateTime.now());
    final tn = phanTramThamNien(soNam);
    final ud = _mucUuDai[_mucUD].$2 ?? uuDaiMacDinh(_cap);
    final kq = tinhLuong(
      heSo: heSo,
      heSoBaoLuu: _so(_baoLuu),
      heSoChucVu: _so(_chucVu),
      heSoKhuVuc: _kv,
      phanTramVuotKhung: _so(_vuotKhung).round(),
      phanTramUuDai: ud,
      phanTramThamNienNghe: tn,
    );
    final bacCuoi = _bac >= ngach.soBac;
    final cauThamNien = soNam < 5
        ? 'Phụ cấp thâm niên 5% bắt đầu từ ${ngayVN(DateTime(_vaoNghe.year + 5, _vaoNghe.month, _vaoNghe.day))}.'
        : 'Phụ cấp thâm niên lên ${tn + 1}% từ ${ngayVN(DateTime(_vaoNghe.year + soNam + 1, _vaoNghe.month, _vaoNghe.day))}.';
    final nangBac = ngayNangBacKe(_xepBac);

    Widget dong(String a, int v, {bool dam = false, Color? mau}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Expanded(child: Text(a, style: TextStyle(fontWeight: dam ? FontWeight.w800 : FontWeight.w500))),
            Text('${dinhDangTien(v)} đ',
                style: TextStyle(fontWeight: dam ? FontWeight.w900 : FontWeight.w600, color: mau, fontSize: dam ? 18 : 15)),
          ]),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Tính lương')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          const CauGiupViec('luong'),
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                value: _cap,
                decoration: const InputDecoration(labelText: 'Cấp dạy', border: OutlineInputBorder()),
                items: [for (final c in capDay) DropdownMenuItem(value: c, child: Text(c))],
                onChanged: (v) => setState(() {
                  _cap = v ?? _cap;
                  _bac = _bac.clamp(1, ngachCua(_cap, _hang).soBac);
                  _luu();
                }),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                value: _hang,
                decoration: const InputDecoration(labelText: 'Hạng', border: OutlineInputBorder()),
                items: [for (final h in hangGV) DropdownMenuItem(value: h, child: Text(h))],
                onChanged: (v) => setState(() {
                  _hang = v ?? _hang;
                  _bac = _bac.clamp(1, ngachCua(_cap, _hang).soBac);
                  _luu();
                }),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            isExpanded: true,
            value: _bac,
            decoration: InputDecoration(labelText: 'Bậc lương (hệ số ${ngach.ma})', border: const OutlineInputBorder()),
            items: [
              for (var b = 1; b <= ngach.soBac; b++)
                DropdownMenuItem(value: b, child: Text('Bậc $b · hệ số ${ngach.heSo(b).toStringAsFixed(2).replaceAll('.', ',')}')),
            ],
            onChanged: (v) => setState(() {
              _bac = v ?? _bac;
              _luu();
            }),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: _mucUD,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Phụ cấp ưu đãi theo nghề', border: OutlineInputBorder()),
            items: [for (var i = 0; i < _mucUuDai.length; i++) DropdownMenuItem(value: i, child: Text(_mucUuDai[i].$1, overflow: TextOverflow.ellipsis))],
            onChanged: (v) => setState(() {
              _mucUD = v ?? 0;
              _luu();
            }),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: InkWell(
                onTap: () => _chonNgay(true),
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Bắt đầu dạy (có BHXH)', border: OutlineInputBorder()),
                  child: Text('${ngayVN(_vaoNghe)} · $soNam năm'),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: InkWell(
                onTap: () => _chonNgay(false),
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Hưởng bậc hiện tại từ', border: OutlineInputBorder()),
                  child: Text(ngayVN(_xepBac)),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Phụ cấp khác (nếu có)', style: TextStyle(fontWeight: FontWeight.w700)),
            children: [
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _chucVu,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) {
                      setState(() {});
                      _luu();
                    },
                    decoration: const InputDecoration(labelText: 'Hệ số phụ cấp chức vụ', hintText: 'Tổ trưởng 0,2'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _baoLuu,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) {
                      setState(() {});
                      _luu();
                    },
                    decoration: const InputDecoration(labelText: 'Hệ số chênh lệch bảo lưu'),
                  ),
                ),
              ]),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _vuotKhung,
                    keyboardType: TextInputType.number,
                    onChanged: (_) {
                      setState(() {});
                      _luu();
                    },
                    decoration: const InputDecoration(labelText: 'Thâm niên vượt khung (%)'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<double>(
                    isExpanded: true,
                    value: _khuVuc.contains(_kv) ? _kv : 0,
                    decoration: const InputDecoration(labelText: 'Hệ số phụ cấp khu vực'),
                    items: [for (final k in _khuVuc) DropdownMenuItem(value: k, child: Text(k == 0 ? 'Không' : k.toString().replaceAll('.', ',')))],
                    onChanged: (v) => setState(() {
                      _kv = v ?? 0;
                      _luu();
                    }),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Lương tháng · hệ số ${heSo.toStringAsFixed(2).replaceAll('.', ',')} × ${dinhDangTien(luongCoSo)} đ',
                    style: const TextStyle(color: MauApp.chuPhu, fontSize: 12.5)),
                const SizedBox(height: 6),
                dong('Lương theo hệ số', kq.luongHeSo),
                if (kq.phuCapChucVu > 0) dong('Phụ cấp chức vụ', kq.phuCapChucVu),
                if (kq.chenhLechBaoLuu > 0) dong('Chênh lệch bảo lưu', kq.chenhLechBaoLuu),
                if (kq.thamNienVuotKhung > 0) dong('Thâm niên vượt khung', kq.thamNienVuotKhung),
                dong('Phụ cấp ưu đãi $ud%', kq.uuDai),
                dong(tn > 0 ? 'Phụ cấp thâm niên $tn%' : 'Phụ cấp thâm niên (chưa đủ 5 năm)', kq.thamNien),
                if (kq.khuVuc > 0) dong('Phụ cấp khu vực', kq.khuVuc),
                const Divider(),
                dong('Tổng thu nhập', kq.tongThuNhap, dam: true),
                dong('Trừ BHXH, BHYT, BHTN (10,5%)', -kq.baoHiem, mau: const Color(0xFFA3241C)),
                const Divider(),
                dong('Thực nhận (chưa tính thuế TNCN)', kq.thucNhan, dam: true, mau: MauApp.xanhLa),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFFE3ECF8), borderRadius: BorderRadius.circular(14)),
            child: Text(
              bacCuoi
                  ? 'Thầy cô đang ở bậc cuối của hạng. Đủ 3 năm ở bậc cuối (từ ${ngayVN(nangBac)}) thì được xét thâm niên vượt khung 5%, sau đó mỗi năm thêm 1%.'
                  : 'Nâng bậc kế tiếp (bậc ${_bac + 1}, hệ số ${ngach.heSo(_bac + 1).toStringAsFixed(2).replaceAll('.', ',')}) dự kiến từ ${ngayVN(nangBac)}, '
                      'nếu đủ 3 năm hoàn thành nhiệm vụ, không bị kỷ luật. $cauThamNien',
              style: const TextStyle(height: 1.4),
            ),
          ),
          if (!bacCuoi && nangBac.isAfter(DateTime.now()))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => LichNhacHan(tenMoi: 'Nâng bậc lương lên bậc ${_bac + 1}', hanMoi: DateTime(nangBac.year, nangBac.month, nangBac.day, 8)),
                )),
                icon: const Icon(Icons.event_available_outlined),
                label: const Text('Nhắc ngày nâng bậc vào Lịch'),
              ),
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(
                text: 'Lương tháng (tính tham khảo theo app Trợ lý số GV, cập nhật $ngayCapNhatLuong)\n'
                    'Hệ số ${heSo.toStringAsFixed(2)}, ưu đãi $ud%, thâm niên $tn%\n'
                    'Tổng thu nhập: ${dinhDangTien(kq.tongThuNhap)} đ\nTrừ bảo hiểm: ${dinhDangTien(kq.baoHiem)} đ\n'
                    'Thực nhận: ${dinhDangTien(kq.thucNhan)} đ',
              ));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã chép kết quả.')));
            },
            icon: const Icon(Icons.copy),
            label: const Text('Chép kết quả'),
          ),
          const SizedBox(height: 16),
          Text('Căn cứ (cập nhật $ngayCapNhatLuong)', style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          for (final c in canCuLuong)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('• $c', style: const TextStyle(fontSize: 12.5, color: MauApp.chuPhu, height: 1.35)),
            ),
          const SizedBox(height: 8),
          const Text(
            'Kết quả để tham khảo. Số thực nhận tại trường còn tùy phụ cấp thu hút, trách nhiệm, các khoản trừ khác và quyết định xếp lương của thầy cô. '
            'Hệ số lương đặc thù của nhà giáo hiện mới là dự thảo nên chưa tính.',
            style: TextStyle(fontSize: 12, color: MauApp.chuPhu, height: 1.35),
          ),
        ],
      ),
    );
  }
}
