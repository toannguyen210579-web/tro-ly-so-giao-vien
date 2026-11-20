import 'package:flutter/material.dart';

import '../data/lich.dart';
import '../main.dart';
import '../services/tep_pdf.dart';
import 'cau_giup_viec.dart';

const _mucNhac = <(int, String)>[
  (0, 'Đúng giờ hạn'),
  (60, 'Trước 1 giờ'),
  (1440, 'Trước 1 ngày'),
  (4320, 'Trước 3 ngày'),
  (10080, 'Trước 1 tuần'),
];

/// Gợi ý việc hay có hạn trong nhà trường.
const _goiY = [
  'Nộp kế hoạch dạy học',
  'Nộp sổ điểm, nhập điểm',
  'Họp tổ chuyên môn',
  'Nộp hồ sơ thi đua',
  'Nộp minh chứng đánh giá chuẩn',
  'Báo cáo tổng kết học kỳ',
];

class LichNhacHan extends StatefulWidget {
  /// Mở thẳng hộp thêm việc với tên, ngày điền sẵn (ví dụ nhắc nâng bậc lương).
  final String? tenMoi;
  final DateTime? hanMoi;
  const LichNhacHan({super.key, this.tenMoi, this.hanMoi});

  @override
  State<LichNhacHan> createState() => _LichNhacHanState();
}

class _LichNhacHanState extends State<LichNhacHan> {
  List<ViecHan>? _ds;
  bool _hienXong = false;

  @override
  void initState() {
    super.initState();
    _tai().then((_) {
      if (widget.tenMoi != null && mounted) _sua(null, ten: widget.tenMoi, han: widget.hanMoi);
    });
  }

  Future<void> _tai() async {
    final ds = await docViec();
    if (mounted) setState(() => _ds = ds);
  }

  Future<void> _luu() async {
    _ds!.sort((a, b) => a.han.compareTo(b.han));
    await ghiViec(_ds!);
    if (mounted) setState(() {});
  }

  Future<void> _sua(ViecHan? goc, {String? ten, DateTime? han}) async {
    final kq = await showModalBottomSheet<ViecHan>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _HopViec(goc: goc, ten: ten, han: han),
    );
    if (kq == null) return;
    final i = _ds!.indexWhere((e) => e.id == kq.id);
    if (i >= 0) {
      _ds![i] = kq;
    } else {
      _ds!.add(kq);
    }
    await _luu();
    try {
      await NhacHan.xinQuyen();
      await NhacHan.datNhac(kq);
    } catch (_) {
      _bao('Đã lưu việc, nhưng chưa đặt được thông báo nhắc trên máy này.');
    }
  }

  Future<void> _danhDau(ViecHan v, bool xong) async {
    v.xong = xong;
    await _luu();
    try {
      xong ? await NhacHan.huy(v) : await NhacHan.datNhac(v);
    } catch (_) {}
  }

  Future<void> _xoa(ViecHan v) async {
    _ds!.remove(v);
    await _luu();
    try {
      await NhacHan.huy(v);
    } catch (_) {}
  }

  void _bao(String s) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  @override
  Widget build(BuildContext context) {
    final ds = _ds;
    final hien = ds == null ? <ViecHan>[] : ds.where((v) => _hienXong || !v.xong).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Lịch, nhắc hạn')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: ds == null ? null : () => _sua(null),
        icon: const Icon(Icons.add),
        label: const Text('Thêm việc'),
      ),
      body: ds == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
              children: [
                const CauGiupViec('lich'),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _hienXong,
                  onChanged: (v) => setState(() => _hienXong = v),
                  title: Text('Hiện cả việc đã xong (${ds.where((v) => v.xong).length})'),
                ),
                if (hien.isEmpty)
                  const Padding(padding: EdgeInsets.only(top: 32), child: Center(child: Text('Chưa có việc nào sắp đến hạn.'))),
                for (final v in hien)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      onTap: () => _sua(v),
                      leading: Checkbox(value: v.xong, onChanged: (x) => _danhDau(v, x ?? false)),
                      title: Text(v.ten,
                          style: TextStyle(
                              fontWeight: FontWeight.w700, decoration: v.xong ? TextDecoration.lineThrough : null)),
                      subtitle: Text('${hai(v.han.hour)}:${hai(v.han.minute)} · ${ngayVN(v.han)} · ${conBaoLau(v.han)}'),
                      trailing: IconButton(tooltip: 'Xóa', icon: const Icon(Icons.delete_outline), onPressed: () => _xoa(v)),
                      tileColor: !v.xong && v.han.isBefore(DateTime.now()) ? const Color(0xFFFDECEC) : null,
                    ),
                  ),
                const SizedBox(height: 8),
                const Text(
                  'Điện thoại sẽ báo trước theo mức thầy cô chọn, kể cả khi đã đóng app. Lần đầu, thầy cô cho app quyền gửi thông báo.',
                  style: TextStyle(fontSize: 12, color: MauApp.chuPhu),
                ),
              ],
            ),
    );
  }
}

