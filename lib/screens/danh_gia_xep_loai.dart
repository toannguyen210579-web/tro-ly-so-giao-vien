import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/danh_gia.dart';
import '../data/lich.dart';
import '../main.dart';
import '../services/chia_se.dart';
import '../services/tep_pdf.dart';
import '../services/tep_word.dart' show taoDocxPhieuXepLoai;
import '../services/tro_ly_api.dart';
import 'cau_giup_viec.dart';
import 'tai_khoan.dart' show HoSo;

/// Tiện ích "Đánh giá, xếp loại": theo dõi điểm tháng (hoặc quý) theo Nghị định 233/2026/NĐ-CP,
/// tổng hợp năm, làm Phiếu xếp loại chất lượng viên chức đúng mẫu Phụ lục II (Word, PDF).
class DanhGiaXepLoai extends StatefulWidget {
  const DanhGiaXepLoai({super.key});

  @override
  State<DanhGiaXepLoai> createState() => _DanhGiaXepLoaiState();
}

class _DanhGiaXepLoaiState extends State<DanhGiaXepLoai> {
  QuyCheDanhGia _qc = QuyCheDanhGia();
  Map<String, KyDanhGia> _ky = {};
  PhieuNam _phieu = PhieuNam();
  int _nam = DateTime.now().year;
  bool _dangTai = true;
  bool _dangAI = false;
  bool _dangLuu = false;
  String _cauAI = '';
  String _traLoiAI = '';

