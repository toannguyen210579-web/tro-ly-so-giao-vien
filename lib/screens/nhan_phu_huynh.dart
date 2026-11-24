import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import '../services/tro_ly_api.dart';
import 'cau_giup_viec.dart';
import 'nhan_xet.dart' show docLop;
import 'nut_noi.dart';
import '../services/chia_se.dart';

class _Mau {
  final String ten;
  final String noiDung;
  const _Mau(this.ten, this.noiDung);
}

const _dsMau = [
  _Mau('Mời họp phụ huynh',
      'Kính gửi quý phụ huynh em [tên học sinh],\nNhà trường kính mời quý phụ huynh dự họp phụ huynh lúc [giờ], ngày [ngày] tại phòng [số phòng].\nKính mong quý phụ huynh sắp xếp tham dự đầy đủ.\nTrân trọng,\nGVCN [họ tên] · lớp [lớp]'),
  _Mau('Học sinh nghỉ học',
      'Kính gửi quý phụ huynh em [tên học sinh],\nHôm nay [ngày], em vắng mặt tại lớp [có phép / không phép]. Kính mong quý phụ huynh phản hồi để nhà trường nắm tình hình của em.\nTrân trọng,\nGVCN [họ tên] · lớp [lớp]'),
  _Mau('Kết quả học tập',
      'Kính gửi quý phụ huynh em [tên học sinh],\nKết quả [giữa kỳ / cuối kỳ] của em: [nhận xét].\nKính mong gia đình tiếp tục phối hợp cùng nhà trường động viên em.\nTrân trọng,\nGVCN [họ tên] · lớp [lớp]'),
  _Mau('Khen ngợi',
      'Kính gửi quý phụ huynh em [tên học sinh],\nThời gian qua em có tiến bộ ở [nội dung]. Giáo viên xin chia sẻ để gia đình cùng động viên em.\nTrân trọng,\nGVCN [họ tên] · lớp [lớp]'),
  _Mau('Nhắc nộp khoản',
      'Kính gửi quý phụ huynh em [tên học sinh],\nKính nhắc quý phụ huynh hoàn thành khoản [tên khoản] trước ngày [ngày].\nTrân trọng,\nGVCN [họ tên] · lớp [lớp]'),
  _Mau('Trao đổi khác',
      'Kính gửi quý phụ huynh em [tên học sinh],\nGiáo viên xin trao đổi với gia đình về việc [nội dung cần trao đổi].\nKính mong quý phụ huynh phản hồi hoặc sắp xếp thời gian trao đổi trực tiếp với giáo viên.\nTrân trọng,\nGVCN [họ tên] · lớp [lớp]'),
  _Mau('Nghỉ lễ, đổi lịch',
      'Kính gửi quý phụ huynh,\nHọc sinh được nghỉ [lý do] từ ngày [ngày] đến ngày [ngày], đi học lại ngày [ngày].\nTrân trọng,\nGVCN [họ tên] · lớp [lớp]'),
];

class NhanPhuHuynh extends StatefulWidget {
  const NhanPhuHuynh({super.key});

  @override
  State<NhanPhuHuynh> createState() => _NhanPhuHuynhState();
}

class _NhanPhuHuynhState extends State<NhanPhuHuynh> {
  int _chon = 0;
  final _tin = TextEditingController(text: _dsMau[0].noiDung);
  TextEditingController? _tenHs; // ô tên học sinh (gợi ý tên theo danh sách lớp)
  final _tenGv = TextEditingController();
  final _lop = TextEditingController();
  final _yMuon = TextEditingController();
  bool _dangChoAI = false;
  List<String> _dsTen = [];
  final _oTin = GlobalKey();

  @override
  void initState() {
    super.initState();
    _taiSan();
  }

  /// Tên thầy cô, lớp nhớ từ lần trước; tên học sinh lấy từ các lớp đã tạo ở Nhận xét học sinh.
  Future<void> _taiSan() async {
    final p = await SharedPreferences.getInstance();
    final lop = await docLop();
    if (!mounted) return;
    setState(() {
      _tenGv.text = p.getString('ph_ten_gv') ?? '';
      _lop.text = p.getString('ph_lop') ?? (lop.length == 1 ? lop.first.ten : '');
      _dsTen = {for (final l in lop) for (final h in l.hocSinh) h.ten}.toList()..sort();
    });
  }

