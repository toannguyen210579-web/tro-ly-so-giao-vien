import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/dich.dart';
import '../main.dart';
import '../services/anh_trang.dart' show anhGuiAi, chonTrangTuTep;
import '../services/chia_se.dart';
import '../services/chon_tep.dart';
import '../services/dich_tren_may.dart';
import '../services/tep_pdf.dart';
import '../services/tep_word.dart' show taoDocx, taoDocxBang;
import '../services/tro_ly_api.dart';
import 'cau_giup_viec.dart';

/// Dịch tài liệu (tiện ích riêng, chốt 24/11/2026): dán chữ, tệp Word, PDF (cả PDF quét), ảnh chụp trang sách;
/// AI tự nhận ngôn ngữ gốc; dịch sang Việt, Anh, Trung, Nhật, Hàn, Pháp; kiểu Sát nghĩa hoặc Dễ hiểu; song ngữ từng đoạn.
/// Kết quả ra tệp Word và PDF, hộp "Đã lưu tệp" tại chỗ.
/// AI chính: Claude qua máy chủ (chế độ dich, mỗi lượt một trang, 20 trang mỗi ngày).
/// Phòng hờ: mất mạng thì đoạn ngắn Anh ⇄ Việt dịch trên máy bằng ML Kit, ghi "Dịch bởi Google".
/// Không dịch tiếng dân tộc thiểu số (AI dịch kém, gửi phụ huynh sai thì hại), chưa dịch đường link.
class DichTaiLieu extends StatefulWidget {
  const DichTaiLieu({super.key});

  @override
  State<DichTaiLieu> createState() => _DichTaiLieuState();
}

class _DichTaiLieuState extends State<DichTaiLieu> {
  final _chu = TextEditingController();
  final _trang = <String>[]; // ảnh, trang PDF cần dịch (đường dẫn tệp ảnh)
  String _den = 'Tiếng Việt';
  String _kieu = kieuSatNghia;
  bool _songNgu = false;
  bool _dangDich = false;
  String _tienDo = '';

  // Kết quả: từng cặp (nguyên văn, bản dịch); không song ngữ thì nguyên văn để trống
  List<(String, String)> _ket = [];
  bool _ketSongNgu = false;
  bool _dichTrenMay = false;
  String _denKet = '';

  @override
  void initState() {
    super.initState();
    DichTrenMay.taiSanNeuCan();
  }

  @override
  void dispose() {
    _chu.dispose();
    super.dispose();
  }