  final _coQuan = TextEditingController();
  final _donVi = TextEditingController();
  final _hoTen = TextEditingController();
  final _chucDanh = TextEditingController();
  final _uuDiem = TextEditingController();
  final _hanChe = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tai();
  }

  @override
  void dispose() {
    for (final c in [_coQuan, _donVi, _hoTen, _chucDanh, _uuDiem, _hanChe]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _tai() async {
    final qc = await KhoDanhGia.docQuyChe();
    final ky = await KhoDanhGia.docKy();
    final nam = namDanhGia(qc, DateTime.now());
    if (!mounted) return;
    setState(() {
      _qc = qc;
      _ky = ky;
      _nam = nam;
    });
    await _taiPhieu();
    if (mounted) setState(() => _dangTai = false);
  }

  /// Phiếu của năm đang xem; chưa có thì điền sẵn họ tên, trường từ Tài khoản.
  Future<void> _taiPhieu() async {
    final daCo = await KhoDanhGia.docPhieu(_nam);
    final PhieuNam ph;
    if (daCo != null) {
      ph = daCo;
    } else {
      final hs = await HoSo.doc();
      ph = PhieuNam(hoTen: hs[0], donVi: hs[1]);
    }
    if (!mounted) return;
    setState(() {
      _phieu = ph;
      _coQuan.text = ph.coQuanTren;
      _donVi.text = ph.donVi;
      _hoTen.text = ph.hoTen;
      _chucDanh.text = ph.chucDanh;
      _uuDiem.text = ph.uuDiem;
      _hanChe.text = ph.hanChe;
    });
  }

  Future<void> _ghiPhieu() async {
    _phieu
      ..coQuanTren = _coQuan.text.trim()
      ..donVi = _donVi.text.trim()
      ..hoTen = _hoTen.text.trim()
      ..chucDanh = _chucDanh.text.trim()
      ..uuDiem = _uuDiem.text.trim()
      ..hanChe = _hanChe.text.trim();
    await KhoDanhGia.ghiPhieu(_nam, _phieu);
  }

  Future<void> _doiNam(int buoc) async {
    await _ghiPhieu();
    setState(() => _nam += buoc);
    await _taiPhieu();
  }

  void _bao(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  List<MocKy> get _moc => cacKy(_qc, _nam);
  TongHopNam get _th => tongHop(_qc, _moc, _ky);

  // ---------- Thẻ "Các kỳ" ----------

  Widget _chonNam() => Row(
        children: [
          IconButton(tooltip: 'Năm trước', onPressed: () => _doiNam(-1), icon: const Icon(Icons.chevron_left)),
          Expanded(
            child: Text(tenNam(_qc, _nam), textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: MauApp.chu)),
          ),
          IconButton(tooltip: 'Năm sau', onPressed: () => _doiNam(1), icon: const Icon(Icons.chevron_right)),
        ],
      );

  Widget _theTongQuan() {
    final th = _th;
    final mau = [const Color(0xFF0C9467), MauApp.xanhTroi, const Color(0xFFE08A00), const Color(0xFFC62828)];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF2B7BE4), Color(0xFF1FB5A8)]),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x332C6EE8), blurRadius: 12, offset: Offset(0, 5))],
      ),
      child: th.soKyDaCham == 0
          ? const Text('Chưa chấm kỳ nào. Bấm vào một kỳ bên dưới để tự chấm điểm.',
              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700, height: 1.4))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Điểm bình quân ${th.soKyDaCham}/${th.soKy} kỳ đã chấm',
                    style: const TextStyle(color: Colors.white70, fontSize: 13.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(soDiem(th.tongHienThi), key: const Key('dg_binh_quan'), style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900, height: 1)),
                    const Text(' / 100', style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                  child: Text('Dự kiến: ${mucXepLoai[th.muc]}', style: TextStyle(color: mau[th.muc], fontWeight: FontWeight.w900, fontSize: 13.5)),
                ),
                const SizedBox(height: 10),
                Text('Tiêu chí chung ${soDiem(th.chungHienThi)}/30 · Kết quả nhiệm vụ ${soDiem(th.nhiemVuHienThi)}/70',
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                if (th.canDatXuatSac != null) ...[
                  const SizedBox(height: 6),
                  Text('Các kỳ còn lại cần bình quân ${soDiem(th.canDatXuatSac!)} điểm để đạt Hoàn thành xuất sắc.',
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
                if (th.binhQuan < 70 && th.canDatTot != null) ...[
                  const SizedBox(height: 4),
                  Text('Cần bình quân ${soDiem(th.canDatTot!)} điểm để đạt Hoàn thành tốt.',
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ],
            ),
    );
  }

  Widget _dongKy(MocKy m) {
    final kc = _ky[m.ma];
    final k = (kc != null && kc.daCham) ? kc : null;
        final dongPhu = k == null
        ? 'Chưa chấm'
        : [
            'Tự chấm ${soDiem(k.diemTuCham(_qc))}',
            if (k.diemTruong != null) 'Trường xác nhận ${soDiem(k.diemTruong!)}',
            if (k.viec.isNotEmpty) '${k.viec.length} việc',
          ].join(' · ');
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        key: Key('dg_ky_${m.ma}'),
        onTap: () => _moKy(m),
        title: Text(m.ten, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(dongPhu),
        trailing: k != null
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: k.diemTruong != null ? const Color(0xFFE3F6EC) : const Color(0xFFE6EEFB),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(soDiem(k.diem(_qc)), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: MauApp.chu)),
              )
            : const Icon(Icons.edit_note, color: MauApp.xanhTroi),
      ),
    );
  }

  Future<void> _moKy(MocKy m) async {
    final goc = _ky[m.ma];
    final banSao = goc == null ? KyDanhGia(ma: m.ma) : KyDanhGia.fromJson(goc.toJson());
    final kq = await Navigator.of(context).push<KyDanhGia>(
      MaterialPageRoute(builder: (_) => ManChamKy(moc: m, ky: banSao, quyChe: _qc)),
    );
    if (kq == null || !mounted) return;
    setState(() => _ky[m.ma] = kq);
    await KhoDanhGia.ghiKy(_ky);
  }

  Widget _theCacKy() => ListView(
        key: const Key('dg_ds_ky'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const CauGiupViec('danh_gia'),
          _chonNam(),
          const SizedBox(height: 6),
          _theTongQuan(),
          const SizedBox(height: 14),
          Text(_qc.theoQuy ? 'Các quý' : 'Các tháng', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 6),
          for (final m in _moc) _dongKy(m),
          const SizedBox(height: 4),
          const Text(
            'Điểm năm là bình quân điểm các kỳ đã chấm; kỳ nào có điểm trường xác nhận thì lấy điểm đó. '
            'Mức xếp loại chính thức do Hiệu trưởng (hoặc cấp có thẩm quyền) quyết định.',
            style: TextStyle(color: MauApp.chuPhu, fontSize: 12.5, height: 1.4),
          ),
        ],
      );

  // ---------- Thẻ "Phiếu năm" ----------

  Future<void> _nhoAI() async {
    final th = _th;
    if (th.soKyDaCham == 0) {
      _bao('Thầy cô chấm ít nhất một kỳ trước để AI có việc làm căn cứ.');
      return;
    }
    setState(() => _dangAI = true);
    final cau = cauHoiUuHanChe(_qc, _moc, _ky, _chucDanh.text.trim());
    final kq = await TroLyApi.hoi(cau, loai: 'danh_gia', riengTu: true);
    if (!mounted) return;
    setState(() => _dangAI = false);
    final t = kq.traLoi;
    if (t == null) {
      _bao(kq.loi ?? 'Chưa viết được, thầy cô thử lại.');
      return;
    }
    final (ud, hc) = tachUuHanChe(t);
    setState(() {
      _cauAI = cau;
      _traLoiAI = t;
      _uuDiem.text = ud;
      _hanChe.text = hc;
    });
    await _ghiPhieu();
  }

  Future<void> _baoCaoAI() async {
    const lyDos = ['Viết sai so với việc đã chấm', 'Nội dung không phù hợp', 'Khác'];
    final lyDo = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Báo cáo nội dung AI viết', style: TextStyle(fontWeight: FontWeight.w800))),
            for (final l in lyDos) ListTile(title: Text(l), onTap: () => Navigator.pop(c, l)),
          ],
        ),
      ),
    );
    if (lyDo == null) return;
    final ok = await TroLyApi.baoCao(cauHoi: _cauAI, traLoi: _traLoiAI, lyDo: lyDo, loai: 'danh_gia');
    _bao(ok ? 'Đã gửi báo cáo. Cảm ơn thầy cô.' : 'Chưa gửi được, thầy cô thử lại sau.');
  }

  Future<void> _luuPhieu() async {
    await _ghiPhieu();
    final th = _th;
    if (th.soKyDaCham == 0) {
      _bao('Chưa có kỳ nào được chấm. Thầy cô chấm các kỳ ở thẻ "Các kỳ" trước.');
      return;
    }
    setState(() => _dangLuu = true);
    try {
      final muc = mucTuXepLoai(th.binhQuan, _phieu.dieuKien);
      final noiDung = NoiDungPhieu(
        coQuanTren: _phieu.coQuanTren,
        donVi: _phieu.donVi,
        nam: tenNam(_qc, _nam),
        hoTen: _phieu.hoTen,
        chucDanh: _phieu.chucDanh,
        diemChung: '${soDiem(th.chungHienThi)} điểm',
        diemNhiemVu: '${soDiem(th.nhiemVuHienThi)} điểm',
        tongDiem: '${soDiem(th.tongHienThi)} điểm (bình quân ${th.soKyDaCham} ${_qc.theoQuy ? 'quý' : 'tháng'})',
        uuDiem: _phieu.uuDiem,
        hanChe: _phieu.hanChe,
        mucTu: muc,
      );
      final thuMuc = await thuMucApp('xuat');
      final ten = 'Phieu_xep_loai_${tenTep(tenNam(_qc, _nam))}_${dauThoiGian(DateTime.now())}';
      final word = File('${thuMuc.path}/$ten.docx');
      await word.writeAsBytes(noiDung.word(), flush: true);
      final pdf = File('${thuMuc.path}/$ten.pdf');
      await pdf.writeAsBytes(await noiDung.pdf(), flush: true);
      if (!mounted) return;
      setState(() => _dangLuu = false);
      await baoDaLuu(context, [word, pdf], tieuDe: 'Đã lưu phiếu xếp loại');
    } catch (_) {
      if (mounted) setState(() => _dangLuu = false);
      _bao('Chưa lưu được phiếu, thầy cô thử lại.');
    }
  }

  Widget _o(TextEditingController c, String nhan, {String? goiY, int dong = 1, Key? key}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          key: key,
          controller: c,
          minLines: dong,
          maxLines: dong == 1 ? 1 : 10,
          onChanged: (_) => _ghiPhieu(),
          decoration: InputDecoration(labelText: nhan, hintText: goiY, border: const OutlineInputBorder(), alignLabelWithHint: dong > 1),
        ),
      );

  Widget _thePhieu() {
    final th = _th;
    final muc = mucTuXepLoai(th.binhQuan, _phieu.dieuKien);
    final dk = _phieu.dieuKien;
    return ListView(
      key: const Key('dg_ds_phieu'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Text('Phiếu xếp loại chất lượng viên chức · ${tenNam(_qc, _nam)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        const SizedBox(height: 4),
        const Text('Đúng mẫu Phụ lục II Nghị định số 233/2026/NĐ-CP. Mục III, IV để trống cho nhà trường ghi.',
            style: TextStyle(color: MauApp.chuPhu, fontSize: 12.5)),
        const SizedBox(height: 12),
        _o(_coQuan, 'Cơ quan cấp trên', goiY: 'UBND phường ... (trường MN, TH, THCS) hoặc Sở GD&ĐT ... (THPT)'),
        _o(_donVi, 'Đơn vị (tên trường)'),
        _o(_hoTen, 'Họ và tên'),
        _o(_chucDanh, 'Chức vụ, chức danh', goiY: 'Giáo viên, Tổ trưởng chuyên môn...'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('I. Tổng hợp kết quả', style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text('1. Tiêu chí chung: ${soDiem(th.chungHienThi)}/30 điểm'),
                Text('2. Kết quả thực hiện nhiệm vụ: ${soDiem(th.nhiemVuHienThi)}/70 điểm'),
                Text('3. Tổng điểm trong năm: ${soDiem(th.tongHienThi)} điểm (${th.soKyDaCham}/${th.soKy} kỳ đã chấm)',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Expanded(child: Text('4, 5. Ưu điểm, hạn chế', style: TextStyle(fontWeight: FontWeight.w900))),
            FilledButton.tonalIcon(
              key: const Key('dg_nho_ai'),
              onPressed: _dangAI ? null : _nhoAI,
              icon: _dangAI ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome, size: 18),
              label: Text(_dangAI ? 'AI đang viết...' : 'Nhờ AI viết nháp'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _o(_uuDiem, 'Ưu điểm', dong: 4, key: const Key('dg_uu_diem')),
        _o(_hanChe, 'Hạn chế', dong: 3, key: const Key('dg_han_che')),
        if (_traLoiAI.isNotEmpty)
          Row(
            children: [
              const Expanded(child: Text('AI có thể nhầm, thầy cô đọc lại và sửa cho đúng.', style: TextStyle(color: MauApp.chuPhu, fontSize: 12.5))),
              TextButton.icon(onPressed: _baoCaoAI, icon: const Icon(Icons.flag_outlined, size: 18), label: const Text('Báo cáo')),
            ],
          ),
        const SizedBox(height: 8),
        const Text('Trường hợp riêng (Điều 12, Điều 14)', style: TextStyle(fontWeight: FontWeight.w900)),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: dk.chuaDu6Thang,
          onChanged: (v) => setState(() {
            dk.chuaDu6Thang = v ?? false;
            _ghiPhieu();
          }),
          title: const Text('Làm việc trong năm chưa đủ 06 tháng'),
          subtitle: const Text('Không xếp loại (trừ nghỉ ốm, thai sản, nghỉ không lương mà vẫn đủ 06 tháng làm việc).'),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: dk.biKyLuat,
          onChanged: (v) => setState(() {
            dk.biKyLuat = v ?? false;
            _ghiPhieu();
          }),
          title: const Text('Bị kỷ luật từ khiển trách trở lên về việc thực hiện nhiệm vụ trong năm'),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: dk.suyThoai,
          onChanged: (v) => setState(() {
            dk.suyThoai = v ?? false;
            _ghiPhieu();
          }),
          title: const Text('Bị cấp có thẩm quyền kết luận có biểu hiện suy thoái'),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFE6EEFB), borderRadius: BorderRadius.circular(12)),
          child: Text(
            muc == null ? 'II. Tự xếp loại: không xếp loại (chưa đủ 06 tháng làm việc).' : 'II. Tự xếp loại: ${mucXepLoai[muc]}',
            key: const Key('dg_tu_xep_loai'),
            style: const TextStyle(fontWeight: FontWeight.w900, color: MauApp.xanhDam),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Lưu ý: số người Hoàn thành xuất sắc không quá 20% số người Hoàn thành tốt của trường (25% nếu trường được công nhận Hoàn thành xuất sắc), '
          'nên đủ 90 điểm vẫn có thể được xếp Hoàn thành tốt.',
          style: TextStyle(color: MauApp.chuPhu, fontSize: 12.5, height: 1.4),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          key: const Key('dg_luu_phieu'),
          onPressed: _dangLuu ? null : _luuPhieu,
          icon: _dangLuu ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_alt),
          label: const Text('Lưu phiếu (Word và PDF)'),
        ),
      ],
    );
  }

  // ---------- Thẻ "Quy chế" ----------

  Widget _theQuyChe() => ManQuyChe(
        quyChe: _qc,
        onLuu: (q) async {
          await KhoDanhGia.ghiQuyChe(q);
          if (!mounted) return;
          final namMoi = namDanhGia(q, DateTime.now());
          setState(() {
            _qc = q;
            _nam = namMoi;
          });
          await _taiPhieu();
          _bao('Đã lưu quy chế chấm điểm.');
        },
      );

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Đánh giá, xếp loại'),
          bottom: const TabBar(tabs: [Tab(text: 'Các kỳ'), Tab(text: 'Phiếu năm'), Tab(text: 'Quy chế')]),
        ),
        body: _dangTai
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(children: [_theCacKy(), _thePhieu(), _theQuyChe()]),
      ),
    );
  }
}