  Future<void> _nhoTenLop() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('ph_ten_gv', _tenGv.text.trim());
    await p.setString('ph_lop', _lop.text.trim());
  }

  @override
  void dispose() {
    _tin.dispose();
    _tenGv.dispose();
    _lop.dispose();
    _yMuon.dispose();
    super.dispose();
  }

  void _chonMau(int i) {
    setState(() {
      _chon = i;
      _tin.text = _dsMau[i].noiDung;
    });
  }

  /// Gửi lên AI loại tin và ý thầy cô muốn nói, không gửi tên học sinh.
  Future<void> _nhoAI() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final y = _yMuon.text.trim();
    if (y.isEmpty) {
      _bao('Thầy cô bấm micro nói, hoặc gõ ý chính vào ô, ví dụ: em hay quên làm bài tập về nhà.');
      return;
    }
    setState(() => _dangChoAI = true);
    final kq = await TroLyApi.hoi(
      'Loại tin: ${_dsMau[_chon].ten}. Ý giáo viên muốn nói: $y. '
      'Gọi học sinh là [tên học sinh], ký [họ tên] và lớp [lớp].',
      loai: 'tin_ph',
    );
    if (!mounted) return;
    setState(() => _dangChoAI = false);
    if (kq.traLoi != null) {
      _tin.text = boDauMarkdown(kq.traLoi!);
      _bao('AI đã viết xong tin nhắn vào ô Tin nhắn bên dưới. Thầy cô đọc lại, sửa nếu cần rồi bấm Gửi.');
      // Cuộn xuống ô Tin nhắn để thầy cô thấy ngay tin AI vừa viết
      final o = _oTin.currentContext;
      if (o != null && o.mounted) {
        Scrollable.ensureVisible(o, duration: const Duration(milliseconds: 400), alignment: 0.1);
      }
    } else {
      _bao(kq.loi ?? 'Chưa soạn được, thầy cô thử lại.');
    }
  }

  /// Điền tên học sinh, tên thầy cô, lớp ngay trên máy (tên không gửi cho AI).
  String _tinHoanChinh() {
    var t = _tin.text;
    final ten = (_tenHs?.text ?? '').trim();
    if (ten.isNotEmpty) t = t.replaceAll(RegExp(r'\[(tên|mã) học sinh\]', caseSensitive: false), ten);
    final gv = _tenGv.text.trim();
    if (gv.isNotEmpty) t = t.replaceAll(RegExp(r'\[họ tên\]', caseSensitive: false), gv);
    final lop = _lop.text.trim();
    if (lop.isNotEmpty) t = t.replaceAll(RegExp(r'\[lớp\]', caseSensitive: false), lop);
    _nhoTenLop();
    return t;
  }

  void _bao(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nhắn phụ huynh')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          const CauGiupViec('nhan_ph'),
          const Text('Chọn loại tin', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 0; i < _dsMau.length; i++)
                ChoiceChip(label: Text(_dsMau[i].ten), selected: _chon == i, onSelected: (_) => _chonMau(i)),
            ],
          ),
          const SizedBox(height: 16),
          // Nhờ AI soạn tin: nói rõ công dụng, có nút micro để nói thay vì gõ (thầy cô báo 24/11/2026 chưa rõ
          // nút này để làm gì, chữ ví dụ trong ô tưởng là chữ có sẵn)
          Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F1FE),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFB9CCEF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Nhờ AI soạn tin theo ý thầy cô', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                const SizedBox(height: 4),
                const Text(
                  'Thầy cô chỉ cần nói (bấm micro) hoặc gõ ý chính. AI viết thành tin nhắn lịch sự, đầy đủ gửi phụ huynh, '
                  'điền sẵn vào ô Tin nhắn bên dưới. Tên học sinh không gửi cho AI.',
                  style: TextStyle(fontSize: 12.5, color: MauApp.chuPhu, height: 1.35),
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _yMuon,
                        minLines: 1,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Ý chính muốn báo',
                          hintText: 'Ví dụ: em hay quên làm bài tập về nhà',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    NutNoi(dich: _yMuon),
                  ],
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: _dangChoAI ? null : _nhoAI,
                  icon: _dangChoAI
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.auto_awesome, size: 18),
                  label: Text(_dangChoAI ? 'AI đang viết tin…' : 'Nhờ AI viết thành tin nhắn'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            key: _oTin,
            controller: _tin,
            minLines: 6,
            maxLines: 14,
            decoration: const InputDecoration(
              labelText: 'Tin nhắn (sửa trực tiếp được)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Autocomplete<String>(
            optionsBuilder: (v) {
              final q = v.text.trim().toLowerCase();
              if (q.isEmpty) return const Iterable<String>.empty();
              return _dsTen.where((t) => t.toLowerCase().contains(q)).take(8);
            },
            fieldViewBuilder: (context, controller, focus, onSubmit) {
              _tenHs = controller;
              return TextField(
                controller: controller,
                focusNode: focus,
                decoration: const InputDecoration(
                  labelText: 'Tên học sinh (gõ vài chữ để chọn, không gửi cho AI)',
                ),
              );
            },
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tenGv,
                  decoration: const InputDecoration(labelText: 'Họ tên thầy cô (app nhớ cho lần sau)'),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 90,
                child: TextField(controller: _lop, decoration: const InputDecoration(labelText: 'Lớp')),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'App tự điền tên học sinh, họ tên, lớp vào tin khi chép hoặc gửi. Chỗ ngoặc vuông còn lại thầy cô sửa trước khi gửi.',
            style: TextStyle(fontSize: 12, color: MauApp.chuPhu),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _tinHoanChinh()));
                    _bao('Đã chép tin nhắn.');
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Chép tin'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => guiChu(_tinHoanChinh(), context: context),
                  icon: const Icon(Icons.send),
                  label: const Text('Gửi qua Zalo…'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
