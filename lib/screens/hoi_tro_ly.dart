import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';

import '../main.dart';
import '../data/tin_kenh.dart';
import 'tin_kenh.dart' show ManXemClip;
import '../services/an_danh.dart';
import '../services/chon_tep.dart';
import '../services/tro_ly_api.dart';
import 'cau_giup_viec.dart';
import 'chu_ai.dart';

class _TinNhan {
  final bool laNguoiDung;
  final String noiDung;
  final String? cauHoi; // câu hỏi đi kèm, để báo cáo
  final String? anh; // đường dẫn ảnh thầy cô chụp kèm câu hỏi
  final bool loi; // câu báo lỗi, không đưa vào ngữ cảnh hỏi tiếp
  final String? cauGoc; // câu thầy cô gõ, để bấm Gửi lại khi lỗi mạng
  final String? traLoiGoc; // câu trả lời còn mã HS01…, dùng làm ngữ cảnh hỏi tiếp và báo cáo
  final List<TinKenh> tinKenh; // toàn bộ clip của kênh (để mở xem trong app)
  final List<int> goiY; // vị trí các clip AI nhắc tới, hiện nút bấm mở ngay
  const _TinNhan(this.laNguoiDung, this.noiDung,
      {this.cauHoi, this.anh, this.loi = false, this.cauGoc, this.traLoiGoc, this.tinKenh = const [], this.goiY = const []});
}

/// Hỏi Trợ lý: hỏi mọi việc, chụp ảnh bài tập để hỏi. Không hiện số câu; máy chủ vẫn có trần chống lạm dụng.
/// Câu có tên học sinh, số điện thoại, email được làm sạch ngay trên máy và gửi sang Claude.
class HoiTroLy extends StatefulWidget {
  final String? cauHoiDau;
  const HoiTroLy({super.key, this.cauHoiDau});

  @override
  State<HoiTroLy> createState() => _HoiTroLyState();
}

class _HoiTroLyState extends State<HoiTroLy> {
  final _o = TextEditingController();
  final _cuon = ScrollController();
  final _ds = <_TinNhan>[];
  bool _dangCho = false;
  XFile? _anh;
  TepTaiLen? _tep; // tệp PDF hoặc ảnh tải lên
  bool _riengTu = false; // cuộc trò chuyện đã có thông tin cá nhân thì các câu sau cũng đi Claude
  Map<String, String> _ma = {}; // tên học sinh → mã, giữ suốt cuộc trò chuyện