/// Tách câu trả lời AI dạng "ƯU ĐIỂM: ... HẠN CHẾ: ..." thành hai phần. Không thấy nhãn thì để cả vào Ưu điểm.
(String, String) tachUuHanChe(String t) {
  final s = t.replaceAll('*', '').replaceAll('#', '').trim();
  final m = RegExp(r'h[aạ]n\s*ch[eế]\s*:?', caseSensitive: false).firstMatch(s);
  String bo(String x) => x.replaceFirst(RegExp(r'^\s*[uư]u\s*đi[eể]m\s*:?', caseSensitive: false), '').trim();
  if (m == null) return (bo(s), '');
  return (bo(s.substring(0, m.start)), s.substring(m.end).trim());
}

/// Nội dung phiếu để xuất tệp Word, PDF.
class NoiDungPhieu {
  final String coQuanTren, donVi, nam, hoTen, chucDanh, diemChung, diemNhiemVu, tongDiem, uuDiem, hanChe;
  final int? mucTu;
  const NoiDungPhieu({
    required this.coQuanTren,
    required this.donVi,
    required this.nam,
    required this.hoTen,
    required this.chucDanh,
    required this.diemChung,
    required this.diemNhiemVu,
    required this.tongDiem,
    required this.uuDiem,
    required this.hanChe,
    required this.mucTu,
  });

