import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../main.dart';
import '../services/tro_ly_api.dart';
import 'cau_giup_viec.dart';

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
  final _tenHs = TextEditingController();
  final _yMuon = TextEditingController();
  bool _dangChoAI = false;

  @override
  void dispose() {
    _tin.dispose();
    _tenHs.dispose();
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
    final y = _yMuon.text.trim();
    if (y.isEmpty) {
      _bao('Thầy cô gõ vài chữ về việc muốn báo, ví dụ "em hay quên làm bài tập về nhà".');
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
      _bao('AI đã soạn xong. Thầy cô đọc lại và sửa trước khi gửi.');
    } else {
      _bao(kq.loi ?? 'Chưa soạn được, thầy cô thử lại.');
    }
  }

  /// Điền tên học sinh ngay trên máy, sau khi AI soạn xong.
  String _tinHoanChinh() {
    final ten = _tenHs.text.trim();
    return ten.isEmpty ? _tin.text : _tin.text.replaceAll('[tên học sinh]', ten);
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
          TextField(
            controller: _yMuon,
            decoration: const InputDecoration(
              labelText: 'Ý thầy cô muốn nói (để AI soạn)',
              hintText: 'Ví dụ: em hay quên làm bài tập về nhà tuần này',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: _dangChoAI ? null : _nhoAI,
              icon: _dangChoAI
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.auto_awesome, size: 18),
              label: const Text('Nhờ AI soạn tin'),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _tin,
            minLines: 6,
            maxLines: 14,
            decoration: const InputDecoration(
              labelText: 'Tin nhắn (sửa trực tiếp được)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tenHs,
            decoration: const InputDecoration(
              labelText: 'Tên học sinh (chỉ điền trên máy, không gửi cho AI)',
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Các chỗ trong ngoặc vuông thầy cô sửa lại trước khi gửi.',
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
                  onPressed: () => Share.share(_tinHoanChinh()),
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
