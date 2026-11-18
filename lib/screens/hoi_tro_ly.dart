import 'package:flutter/material.dart';

import '../main.dart';
import '../services/tro_ly_api.dart';

class _TinNhan {
  final bool laNguoiDung;
  final String noiDung;
  final String? cauHoi; // câu hỏi đi kèm, để báo cáo
  const _TinNhan(this.laNguoiDung, this.noiDung, {this.cauHoi});
}

/// Hỏi Trợ lý: chỉ trả lời việc của nghề giáo, giới hạn số câu mỗi ngày.
class HoiTroLy extends StatefulWidget {
  final String? cauHoiDau;
  const HoiTroLy({super.key, this.cauHoiDau});

  @override
  State<HoiTroLy> createState() => _HoiTroLyState();
}

class _HoiTroLyState extends State<HoiTroLy> {
  final _o = TextEditingController();
  final _ds = <_TinNhan>[];
  bool _dangCho = false;
  int? _conLai;

  @override
  void initState() {
    super.initState();
    final c = widget.cauHoiDau;
    if (c != null && c.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _gui(c));
    }
  }

  @override
  void dispose() {
    _o.dispose();
    super.dispose();
  }

  Future<void> _gui([String? cau]) async {
    final c = (cau ?? _o.text).trim();
    if (c.isEmpty || _dangCho) return;
    _o.clear();
    setState(() {
      _ds.add(_TinNhan(true, c));
      _dangCho = true;
    });
    final kq = await TroLyApi.hoi(c);
    if (!mounted) return;
    setState(() {
      _dangCho = false;
      _conLai = kq.conLai ?? _conLai;
      _ds.add(_TinNhan(false, kq.traLoi ?? kq.loi ?? 'Có lỗi, thầy cô thử lại.', cauHoi: c));
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
    final ok = await TroLyApi.baoCao(cauHoi: t.cauHoi ?? '', traLoi: t.noiDung, lyDo: lyDo);
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
        actions: [
          if (_conLai != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Chip(label: Text('Còn $_conLai câu hôm nay')),
            ),
        ],
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Trợ lý trả lời về chế độ, tiền lương, Thông tư, viết văn bản và phương pháp dạy học.',
              style: TextStyle(color: MauApp.chuPhu),
            ),
          ),
          Expanded(
            child: ListView.builder(
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
                        SelectableText(
                          t.noiDung,
                          style: TextStyle(fontSize: 15, height: 1.45, color: t.laNguoiDung ? Colors.white : MauApp.chu),
                        ),
                        if (!t.laNguoiDung) ...[
                          const SizedBox(height: 4),
                          const Text(
                            'AI có thể nhầm. Thầy cô đối chiếu văn bản gốc trước khi dùng.',
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
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _o,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _gui(),
                      decoration: InputDecoration(
                        hintText: 'Thầy cô hỏi gì về nghề giáo?',
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
            ),
          ),
        ],
      ),
    );
  }
}