  List<int> word() => taoDocxPhieuXepLoai(
        coQuanTren: coQuanTren,
        donVi: donVi,
        nam: nam,
        hoTen: hoTen,
        chucDanh: chucDanh,
        donViCongTac: donVi,
        diemChung: diemChung,
        diemNhiemVu: diemNhiemVu,
        tongDiem: tongDiem,
        uuDiem: uuDiem,
        hanChe: hanChe,
        mucXepLoai: mucXepLoai,
        mucTu: mucTu,
      );

  Future<List<int>> pdf() async {
    final doc = pw.Document(theme: await PhongPdf.theme());
    const co = 12.0;
    pw.Widget t(String s, {bool dam = false, bool nghieng = false, double size = co, pw.TextAlign canh = pw.TextAlign.left}) => pw.Text(
          s,
          textAlign: canh,
          style: pw.TextStyle(fontSize: size, fontWeight: dam ? pw.FontWeight.bold : null, fontStyle: nghieng ? pw.FontStyle.italic : null, lineSpacing: 2),
        );
    pw.Widget nhan(String n, String v) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.RichText(
            text: pw.TextSpan(style: const pw.TextStyle(fontSize: co, lineSpacing: 2), children: [
              pw.TextSpan(text: n, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.TextSpan(text: v),
            ]),
          ),
        );
    pw.Widget o(bool chon, String s) => pw.Padding(
          padding: const pw.EdgeInsets.only(left: 18, bottom: 3),
          child: pw.Row(children: [
            pw.Container(
              width: 10,
              height: 10,
              alignment: pw.Alignment.center,
              decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.8)),
              child: chon ? pw.Text('x', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)) : null,
            ),
            pw.SizedBox(width: 6),
            t(s),
          ]),
        );
    List<pw.Widget> doan(String s, int soDong) {
      final ds = s.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      if (ds.isEmpty) return [for (var i = 0; i < soDong; i++) t('.' * 95, size: 10)];
      return [for (final d in ds) pw.Padding(padding: const pw.EdgeInsets.only(left: 18, bottom: 3), child: t(d))];
    }

    pw.Widget ky(String chuc, String ten) => pw.Column(children: [
          t('......, ngày .... tháng .... năm ......', nghieng: true, size: 11),
          t(chuc, dam: true),
          t('(Ký tên, ghi rõ họ tên)', nghieng: true, size: 10.5),
          pw.SizedBox(height: 56),
          t(ten, dam: true),
        ]);
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(85, 57, 43, 57),
      build: (c) => [
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(
            flex: 5,
            child: pw.Column(children: [
              if (coQuanTren.trim().isNotEmpty) t(coQuanTren.trim().toUpperCase(), size: 11.5, canh: pw.TextAlign.center),
              t((donVi.trim().isEmpty ? 'TÊN CƠ QUAN, TỔ CHỨC, ĐƠN VỊ' : donVi.trim()).toUpperCase(), dam: true, size: 11.5, canh: pw.TextAlign.center),
              pw.Container(width: 60, height: 0.8, color: PdfColors.black, margin: const pw.EdgeInsets.only(top: 2)),
            ]),
          ),
          pw.Expanded(
            flex: 7,
            child: pw.Column(children: [
              t('CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM', dam: true, size: 11.5, canh: pw.TextAlign.center),
              t('Độc lập - Tự do - Hạnh phúc', dam: true, canh: pw.TextAlign.center),
              pw.Container(width: 130, height: 0.8, color: PdfColors.black, margin: const pw.EdgeInsets.only(top: 2)),
            ]),
          ),
        ]),
        pw.SizedBox(height: 18),
        pw.Center(child: t('PHIẾU XẾP LOẠI CHẤT LƯỢNG VIÊN CHỨC', dam: true, size: 13.5)),
        pw.Center(child: t(nam, dam: true)),
        pw.SizedBox(height: 12),
        nhan('Họ và tên: ', hoTen.isEmpty ? '.' * 60 : hoTen),
        nhan('Chức vụ, chức danh: ', chucDanh.isEmpty ? '.' * 50 : chucDanh),
        nhan('Đơn vị công tác: ', donVi.isEmpty ? '.' * 54 : donVi),
        pw.SizedBox(height: 6),
        t('I. TỔNG HỢP KẾT QUẢ THEO DÕI, ĐÁNH GIÁ', dam: true),
        pw.SizedBox(height: 3),
        nhan('1. Kết quả theo dõi, đánh giá theo tiêu chí chung (tối đa 30 điểm): ', diemChung),
        nhan('2. Kết quả theo dõi, đánh giá theo tiêu chí kết quả thực hiện nhiệm vụ (tối đa 70 điểm): ', diemNhiemVu),
        nhan('3. Tổng điểm theo dõi, đánh giá trong năm: ', tongDiem),
        t('4. Ưu điểm:', dam: true),
        ...doan(uuDiem, 4),
        t('5. Hạn chế:', dam: true),
        ...doan(hanChe, 4),
        pw.SizedBox(height: 6),
        t('II. VIÊN CHỨC TỰ ĐÁNH GIÁ, XẾP LOẠI CHẤT LƯỢNG', dam: true),
        for (var i = 0; i < mucXepLoai.length; i++) o(mucTu == i, mucXepLoai[i]),
        pw.SizedBox(height: 6),
        t('III. KẾT QUẢ XẾP LOẠI CHẤT LƯỢNG VIÊN CHỨC CỦA CẤP CÓ THẨM QUYỀN', dam: true),
        for (final m in mucXepLoai) o(false, m),
        pw.SizedBox(height: 6),
        t('IV. Ý KIẾN NHẬN XÉT CỦA CẤP CÓ THẨM QUYỀN VÀ ĐỀ XUẤT PHƯƠNG ÁN XỬ LÝ(1)', dam: true),
        for (var i = 0; i < 4; i++) t('.' * 95, size: 10),
        pw.SizedBox(height: 16),
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(child: ky('VIÊN CHỨC TỰ XẾP LOẠI', hoTen)),
          pw.Expanded(child: ky('CẤP CÓ THẨM QUYỀN XẾP LOẠI', '')),
        ]),
        pw.SizedBox(height: 12),
        t('(1) Việc đề xuất phương án xử lý căn cứ quy định tại Điều 16 Nghị định số 233/2026/NĐ-CP.', nghieng: true, size: 10),
      ],
    ));
    return doc.save();
  }
}

