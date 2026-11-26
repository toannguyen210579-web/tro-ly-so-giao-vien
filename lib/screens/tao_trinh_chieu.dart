import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/trinh_chieu.dart';
import '../main.dart';
import '../services/anh_trang.dart' show anhGuiAi;
import '../services/chia_se.dart';
import '../services/chon_tep.dart';
import '../services/tep_pdf.dart' show thuMucApp, tenTep, dauThoiGian;
import '../services/tep_pptx.dart';
import '../services/tep_trinh_chieu_pdf.dart';
import '../services/tro_ly_api.dart';
import 'cau_giup_viec.dart';

/// Giáo án dài hơn mức này thì chỉ gửi phần đầu (máy chủ nhận tối đa 30.000 ký tự mỗi lần).
const _toiDaChu = 29000;

/// Giáo án ít chữ hơn mức này (và không có ảnh, tệp PDF) thì báo trước: AI chỉ dựng được khung bài.
const _itChu = 400;

/// Tạo bài trình chiếu (26/11/2026): chọn tệp giáo án (Word, PDF), chụp giáo án hoặc dán nội dung; AI dựng dàn trang
/// theo đúng các hoạt động của giáo án và khung kế hoạch bài dạy của cấp học; thầy cô xem, sửa từng trang rồi lưu
/// tệp PowerPoint (.pptx, có ghi chú giáo viên ở từng trang) và PDF.
class TaoTrinhChieu extends StatefulWidget {
  /// Bài có sẵn (dùng khi thử giao diện), không gọi AI.
  final BaiChieu? baiThu;
  const TaoTrinhChieu({super.key, this.baiThu});

  @override
  State<TaoTrinhChieu> createState() => _TaoTrinhChieuState();
}

class _TaoTrinhChieuState extends State<TaoTrinhChieu> {
  final _chu = TextEditingController();
  final _anh = <String>[]; // đường dẫn ảnh chụp giáo án
  TepTaiLen? _tep; // tệp giáo án Word (đã lấy chữ) hoặc PDF
  String _cap = 'THCS';
  int _soTrang = 12;
  String _mau = mauTrinhChieu.first.ma;
  bool _dangTao = false;
  int _giay = 0;
  Timer? _dem;
  BaiChieu? _bai;

  @override
  void initState() {
    super.initState();
    _bai = widget.baiThu;
    _nhoLanTruoc();
  }

  @override
  void dispose() {
    _dem?.cancel();
    _chu.dispose();
    super.dispose();
  }