  @override
  void initState() {
    super.initState();
    final c = widget.cauHoiDau;
    if (c != null && c.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _gui(c));
    }
  }

  Future<void> _chonAnh() async {
    final nguon = await showModalBottomSheet<Object>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Chụp ảnh'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Chọn ảnh có sẵn'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.upload_file),
              title: const Text('Tải tệp lên (PDF, Word, ảnh)'),
              onTap: () => Navigator.pop(ctx, 'tep'),
            ),
          ],
        ),
      ),
    );
    if (nguon == null) return;
    if (nguon == 'tep') {
      try {
        final t = await chonTep(['pdf', ...duoiChu, ...duoiAnh]);
        if (t == null || !mounted) return;
        if (t.chu != null) {
          setState(() => _o.text = [_o.text.trim(), t.chu!].where((x) => x.isNotEmpty).join('\n\n'));
        } else {
          setState(() {
            _tep = t;
            _anh = null;
          });
        }
      } on FormatException catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chưa mở được tệp, thầy cô thử lại.')));
        }
      }
      return;
    }
    if (nguon is! ImageSource) return;
    try {
      final x = await ImagePicker().pickImage(source: nguon, maxWidth: 1568, maxHeight: 1568, imageQuality: 80);
      if (x != null && mounted) {
        setState(() {
          _anh = x;
          _tep = null;
        });
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa lấy được ảnh. Thầy cô cho app quyền dùng máy ảnh, ảnh trong Cài đặt.')),
      );
    }
  }

  @override
  void dispose() {
    _o.dispose();
    _cuon.dispose();
    super.dispose();
  }

  /// Clip nào có tít xuất hiện trong câu trả lời thì gợi ý; không thấy tít nào thì gợi ý clip mới nhất.
  List<int> _clipDuocNhac(String traLoi, List<TinKenh> ds) {
    if (ds.isEmpty) return const [];
    String chuan(String x) => x.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N} ]', unicode: true), '').replaceAll(RegExp(r'\s+'), ' ').trim();
    final tl = chuan(traLoi);
    final co = [for (var i = 0; i < ds.length; i++) if (chuan(ds[i].tit).length > 8 && tl.contains(chuan(ds[i].tit))) i];
    return (co.isEmpty ? [0] : co).take(3).toList();
  }

  Future<void> _gui([String? cau]) async {
    final c = (cau ?? _o.text).trim();
    final anh = _anh;
    final tep = _tep;
    if ((c.isEmpty && anh == null && tep == null) || _dangCho) return;
    _o.clear();
    setState(() {
      _ds.add(_TinNhan(true, [if (tep != null) '📎 ${tep.ten}', if (c.isNotEmpty) c else if (anh != null) '(Ảnh)'].join('\n'), anh: anh?.path));
      _anh = null;
      _tep = null;
      _dangCho = true;
    });
    _cuonXuong();
    final sach = await lamSachCauHoi(c, maDaCo: _ma);
    _ma = sach.ma;
    _riengTu = _riengTu || sach.riengTu;
    // Các lượt hỏi đáp trước, để thầy cô hỏi tiếp ("giải thích thêm", "cho ví dụ") không phải nhắc lại
    final lichSu = [
      for (final t in _ds)
        if (!t.laNguoiDung && !t.loi && t.cauHoi != null && t.cauHoi!.isNotEmpty) (t.cauHoi!, t.traLoiGoc ?? t.noiDung),
    ];
    final dsAnh = anh == null ? <String>[] : [base64Encode(await File(anh.path).readAsBytes())];
    if (tep?.anh != null) dsAnh.add(tep!.anh!);
    // Hỏi về kênh Việt Nam Tiêu Điểm, clip, tin mới: gửi kèm danh sách clip của kênh để AI trả lời đúng
    var guiDi = sach.noiDung;
    var tinKenh = <TinKenh>[];
    if (RegExp(r'ti[eê]u\s*đi[eể]m|vntđ|vntd|(clip|cip|video|tin|kênh)\s+(của|trong|trên)\s+app', caseSensitive: false)
        .hasMatch(c)) {
      try {
        final tin = await NguonTin.tai();
        if (tin.isNotEmpty) {
          tinKenh = tin;
          guiDi = '$guiDi\n\n(Thông tin kèm theo để trả lời, không nhắc lại phần này: "Việt Nam Tiêu Điểm" là kênh clip tin giáo dục ngắn '
              'đi cùng app, xem trong mục Tin của app. Khi gợi ý clip, ghi đúng nguyên văn tít clip trong ngoặc kép; '
              'app sẽ hiện nút bấm mở clip đó ngay dưới câu trả lời, nên không chỉ sang trang web hay kênh khác. '
              'Các clip gần đây, mới nhất trước:\n'
              '${tin.take(15).map((t) => '- ${t.ngay.day}/${t.ngay.month}: "${t.tit}" ${t.tomTat}').join('\n')})';
        }
      } catch (_) {}
    }
    final kq = await TroLyApi.hoi(guiDi,
        anh: dsAnh, pdf: tep?.pdf == null ? const [] : [tep!.pdf!], riengTu: _riengTu, lichSu: lichSu);
    if (!mounted) return;
    setState(() {
      _dangCho = false;
      _ds.add(_TinNhan(
        false,
        kq.traLoi == null ? (kq.loi ?? 'Có lỗi, thầy cô thử lại.') : traTen(kq.traLoi!, _ma),
        cauHoi: sach.noiDung,
        loi: kq.traLoi == null,
        cauGoc: c,
        traLoiGoc: kq.traLoi,
        tinKenh: tinKenh,
        goiY: kq.traLoi == null ? const [] : _clipDuocNhac(kq.traLoi!, tinKenh),
      ));
    });
    _cuonXuong();
  }

  void _cuonXuong() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_cuon.hasClients) {
        _cuon.animateTo(_cuon.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _baoCao(_TinNhan t) async {
    const lyDos = ['Sai thông tin', 'Nội dung không phù hợp', 'Xúc phạm, độc hại', 'Khác'];
    final lyDo = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Báo cáo câu trả lời này', style: TextStyle(fontWeight: FontWeight.w800))),
            for (final l in lyDos) ListTile(title: Text(l), onTap: () => Navigator.pop(ctx, l)),
          ],
        ),
      ),
    );
    if (lyDo == null) return;
    final ok = await TroLyApi.baoCao(cauHoi: t.cauHoi ?? '', traLoi: t.traLoiGoc ?? t.noiDung, lyDo: lyDo, loai: 'hoi');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Đã gửi báo cáo. Cảm ơn thầy cô.' : 'Chưa gửi được, thầy cô thử lại sau.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hỏi Trợ lý'),
      ),
      body: Column(
        children: [
          const CauGiupViec('hoi', margin: EdgeInsets.fromLTRB(16, 4, 16, 4)),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Hỏi Trợ lý mọi việc: chế độ, văn bản, dạy học hay chuyện thường ngày. Chụp ảnh bài tập để hỏi cách giải.',
              style: TextStyle(color: MauApp.chuPhu),
            ),
          ),
          SafeArea(
            top: false,
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_tep != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: InputChip(
                          avatar: Icon(_tep!.pdf != null ? Icons.picture_as_pdf_outlined : Icons.image_outlined, size: 18),
                          label: Text(_tep!.ten, overflow: TextOverflow.ellipsis),
                          onDeleted: () => setState(() => _tep = null),
                        ),
                      ),
                    ),
                  if (_anh != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(File(_anh!.path), height: 80, fit: BoxFit.cover),
                            ),
                            Positioned(
                              right: 0,
                              top: 0,
                              child: IconButton.filledTonal(
                                visualDensity: VisualDensity.compact,
                                tooltip: 'Bỏ ảnh',
                                onPressed: () => setState(() => _anh = null),
                                icon: const Icon(Icons.close, size: 16),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Row(
                children: [
                  IconButton(
                    tooltip: 'Chụp ảnh, tải tệp lên',
                    onPressed: _dangCho ? null : _chonAnh,
                    icon: const Icon(Icons.attach_file, color: MauApp.xanhDam),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _o,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _gui(),
                      decoration: InputDecoration(
                        hintText: 'Thầy cô cần hỏi gì?',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Gửi câu hỏi',
                    onPressed: _dangCho ? null : () => _gui(),
                    icon: const Icon(Icons.arrow_upward),
                  ),
                ],
              ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _cuon,
              padding: const EdgeInsets.all(16),
              itemCount: _ds.length + (_dangCho ? 1 : 0),
              itemBuilder: (_, i) {
                if (i == _ds.length) {
                  return const Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()),
                  );
                }
                final t = _ds[i];
                return Align(
                  alignment: t.laNguoiDung ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                    decoration: BoxDecoration(
                      color: t.laNguoiDung ? MauApp.xanhTroi : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (t.anh != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(File(t.anh!), height: 140, fit: BoxFit.cover),
                            ),
                          ),
                        if (t.laNguoiDung)
                          SelectableText(t.noiDung, style: const TextStyle(fontSize: 15, height: 1.45, color: Colors.white))
                        else
                          ChuAI(t.noiDung, style: const TextStyle(fontSize: 15, height: 1.45, color: MauApp.chu)),
                        if (t.loi && (t.cauGoc ?? '').isNotEmpty)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: _dangCho ? null : () => _gui(t.cauGoc),
                              icon: const Icon(Icons.refresh, size: 16),
                              label: const Text('Gửi lại'),
                            ),
                          ),
                        if (!t.laNguoiDung && !t.loi && t.goiY.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          for (final i in t.goiY)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: OutlinedButton.icon(
                                onPressed: () => Navigator.of(context)
                                    .push(MaterialPageRoute(builder: (_) => ManXemClip(ds: t.tinKenh, batDau: i))),
                                icon: const Icon(Icons.play_circle_outline),
                                label: Text('Xem clip: ${t.tinKenh[i].tit}', maxLines: 2, overflow: TextOverflow.ellipsis),
                              ),
                            ),
                          if (trangKenhFacebook.isNotEmpty)
                            TextButton.icon(
                              onPressed: () => launchUrl(Uri.parse(trangKenhFacebook), mode: LaunchMode.externalApplication),
                              icon: const Icon(Icons.open_in_new, size: 18),
                              label: const Text('Mở trang kênh Việt Nam Tiêu Điểm'),
                            ),
                        ],
                        if (!t.laNguoiDung && !t.loi) ...[
                          const SizedBox(height: 4),
                          const Text(
                            'AI có thể nhầm. Thầy cô kiểm tra lại thông tin quan trọng trước khi dùng.',
                            style: TextStyle(fontSize: 11.5, color: MauApp.chuPhu),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () => _baoCao(t),
                              icon: const Icon(Icons.flag_outlined, size: 16),
                              label: const Text('Báo cáo'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