/// Màn chấm điểm một kỳ.
class ManChamKy extends StatefulWidget {
  final MocKy moc;
  final KyDanhGia ky;
  final QuyCheDanhGia quyChe;
  const ManChamKy({super.key, required this.moc, required this.ky, required this.quyChe});

  @override
  State<ManChamKy> createState() => _ManChamKyState();
}

class _ManChamKyState extends State<ManChamKy> {
  late KyDanhGia _k;
  late List<double> _chung;
  final List<TextEditingController> _tenViec = [];
  late final TextEditingController _diemTruong;
  late final TextEditingController _ghiChu;

  QuyCheDanhGia get _q => widget.quyChe;

  @override
  void initState() {
    super.initState();
    _k = widget.ky;
    // Chưa chấm: để sẵn điểm tối đa từng nhóm (thầy cô trừ chỗ chưa đạt), đỡ phải bấm nhiều
    _chung = List<double>.from(_k.chung ?? _q.chung);
    for (final v in _k.viec) {
      _tenViec.add(TextEditingController(text: v.ten));
    }
    _diemTruong = TextEditingController(text: _k.diemTruong == null ? '' : soDiem(_k.diemTruong!));
    _ghiChu = TextEditingController(text: _k.ghiChu);
  }

  @override
  void dispose() {
    for (final c in [..._tenViec, _diemTruong, _ghiChu]) {
      c.dispose();
    }
    super.dispose();
  }