  /// Cấp học, số trang, màu dùng lần trước: thầy cô không phải chọn lại.
  Future<void> _nhoLanTruoc() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      final cap = p.getString('tc_cap');
      if (cap != null && capHocTrinhChieu.contains(cap)) _cap = cap;
      final so = p.getInt('tc_so');
      if (so != null && soTrangTrinhChieu.contains(so)) _soTrang = so;
      final mau = p.getString('tc_mau');
      if (mau != null && mauTrinhChieu.any((m) => m.ma == mau)) _mau = mau;
    });
  }

  Future<void> _ghiNho() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('tc_cap', _cap);
    await p.setInt('tc_so', _soTrang);
    await p.setString('tc_mau', _mau);
  }

  MauTrinhChieu get _mauChon => mauTrinhChieu.firstWhere((m) => m.ma == _mau, orElse: () => mauTrinhChieu.first);

  void _bao(String s) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  Future<void> _chonTep() async {
    try {
      final t = await chonTep(['docx', 'doc', 'pdf', 'txt']);
      if (t == null || !mounted) return;
      setState(() => _tep = t);
    } on FormatException catch (e) {
      _bao(e.message);
    } catch (_) {
      _bao('Chưa mở được tệp, thầy cô thử lại.');
    }
  }

  Future<void> _themAnh(ImageSource nguon) async {
    if (_anh.length >= 4) {
      _bao('Mỗi lần gửi tối đa 4 ảnh giáo án.');
      return;
    }
    try {
      if (nguon == ImageSource.camera) {
        final x = await ImagePicker().pickImage(source: nguon, imageQuality: 90);
        if (x != null) setState(() => _anh.add(x.path));
      } else {
        final ds = await ImagePicker().pickMultiImage(imageQuality: 90);
        setState(() => _anh.addAll(ds.take(4 - _anh.length).map((x) => x.path)));
        if (ds.length > 4) _bao('Mỗi lần gửi tối đa 4 ảnh, app lấy 4 ảnh đầu.');
      }
    } catch (_) {
      _bao('Chưa lấy được ảnh. Thầy cô cho app quyền dùng máy ảnh, ảnh trong Cài đặt.');
    }
  }

  String get _chuGiaoAn => [_tep?.chu ?? '', _chu.text.trim()].where((s) => s.trim().isNotEmpty).join('\n\n');

  Future<void> _tao() async {
    FocusManager.instance.primaryFocus?.unfocus();
    var chu = _chuGiaoAn;
    final pdf = _tep?.pdf;
    if (chu.isEmpty && _anh.isEmpty && pdf == null) {
      _bao('Thầy cô chọn tệp giáo án, chụp giáo án hoặc dán nội dung giáo án.');
      return;
    }
    if (chu.length < _itChu && _anh.isEmpty && pdf == null) {
      final tiep = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Giáo án ngắn quá'),
          content: const Text(
              'Mới có ít chữ nên AI chỉ dựng được khung bài theo các hoạt động và gợi ý nội dung từ tên bài. '
              'Thầy cô nhớ đối chiếu sách giáo khoa. Có tệp giáo án thì chọn tệp để bài chiếu bám đúng giáo án.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Thêm giáo án')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Vẫn tạo')),
          ],
        ),
      );
      if (tiep != true || !mounted) return;
    }
    var catBot = false;
    if (chu.length > _toiDaChu) {
      chu = chu.substring(0, _toiDaChu);
      catBot = true;
    }
    _ghiNho();
    setState(() {
      _dangTao = true;
      _giay = 0;
    });
    _dem = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _giay++);
    });
    final anh = <String>[];
    try {
      for (final p in _anh) {
        anh.add(await anhGuiAi(p));
      }
    } on FormatException {
      _dem?.cancel();
      setState(() => _dangTao = false);
      _bao('Có ảnh không mở được. Thầy cô chụp lại hoặc chọn ảnh khác.');
      return;
    }
    final kq = await TroLyApi.hoi(
      yeuCauTrinhChieu(capHoc: _cap, soTrang: _soTrang, noiDung: chu),
      loai: 'trinh_chieu',
      anh: anh,
      pdf: [if (pdf != null) pdf],
    );
    _dem?.cancel();
    if (!mounted) return;
    setState(() => _dangTao = false);
    if (kq.traLoi == null) {
      _bao(kq.loi ?? 'Chưa tạo được, thầy cô thử lại.');
      return;
    }
    final bai = BaiChieu.tuTraLoi(kq.traLoi!);
    if (bai == null) {
      _bao('AI trả lời chưa đúng dạng bài trình chiếu, thầy cô bấm Tạo lại.');
      return;
    }
    setState(() => _bai = bai);
    if (catBot) _bao('Giáo án dài, app đã gửi khoảng 29.000 chữ đầu. Phần sau thầy cô tạo thêm một bài riêng.');
  }

  Future<void> _sua(int i) async {
    final bai = _bai!;
    final tr = bai.trang[i];
    final td = TextEditingController(text: tr.tieuDe);
    final y = TextEditingController(text: tr.y.join('\n'));
    final gc = TextEditingController(text: tr.ghiChu);
    final kq = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Sửa trang ${i + 1}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const Key('tc_sua_tieu_de'),
                controller: td,
                decoration: const InputDecoration(labelText: 'Tiêu đề'),
                maxLines: 2,
                minLines: 1,
              ),
              const SizedBox(height: 10),
              TextField(
                key: const Key('tc_sua_y'),
                controller: y,
                decoration: InputDecoration(labelText: tr.laBia ? 'Môn, lớp (mỗi ý một dòng)' : 'Nội dung (mỗi ý một dòng)'),
                maxLines: 8,
                minLines: 3,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: gc,
                decoration: const InputDecoration(labelText: 'Ghi chú cho giáo viên (không hiện trên trang chiếu)'),
                maxLines: 6,
                minLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          if (bai.trang.length > 1)
            TextButton(
              onPressed: () => Navigator.pop(c, 'xoa'),
              style: TextButton.styleFrom(foregroundColor: const Color(0xFFC62828)),
              child: const Text('Bỏ trang này'),
            ),
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Thôi')),
          FilledButton(key: const Key('tc_luu_sua'), onPressed: () => Navigator.pop(c, 'luu'), child: const Text('Lưu')),
        ],
      ),
    );
    if (kq == 'luu' && mounted) {
      setState(() {
        tr.tieuDe = td.text.trim();
        tr.y = y.text.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
        tr.ghiChu = gc.text.trim();
        if (tr.laBia && tr.tieuDe.isNotEmpty) bai.tieuDe = tr.tieuDe;
      });
    } else if (kq == 'xoa' && mounted) {
      setState(() => bai.trang.removeAt(i));
    }
    // Không gọi dispose ngay: hộp sửa còn đang đóng (hiệu ứng) vẫn dùng các ô chữ này
  }

  Future<void> _luu() async {
    final bai = _bai;
    if (bai == null || bai.trang.isEmpty) return;
    try {
      final thu = (await thuMucApp('xuat')).path;
      var ten = tenTep(bai.tieuDe);
      if (ten.length > 40) ten = ten.substring(0, 40);
      ten = 'Trinh_chieu_${ten.isEmpty ? 'bai' : ten}_${dauThoiGian(DateTime.now())}';
      final pptx = File('$thu/$ten.pptx');
      await pptx.writeAsBytes(taoPptx(bai, _mauChon));
      final pdf = File('$thu/$ten.pdf');
      await pdf.writeAsBytes(await taoPdfTrinhChieu(bai, _mauChon));
      if (!mounted) return;
      await baoDaLuu(context, [pptx, pdf], tieuDe: 'Đã lưu bài trình chiếu (PowerPoint, PDF)');
    } catch (_) {
      _bao('Chưa lưu được tệp, thầy cô thử lại.');
    }
  }

  Future<void> _baoCao() async {
    const lyDos = ['Sai kiến thức', 'Không bám giáo án', 'Nội dung không phù hợp', 'Khác'];
    final lyDo = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Báo cáo bài trình chiếu này', style: TextStyle(fontWeight: FontWeight.w800))),
            for (final l in lyDos) ListTile(title: Text(l), onTap: () => Navigator.pop(c, l)),
          ],
        ),
      ),
    );
    if (lyDo == null || _bai == null) return;
    final bai = _bai!;
    final traLoi = [
      for (final t in bai.trang) [t.tieuDe, ...t.y].join(' | '),
    ].join('\n');
    final ok = await TroLyApi.baoCao(cauHoi: bai.tieuDe, traLoi: traLoi, lyDo: lyDo, loai: 'trinh_chieu');
    _bao(ok ? 'Đã gửi báo cáo. Cảm ơn thầy cô.' : 'Chưa gửi được, thầy cô thử lại sau.');
  }

  Widget _tieuMuc(String s) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 6),
        child: Text(s, style: const TextStyle(fontWeight: FontWeight.w800)),
      );

  @override
  Widget build(BuildContext context) {
    final bai = _bai;
    final tep = _tep;
    return Scaffold(
      appBar: AppBar(title: const Text('Tạo bài trình chiếu')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          const CauGiupViec('trinh_chieu'),
          const Text('Giáo án', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                key: const Key('tc_chon_tep'),
                onPressed: _dangTao ? null : _chonTep,
                icon: const Icon(Icons.upload_file, size: 18),
                label: const Text('Tệp giáo án (Word, PDF)'),
              ),
              OutlinedButton.icon(
                onPressed: _dangTao ? null : () => _themAnh(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined, size: 18),
                label: const Text('Chụp giáo án'),
              ),
              OutlinedButton.icon(
                onPressed: _dangTao ? null : () => _themAnh(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: const Text('Ảnh có sẵn'),
              ),
            ],
          ),
          if (tep != null || _anh.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (tep != null)
                    InputChip(
                      avatar: Icon(tep.pdf != null ? Icons.picture_as_pdf_outlined : Icons.description_outlined, size: 18),
                      label: Text(tep.ten, overflow: TextOverflow.ellipsis),
                      onDeleted: _dangTao ? null : () => setState(() => _tep = null),
                    ),
                  if (_anh.isNotEmpty)
                    InputChip(
                      avatar: const Icon(Icons.image_outlined, size: 18),
                      label: Text('${_anh.length} ảnh giáo án'),
                      onDeleted: _dangTao ? null : () => setState(_anh.clear),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          TextField(
            key: const Key('tc_o_chu'),
            controller: _chu,
            minLines: 3,
            maxLines: 10,
            enabled: !_dangTao,
            decoration: const InputDecoration(
              labelText: 'Hoặc dán nội dung giáo án',
              hintText: 'Dán giáo án, hoặc ghi thêm yêu cầu (ví dụ: thêm trang trò chơi khởi động)',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          _tieuMuc('Cấp học'),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final c in capHocTrinhChieu)
                ChoiceChip(label: Text(c), selected: _cap == c, onSelected: _dangTao ? null : (_) => setState(() => _cap = c)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            switch (_cap) {
              'Tiểu học' => 'Theo khung Công văn 2345/BGDĐT-GDTH: Khởi động, Khám phá, Luyện tập, Vận dụng.',
              'Mầm non' => 'Theo giáo án của trường: Gây hứng thú, Hoạt động chính, Kết thúc; chữ ít, to.',
              _ => 'Theo khung Công văn 5512/BGDĐT-GDTrH: Mở đầu, Hình thành kiến thức mới, Luyện tập, Vận dụng.',
            },
            style: const TextStyle(fontSize: 12.5, color: MauApp.chuPhu),
          ),
          _tieuMuc('Số trang chiếu (khoảng)'),
          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: [for (final n in soTrangTrinhChieu) ButtonSegment(value: n, label: Text('$n'))],
            selected: {_soTrang},
            onSelectionChanged: _dangTao ? null : (s) => setState(() => _soTrang = s.first),
          ),
          _tieuMuc('Màu bài chiếu'),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            children: [
              for (final m in mauTrinhChieu)
                ChoiceChip(
                  avatar: CircleAvatar(backgroundColor: Color(0xFF000000 | m.chinh), radius: 9),
                  label: Text(m.ten),
                  selected: _mau == m.ma,
                  onSelected: (_) => setState(() => _mau = m.ma),
                ),
            ],
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            key: const Key('tc_tao'),
            onPressed: _dangTao ? null : _tao,
            icon: _dangTao
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.auto_awesome_outlined),
            label: Text(_dangTao ? 'AI đang dựng bài… $_giay giây' : (bai == null ? 'Tạo bài trình chiếu' : 'Tạo lại')),
          ),
          const SizedBox(height: 4),
          const Text(
            'Thường mất khoảng 30 giây đến 1 phút. Mỗi ngày tạo được 5 bài.',
            style: TextStyle(fontSize: 12, color: MauApp.chuPhu),
          ),
          if (bai != null) ...[
            const SizedBox(height: 18),
            Text('${bai.tieuDe} (${bai.trang.length} trang)', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 2),
            const Text('Bấm vào trang để sửa chữ, ghi chú hoặc bỏ trang.', style: TextStyle(fontSize: 12.5, color: MauApp.chuPhu)),
            const SizedBox(height: 10),
            for (var i = 0; i < bai.trang.length; i++)
              _TheTrang(
                key: ValueKey('tc_trang_$i'),
                tr: bai.trang[i],
                so: i + 1,
                tong: bai.trang.length,
                tenBai: bai.tieuDe,
                mau: _mauChon,
                onTap: _dangTao ? null : () => _sua(i),
              ),
            const Text(
              'AI có thể nhầm. Thầy cô xem lại từng trang trước khi chiếu. Ghi chú giáo viên nằm ở phần Ghi chú của tệp PowerPoint.',
              style: TextStyle(fontSize: 11.5, color: MauApp.chuPhu),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(onPressed: _baoCao, icon: const Icon(Icons.flag_outlined, size: 16), label: const Text('Báo cáo')),
            ),
            FilledButton.icon(
              key: const Key('tc_luu'),
              onPressed: _dangTao ? null : _luu,
              icon: const Icon(Icons.save_alt),
              label: const Text('Lưu bài trình chiếu (PowerPoint, PDF)'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Một trang chiếu thu nhỏ (vẽ giống tệp PowerPoint, PDF) kèm ghi chú giáo viên.
class _TheTrang extends StatelessWidget {
  final TrangChieu tr;
  final int so;
  final int tong;
  final String tenBai;
  final MauTrinhChieu mau;
  final VoidCallback? onTap;
  const _TheTrang({super.key, required this.tr, required this.so, required this.tong, required this.tenBai, required this.mau, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(aspectRatio: 16 / 9, child: FittedBox(child: SizedBox(width: 960, height: 540, child: _VeTrang(tr, so, tong, tenBai, mau)))),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$so', style: const TextStyle(fontWeight: FontWeight.w800, color: MauApp.chuPhu)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        tr.ghiChu.isEmpty ? 'Chưa có ghi chú giáo viên' : 'Ghi chú: ${tr.ghiChu}',
                        style: const TextStyle(fontSize: 12.5, color: MauApp.chuPhu, height: 1.35),
                      ),
                    ),
                    const Icon(Icons.edit_outlined, size: 18, color: MauApp.chuPhu),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Trang chiếu khổ 960 x 540 điểm, cùng bố cục với tệp PDF (tep_trinh_chieu_pdf.dart).
class _VeTrang extends StatelessWidget {
  final TrangChieu tr;
  final int so;
  final int tong;
  final String tenBai;
  final MauTrinhChieu mau;
  const _VeTrang(this.tr, this.so, this.tong, this.tenBai, this.mau);

  Color _m(int c) => Color(0xFF000000 | c);

  Widget _vua(double rong, Widget con, {Alignment canh = Alignment.topLeft}) =>
      FittedBox(fit: BoxFit.scaleDown, alignment: canh, child: SizedBox(width: rong, child: con));

  @override
  Widget build(BuildContext context) {
    if (tr.laBia) {
      final phu = tr.y.where((s) => s.isNotEmpty).join(' · ');
      return Stack(children: [
        Container(color: _m(mau.chinh)),
        Positioned(left: 0, right: 0, bottom: 0, height: 162, child: Container(color: _m(mau.dam))),
        Positioned(
          left: 54,
          top: 126,
          width: 852,
          height: 189,
          child: _vua(
            852,
            Text(tr.tieuDe, style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w800, color: Colors.white, height: 1.2)),
            canh: Alignment.bottomLeft,
          ),
        ),
        if (phu.isNotEmpty)
          Positioned(
            left: 54,
            top: 402,
            width: 852,
            height: 94,
            child: _vua(852, Text(phu, style: const TextStyle(fontSize: 24, color: Colors.white))),
          ),
      ]);
    }
    final co = coChuNoiDung(tr.y) / 100;
    final nhan = tr.hoatDong.trim();
    const chu = Color(0xFF14233A);
    return ColoredBox(
      color: Colors.white,
      child: Column(children: [
        Container(
          height: 108,
          color: _m(mau.chinh),
          padding: const EdgeInsets.symmetric(horizontal: 43),
          alignment: Alignment.centerLeft,
          child: _vua(
            874,
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              if (nhan.isNotEmpty)
                Text(nhan.toUpperCase(), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _m(mau.nhat))),
              Text(tr.tieuDe, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white, height: 1.2)),
            ]),
            canh: Alignment.centerLeft,
          ),
        ),
        Container(height: 6, color: _m(mau.nhat)),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(43, 24, 43, 0),
            child: _vua(
              874,
              Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                for (final y in tr.y)
                  Padding(
                    padding: EdgeInsets.only(bottom: co * 0.45),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      SizedBox(width: 36, child: Text('•', style: TextStyle(fontSize: co, color: chu))),
                      Expanded(child: Text(y, style: TextStyle(fontSize: co, color: chu, height: 1.25))),
                    ]),
                  ),
              ]),
            ),
          ),
        ),
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 43),
          alignment: Alignment.centerRight,
          child: Text('$tenBai   ·   $so/$tong',
              maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xFF8A94A6))),
        ),
      ]),
    );
  }
}