  void _bao(String s) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  Future<void> _chupAnh() async {
    try {
      while (true) {
        final x = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 90);
        if (x == null) break;
        setState(() => _trang.add(x.path));
        if (!mounted) return;
        final tiep = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text('Đã có ${_trang.length} trang'),
            content: const Text('Chụp thêm trang tiếp theo?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Xong')),
              FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Chụp thêm trang')),
            ],
          ),
        );
        if (tiep != true) break;
      }
    } catch (_) {
      _bao('Chưa mở được máy ảnh. Thầy cô cho app quyền dùng máy ảnh trong Cài đặt.');
    }
  }

  Future<void> _chonAnh() async {
    try {
      final ds = await ImagePicker().pickMultiImage(imageQuality: 90);
      if (ds.isNotEmpty && mounted) setState(() => _trang.addAll(ds.map((x) => x.path)));
    } catch (_) {
      _bao('Chưa lấy được ảnh. Thầy cô cho app quyền dùng ảnh trong Cài đặt.');
    }
  }

  Future<void> _chonTep() async {
    final loai = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('Tệp Word, văn bản (.docx, .doc, .txt)'),
              onTap: () => Navigator.pop(c, 'chu'),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('Tệp PDF hoặc ảnh (cả PDF quét)'),
              subtitle: const Text('Mỗi trang PDF dịch thành một trang'),
              onTap: () => Navigator.pop(c, 'trang'),
            ),
          ],
        ),
      ),
    );
    if (loai == null) return;
    try {
      if (loai == 'chu') {
        final t = await chonTep(duoiChu);
        if (t?.chu == null || !mounted) return;
        setState(() => _chu.text = [_chu.text.trim(), t!.chu!].where((x) => x.isNotEmpty).join('\n\n'));
      } else {
        final kq = await chonTrangTuTep();
        if (kq == null || !mounted) return;
        if (kq.loiNhan != null) _bao(kq.loiNhan!);
        setState(() => _trang.addAll(kq.trang));
      }
    } on FormatException catch (e) {
      _bao(e.message);
    } catch (_) {
      _bao('Chưa mở được tệp, thầy cô thử lại.');
    }
  }

  Future<void> _dich() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final chu = _chu.text.trim();
    if (chu.isEmpty && _trang.isEmpty) {
      _bao('Thầy cô dán chữ, chụp ảnh hoặc chọn tệp cần dịch.');
      return;
    }
    final dau = dauYeuCauDich(_den, _kieu, _songNgu);
    final khoi = chiaKhoiDich(tachDoanDich(chu));
    final trang = List<String>.from(_trang);
    final tong = khoi.length + trang.length;
    setState(() {
      _dangDich = true;
      _ket = [];
      _ketSongNgu = _songNgu;
      _dichTrenMay = false;
      _denKet = _den;
    });
    final ket = <(String, String)>[];
    String? loi;
    var xong = 0;
    for (final k in khoi) {
      setState(() => _tienDo = 'Đang dịch trang ${xong + 1}/$tong…');
      final kq = await TroLyApi.hoi('$dau\n---\n${k.join('\n\n')}', loai: 'dich');
      if (!mounted) return;
      if (kq.traLoi == null) {
        // Mất mạng ngay từ đầu: đoạn ngắn Anh ⇄ Việt dịch trên máy
        final matMang = (kq.loi ?? '').startsWith('Không kết nối được');
        if (matMang && xong == 0 && trang.isEmpty && khoi.length == 1 && DichTrenMay.dichDuoc(chu, _den)) {
          setState(() => _tienDo = 'Mất mạng, đang dịch trên máy…');
          final t = await DichTrenMay.dich(chu, _den);
          if (!mounted) return;
          if (t != null) {
            ket.addAll(_songNgu ? ghepSongNgu(k, t) : [('', t)]);
            _dichTrenMay = true;
            xong++;
            break;
          }
          loi = 'Mất mạng, và máy chưa có gói dịch Anh ⇄ Việt (cần mạng wifi để tải lần đầu).';
        } else {
          loi = kq.loi ?? 'Chưa dịch được, thầy cô thử lại.';
        }
        break;
      }
      ket.addAll(_songNgu ? ghepSongNgu(k, kq.traLoi!) : [('', boDauMarkdownDich(kq.traLoi!))]);
      xong++;
    }
    if (loi == null) {
      for (final p in trang) {
        setState(() => _tienDo = 'Đang dịch trang ${xong + 1}/$tong…');
        final String anh;
        try {
          anh = await anhGuiAi(p);
        } on FormatException {
          loi = 'Có trang ảnh không mở được, đã bỏ qua.';
          continue;
        }
        final kq = await TroLyApi.hoi(dau, loai: 'dich', anh: [anh]);
        if (!mounted) return;
        if (kq.traLoi == null) {
          loi = kq.loi ?? 'Chưa dịch được, thầy cô thử lại.';
          break;
        }
        ket.add(_songNgu ? tachNguyenVanBanDich(kq.traLoi!) : ('', boDauMarkdownDich(kq.traLoi!)));
        xong++;
      }
    }
    if (!mounted) return;
    setState(() {
      _dangDich = false;
      _tienDo = '';
      _ket = ket;
    });
    if (loi != null) {
      _bao(xong == 0 ? loi : 'Đã dịch được $xong/$tong trang. $loi');
    }
  }

  String get _chuKetQua => _ket
      .map((e) => _ketSongNgu && e.$1.isNotEmpty ? '${e.$1}\n→ ${e.$2}' : e.$2)
      .join('\n\n');

  Future<void> _luuTep() async {
    if (_ket.isEmpty) return;
    try {
      final thu = (await thuMucApp('xuat')).path;
      final ten = 'Ban_dich_${tenTep(_denKet)}_${dauThoiGian(DateTime.now())}';
      final tieuDe = _ketSongNgu ? 'BẢN DỊCH SONG NGỮ' : 'BẢN DỊCH';
      final ds = <File>[];
      final word = File('$thu/$ten.docx');
      if (_ketSongNgu) {
        await word.writeAsBytes(taoDocxBang(
          tieuDe: tieuDe,
          phuDe: 'Dịch sang $_denKet',
          bang: [
            ['Nguyên văn', 'Bản dịch'],
            for (final (g, d) in _ket) [g.replaceAll('\n', ' '), d.replaceAll('\n', ' ')],
          ],
          doRong: const [500, 500],
          dongCuoi: [if (_dichTrenMay) DichTrenMay.ghiNguon],
        ));
      } else {
        await word.writeAsBytes(taoDocx([
          for (final (_, d) in _ket) ...tachDoanDich(d),
          if (_dichTrenMay) DichTrenMay.ghiNguon,
        ], tieuDe: tieuDe));
      }
      ds.add(word);
      final cjk = coChuCJK(_chuKetQua);
      // Phông PDF của app chưa có chữ Trung, Nhật, Hàn: chỉ xuất Word cho các bản dịch có chữ này
      if (!cjk) {
        final doc = pw.Document(theme: await PhongPdf.theme());
        doc.addPage(pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(70, 50, 50, 50),
          build: (_) => [
            pw.Center(child: pw.Text(tieuDe, style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold))),
            pw.Center(child: pw.Text('Dịch sang $_denKet', style: pw.TextStyle(fontSize: 11, fontStyle: pw.FontStyle.italic))),
            pw.SizedBox(height: 14),
            for (final (g, d) in _ket) ...[
              if (_ketSongNgu && g.isNotEmpty)
                pw.Paragraph(
                  text: g,
                  style: pw.TextStyle(fontSize: 11.5, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700, lineSpacing: 2),
                ),
              for (final dd in tachDoanDich(d))
                pw.Paragraph(text: dd, style: pw.TextStyle(fontSize: 12.5, lineSpacing: 3), textAlign: pw.TextAlign.justify),
              if (_ketSongNgu) pw.Divider(color: PdfColors.grey400, thickness: 0.5),
            ],
            if (_dichTrenMay) pw.Paragraph(text: DichTrenMay.ghiNguon, style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic)),
          ],
        ));
        final pdf = File('$thu/$ten.pdf');
        await pdf.writeAsBytes(await doc.save());
        ds.add(pdf);
      }
      if (!mounted) return;
      await baoDaLuu(context, ds,
          tieuDe: cjk ? 'Đã lưu bản dịch (Word; có chữ Trung, Nhật, Hàn nên chưa xuất PDF)' : 'Đã lưu bản dịch (Word, PDF)');
    } catch (_) {
      _bao('Chưa lưu được tệp, thầy cô thử lại.');
    }
  }

  Future<void> _baoCao() async {
    const lyDos = ['Dịch sai nghĩa', 'Bỏ sót nội dung', 'Nội dung không phù hợp', 'Khác'];
    final lyDo = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Báo cáo bản dịch này', style: TextStyle(fontWeight: FontWeight.w800))),
            for (final l in lyDos) ListTile(title: Text(l), onTap: () => Navigator.pop(c, l)),
          ],
        ),
      ),
    );
    if (lyDo == null) return;
    final ok = await TroLyApi.baoCao(cauHoi: _chu.text.trim(), traLoi: _chuKetQua, lyDo: lyDo, loai: 'dich');
    _bao(ok ? 'Đã gửi báo cáo. Cảm ơn thầy cô.' : 'Chưa gửi được, thầy cô thử lại sau.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dịch tài liệu')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          const CauGiupViec('dich'),
          TextField(
            controller: _chu,
            minLines: 5,
            maxLines: 12,
            decoration: const InputDecoration(
              labelText: 'Chữ cần dịch',
              hintText: 'Dán hoặc gõ chữ cần dịch, hoặc chụp ảnh, chọn tệp ở dưới',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _dangDich ? null : _chupAnh,
                icon: const Icon(Icons.photo_camera_outlined, size: 18),
                label: const Text('Chụp ảnh'),
              ),
              OutlinedButton.icon(
                onPressed: _dangDich ? null : _chonAnh,
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: const Text('Ảnh có sẵn'),
              ),
              OutlinedButton.icon(
                onPressed: _dangDich ? null : _chonTep,
                icon: const Icon(Icons.upload_file, size: 18),
                label: const Text('Tệp PDF, Word'),
              ),
            ],
          ),
          if (_trang.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: InputChip(
                  avatar: const Icon(Icons.image_outlined, size: 18),
                  label: Text('${_trang.length} trang ảnh, PDF'),
                  onDeleted: _dangDich ? null : () => setState(_trang.clear),
                ),
              ),
            ),
          const SizedBox(height: 16),
          const Text('Dịch sang', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final n in dsNgonNguDich)
                ChoiceChip(label: Text(n), selected: _den == n, onSelected: _dangDich ? null : (_) => setState(() => _den = n)),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Ngôn ngữ gốc app tự nhận.', style: TextStyle(fontSize: 12.5, color: MauApp.chuPhu)),
          const SizedBox(height: 14),
          const Text('Kiểu dịch', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: kieuSatNghia, label: Text('Sát nghĩa'), icon: Icon(Icons.gavel_outlined)),
              ButtonSegment(value: kieuDeHieu, label: Text('Dễ hiểu'), icon: Icon(Icons.child_care_outlined)),
            ],
            selected: {_kieu},
            onSelectionChanged: _dangDich ? null : (s) => setState(() => _kieu = s.first),
          ),
          const SizedBox(height: 4),
          Text(
            _kieu == kieuSatNghia ? 'Bám câu chữ, văn phong trang trọng: văn bản, tài liệu.' : 'Câu ngắn, từ đơn giản: đưa học sinh đọc.',
            style: const TextStyle(fontSize: 12.5, color: MauApp.chuPhu),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _songNgu,
            onChanged: _dangDich ? null : (v) => setState(() => _songNgu = v),
            title: const Text('Song ngữ', style: TextStyle(fontWeight: FontWeight.w800)),
            subtitle: const Text('Bản gốc và bản dịch đặt cạnh nhau từng đoạn'),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _dangDich ? null : _dich,
            icon: _dangDich
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.translate_rounded),
            label: Text(_dangDich ? _tienDo : 'Dịch'),
          ),
          const SizedBox(height: 4),
          const Text(
            'Mỗi trang chữ (khoảng 2.500 ký tự), mỗi ảnh hoặc trang PDF tính một lượt; mỗi ngày dịch được 20 trang.',
            style: TextStyle(fontSize: 12, color: MauApp.chuPhu),
          ),
          if (_ket.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Bản dịch (${_denKet.toLowerCase()})', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 8),
                  for (final (g, d) in _ket) ...[
                    if (_ketSongNgu && g.isNotEmpty)
                      SelectableText(g, style: const TextStyle(fontStyle: FontStyle.italic, color: MauApp.chuPhu, height: 1.4)),
                    SelectableText(d, style: const TextStyle(fontSize: 15, height: 1.45)),
                    const SizedBox(height: 10),
                  ],
                  Text(
                    _dichTrenMay ? DichTrenMay.ghiNguon : 'AI có thể nhầm. Thầy cô đọc lại bản dịch trước khi dùng.',
                    style: const TextStyle(fontSize: 11.5, color: MauApp.chuPhu),
                  ),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 4,
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _chuKetQua));
                          _bao('Đã chép bản dịch.');
                        },
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('Chép'),
                      ),
                      if (!_dichTrenMay)
                        TextButton.icon(
                          onPressed: _baoCao,
                          icon: const Icon(Icons.flag_outlined, size: 16),
                          label: const Text('Báo cáo'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _luuTep,
              icon: const Icon(Icons.save_alt),
              label: const Text('Lưu bản dịch (Word, PDF)'),
            ),
          ],
        ],
      ),
    );
  }
}