  void _themViec([String ten = '']) {
    setState(() {
      _k.viec.add(ViecGiao(ten: ten));
      _tenViec.add(TextEditingController(text: ten));
    });
  }

  void _xoaViec(int i) {
    setState(() {
      _k.viec.removeAt(i);
      _tenViec.removeAt(i).dispose();
    });
  }

  Future<void> _layTuLich() async {
    final ds = (await docViec()).where((v) => !v.han.isBefore(widget.moc.tu) && v.han.isBefore(widget.moc.den)).toList();
    if (!mounted) return;
    final daCo = _k.viec.map((v) => v.ten.trim().toLowerCase()).toSet();
    final moi = ds.where((v) => !daCo.contains(v.ten.trim().toLowerCase())).toList();
    if (moi.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ds.isEmpty ? 'Lịch nhắc hạn không có việc nào trong ${widget.moc.ten.toLowerCase()}.' : 'Các việc trong Lịch nhắc hạn đã có ở đây.'),
      ));
      return;
    }
    for (final v in moi) {
      _themViec(v.ten);
      // Việc chưa đánh dấu xong trong lịch mà đã quá hạn: để sẵn "Trễ hạn"
      if (!v.xong && v.han.isBefore(DateTime.now())) _k.viec.last.tienDo = 1;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã lấy ${moi.length} việc từ Lịch nhắc hạn.')));
  }

  KyDanhGia _ketQua() {
    for (var i = 0; i < _k.viec.length; i++) {
      _k.viec[i].ten = _tenViec[i].text.trim();
    }
    _k.viec.removeWhere((v) => v.ten.isEmpty);
    _k.chung = List<double>.from(_chung);
    final dt = double.tryParse(_diemTruong.text.trim().replaceAll(',', '.'));
    _k.diemTruong = (dt != null && dt >= 0 && dt <= 100) ? dt : null;
    _k.ghiChu = _ghiChu.text.trim();
    return _k;
  }

  Widget _chonMuc(String nhan, List<(String, double)> muc, int chon, void Function(int) doi) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 78, child: Padding(padding: const EdgeInsets.only(top: 8), child: Text(nhan, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)))),
            Expanded(
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (var i = 0; i < muc.length; i++)
                    ChoiceChip(
                      label: Text(muc[i].$1),
                      selected: chon == i,
                      onSelected: (_) => setState(() => doi(i)),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final nv = _k.diemNhiemVu(_q);
    final tongChung = _chung.fold(0.0, (a, b) => a + b);
    final tong = tongChung + nv.fold(0.0, (a, b) => a + b);
    return Scaffold(
      appBar: AppBar(title: Text(widget.moc.ten)),
      body: ListView(
        key: const Key('dg_ds_cham'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFFE6EEFB), borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Điểm tự chấm', style: TextStyle(color: MauApp.chuPhu, fontWeight: FontWeight.w700)),
                      Text('Chung ${soDiem(tongChung)} + nhiệm vụ ${soDiem(nv.fold(0.0, (a, b) => a + b))}', style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
                Text(soDiem(tong), key: const Key('dg_tong_ky'), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: MauApp.xanhDam)),
                const SizedBox(width: 8),
                Text(mucXepLoai[mucTheoDiem(tong)].replaceFirst(' nhiệm vụ', ''), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('A. Tiêu chí chung (tối đa ${soDiem(_q.tongChung)} điểm)', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5)),
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Expanded(child: Text('${i + 1}. ${tenNhomChung[i]}', style: const TextStyle(fontSize: 13.5))),
                  IconButton(
                    tooltip: 'Trừ nửa điểm',
                    onPressed: _chung[i] <= 0 ? null : () => setState(() => _chung[i] = (_chung[i] - 0.5).clamp(0.0, _q.chung[i]).toDouble()),
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  SizedBox(
                    width: 64,
                    child: Text('${soDiem(_chung[i])}/${soDiem(_q.chung[i])}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900)),
                  ),
                  IconButton(
                    tooltip: 'Cộng nửa điểm',
                    onPressed: _chung[i] >= _q.chung[i] ? null : () => setState(() => _chung[i] = (_chung[i] + 0.5).clamp(0.0, _q.chung[i]).toDouble()),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 18),
          Text('B. Kết quả thực hiện nhiệm vụ (tối đa ${soDiem(_q.tongNhiemVu)} điểm)', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5)),
          const SizedBox(height: 4),
          Text(
            'Mỗi việc được giao chọn khối lượng, chất lượng, tiến độ; app tính số lượng ${soDiem(nv[0])}/${soDiem(_q.nhiemVu[0])}, '
            'chất lượng ${soDiem(nv[1])}/${soDiem(_q.nhiemVu[1])}, tiến độ ${soDiem(nv[2])}/${soDiem(_q.nhiemVu[2])}.',
            style: const TextStyle(color: MauApp.chuPhu, fontSize: 12.5, height: 1.4),
          ),
          for (var i = 0; i < _k.viec.length; i++)
            Card(
              margin: const EdgeInsets.only(top: 10),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 4, 10),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: Key('dg_ten_viec_$i'),
                            controller: _tenViec[i],
                            decoration: InputDecoration(hintText: 'Việc được giao ${i + 1}', border: InputBorder.none),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        IconButton(tooltip: 'Bỏ việc này', onPressed: () => _xoaViec(i), icon: const Icon(Icons.close)),
                      ],
                    ),
                    _chonMuc('Khối lượng', mucKhoiLuong, _k.viec[i].khoiLuong, (x) => _k.viec[i].khoiLuong = x),
                    _chonMuc('Chất lượng', mucChatLuong, _k.viec[i].chatLuong, (x) => _k.viec[i].chatLuong = x),
                    _chonMuc('Tiến độ', mucTienDo, _k.viec[i].tienDo, (x) => _k.viec[i].tienDo = x),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(key: const Key('dg_them_viec'), onPressed: () => _themViec(), icon: const Icon(Icons.add), label: const Text('Thêm việc')),
              OutlinedButton.icon(onPressed: _layTuLich, icon: const Icon(Icons.event_note_outlined), label: const Text('Lấy việc từ Lịch nhắc hạn')),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            key: const Key('dg_diem_truong'),
            controller: _diemTruong,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            decoration: const InputDecoration(
              labelText: 'Điểm trường xác nhận (nếu có)',
              helperText: 'Có điểm này thì app dùng nó để tính điểm năm thay cho điểm tự chấm.',
              helperMaxLines: 3,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ghiChu,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Ghi chú',
              hintText: 'Việc nổi bật, khen thưởng, việc chưa làm được',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            key: const Key('dg_luu_ky'),
            onPressed: () => Navigator.of(context).pop(_ketQua()),
            icon: const Icon(Icons.check),
            label: const Text('Lưu kỳ này'),
          ),
        ],
      ),
    );
  }
}