class _HopViec extends StatefulWidget {
  final ViecHan? goc;
  final String? ten;
  final DateTime? han;
  const _HopViec({this.goc, this.ten, this.han});

  @override
  State<_HopViec> createState() => _HopViecState();
}

class _HopViecState extends State<_HopViec> {
  late final _ten = TextEditingController(text: widget.goc?.ten ?? widget.ten ?? '');
  late final _ghiChu = TextEditingController(text: widget.goc?.ghiChu ?? '');
  late DateTime _han = widget.goc?.han ?? widget.han ?? DateTime.now().add(const Duration(days: 1)).copyWith(hour: 16, minute: 0);
  late int _nhac = widget.goc?.nhacTruoc ?? 1440;

  @override
  void dispose() {
    _ten.dispose();
    _ghiChu.dispose();
    super.dispose();
  }

  Future<void> _chonHan() async {
    final d = await showDatePicker(context: context, initialDate: _han, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (d == null || !mounted) return;
    final g = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_han));
    setState(() => _han = DateTime(d.year, d.month, d.day, g?.hour ?? _han.hour, g?.minute ?? _han.minute));
  }

  @override
  Widget build(BuildContext context) {
    // Cuộn được: màn hình nhỏ hoặc bàn phím mở thì nút Lưu không bị che
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.goc == null ? 'Thêm việc có hạn' : 'Sửa việc', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          TextField(controller: _ten, autofocus: widget.goc == null && widget.ten == null, decoration: const InputDecoration(labelText: 'Việc cần làm', border: OutlineInputBorder())),
          if (widget.goc == null) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final g in _goiY) ActionChip(label: Text(g, style: const TextStyle(fontSize: 12.5)), onPressed: () => _ten.text = g),
            ]),
          ],
          const SizedBox(height: 12),
          InkWell(
            onTap: _chonHan,
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Hạn', border: OutlineInputBorder()),
              child: Text('${hai(_han.hour)}:${hai(_han.minute)}, ngày ${ngayVN(_han)}'),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            isExpanded: true,
            value: _mucNhac.any((m) => m.$1 == _nhac) ? _nhac : 1440,
            decoration: const InputDecoration(labelText: 'Nhắc', border: OutlineInputBorder()),
            items: [for (final m in _mucNhac) DropdownMenuItem(value: m.$1, child: Text(m.$2))],
            onChanged: (v) => setState(() => _nhac = v ?? 1440),
          ),
          const SizedBox(height: 12),
          TextField(controller: _ghiChu, decoration: const InputDecoration(labelText: 'Ghi chú (không bắt buộc)', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                if (_ten.text.trim().isEmpty) return;
                Navigator.of(context).pop(ViecHan(
                  id: widget.goc?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
                  ten: _ten.text.trim(),
                  han: _han,
                  nhacTruoc: _nhac,
                  ghiChu: _ghiChu.text.trim(),
                  xong: widget.goc?.xong ?? false,
                ));
              },
              icon: const Icon(Icons.check),
              label: const Text('Lưu'),
            ),
          ),
        ],
      ),
    );
  }
}