/// Thẻ Quy chế: chấm theo tháng hay quý, năm học hay năm công tác, điểm tối đa từng phần.
class ManQuyChe extends StatefulWidget {
  final QuyCheDanhGia quyChe;
  final Future<void> Function(QuyCheDanhGia) onLuu;
  const ManQuyChe({super.key, required this.quyChe, required this.onLuu});

  @override
  State<ManQuyChe> createState() => _ManQuyCheState();
}

class _ManQuyCheState extends State<ManQuyChe> {
  late bool _theoQuy;
  late bool _namHoc;
  late List<TextEditingController> _o;

  @override
  void initState() {
    super.initState();
    _dat(widget.quyChe);
  }

  void _dat(QuyCheDanhGia q) {
    _theoQuy = q.theoQuy;
    _namHoc = q.namHoc;
    _o = [for (final d in [...q.chung, ...q.nhiemVu]) TextEditingController(text: soDiem(d))];
  }

  @override
  void dispose() {
    for (final c in _o) {
      c.dispose();
    }
    super.dispose();
  }

  QuyCheDanhGia get _q {
    double so(int i) => double.tryParse(_o[i].text.trim().replaceAll(',', '.')) ?? 0;
    return QuyCheDanhGia(theoQuy: _theoQuy, namHoc: _namHoc, chung: [so(0), so(1), so(2)], nhiemVu: [so(3), so(4), so(5)]);
  }

  Widget _oDiem(int i, String nhan) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Expanded(child: Text(nhan, style: const TextStyle(fontSize: 13.5))),
            SizedBox(
              width: 80,
              child: TextField(
                controller: _o[i],
                textAlign: TextAlign.center,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final loi = _q.loiDiem;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        const Text(
          'Nghị định số 233/2026/NĐ-CP chỉ quy định khung: tiêu chí chung 30 điểm, kết quả nhiệm vụ 70 điểm. '
          'Điểm từng phần do quy chế đánh giá của trường quy định. Thầy cô sửa cho khớp quy chế trường mình.',
          style: TextStyle(color: MauApp.chuPhu, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 14),
        const Text('Theo dõi, chấm điểm', style: TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        SegmentedButton<bool>(
          segments: const [ButtonSegment(value: false, label: Text('Theo tháng')), ButtonSegment(value: true, label: Text('Theo quý'))],
          selected: {_theoQuy},
          onSelectionChanged: (s) => setState(() => _theoQuy = s.first),
        ),
        const SizedBox(height: 10),
        SegmentedButton<bool>(
          segments: const [ButtonSegment(value: true, label: Text('Năm học (9 đến 5)')), ButtonSegment(value: false, label: Text('Năm (1 đến 12)'))],
          selected: {_namHoc},
          onSelectionChanged: (s) => setState(() => _namHoc = s.first),
        ),
        const SizedBox(height: 16),
        const Text('Tiêu chí chung (cộng 30 điểm)', style: TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        for (var i = 0; i < 3; i++) _oDiem(i, '${i + 1}. ${tenNhomChung[i]}'),
        const SizedBox(height: 8),
        const Text('Kết quả thực hiện nhiệm vụ (cộng 70 điểm)', style: TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        for (var i = 0; i < 3; i++) _oDiem(3 + i, tenThanhPhanNv[i]),
        if (loi.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(loi, style: const TextStyle(color: Color(0xFFC62828), fontWeight: FontWeight.w700))),
        const SizedBox(height: 6),
        const Text(
          'Cách app tính kết quả nhiệm vụ: Chất lượng Tốt 100%, Đạt 80%, Chưa đạt 0%; Tiến độ Đúng hạn 100%, Trễ hạn 60%, Không làm 0%; '
          'Số lượng theo khối lượng hoàn thành. Đổi cách tính tháng, quý thì điểm các kỳ đã chấm theo cách cũ vẫn giữ, chuyển lại là thấy.',
          style: TextStyle(color: MauApp.chuPhu, fontSize: 12.5, height: 1.4),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() {
                  for (final c in _o) {
                    c.dispose();
                  }
                  _dat(QuyCheDanhGia(theoQuy: _theoQuy, namHoc: _namHoc));
                }),
                child: const Text('Dùng điểm mẫu'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                key: const Key('dg_luu_quy_che'),
                onPressed: loi.isNotEmpty ? null : () => widget.onLuu(_q),
                child: const Text('Lưu quy chế'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
