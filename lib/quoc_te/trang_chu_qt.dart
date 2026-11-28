import 'package:flutter/material.dart';

import '../main.dart';
import '../screens/anh_the.dart';
import '../screens/gio_the.dart';
import '../screens/o_chu.dart';
import '../screens/quet_pdf.dart';
import 'cong_cu_qt.dart';
import 'ngon_ngu.dart';
import 'quoc_te.dart';

/// Trang chủ bản quốc tế: chỉ gồm các tiện ích giáo viên nước nào cũng dùng.
class TrangChuQT extends StatefulWidget {
  const TrangChuQT({super.key});

  @override
  State<TrangChuQT> createState() => _TrangChuQTState();
}

class _TrangChuQTState extends State<TrangChuQT> {
  List<String> _lop = [];

  @override
  void initState() {
    super.initState();
    _taiLop();
  }

  Future<void> _taiLop() async {
    final d = await LopQT.doc();
    if (mounted) setState(() => _lop = d);
  }

  Future<void> _mo(Widget man) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => man));
    _taiLop();
  }

  void _chonTieng() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final e in tenTieng.entries)
              ListTile(
                key: ValueKey('tieng_${e.key}'),
                title: Text(e.value),
                trailing: e.key == tieng.value ? const Icon(Icons.check) : null,
                onTap: () {
                  datTieng(e.key);
                  Navigator.of(c).pop();
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final o = <_O>[
      _O('timer', Icons.timer_outlined, const Color(0xFF1F6FE5), () => const DongHoQT()),
      _O('picker', Icons.casino_outlined, const Color(0xFFEF6A23), () => const GoiTenQT()),
      _O('groups', Icons.groups_2_outlined, const Color(0xFF0B8A6A), () => const ChiaNhomQT()),
      _O('score', Icons.emoji_events_outlined, const Color(0xFF8A4FD3), () => const BangDiemQT()),
      _O('attendance', Icons.fact_check_outlined, const Color(0xFFD42539), () => const DiemDanhQT()),
      _O('scan', Icons.document_scanner_outlined, const Color(0xFF00838F), () => const QuetPdf()),
      _O('idPhoto', Icons.badge_outlined, const Color(0xFF5E6AD2), () => const AnhThe()),
      _O('answerCards', Icons.style_outlined, const Color(0xFF0B8A6A), () => const GioThe()),
      _O('crossword', Icons.grid_on_outlined, const Color(0xFFE5570B), () => const OChuMan()),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text(tenAppQuocTe),
        actions: [
          TextButton.icon(
            key: const ValueKey('nut_tieng'),
            onPressed: _chonTieng,
            icon: const Icon(Icons.language),
            label: Text(tieng.value.toUpperCase()),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(chu('title'), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, khung) {
            // Số cột theo bề ngang thật của khung: điện thoại 2 cột, máy tính bảng 3 cột
            final cot = khung.maxWidth >= 560 ? 3 : 2;
            return GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            // Ô cao cố định (giãn theo cỡ chữ của máy) để tên dài hai dòng không bị tràn
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cot,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              mainAxisExtent: 104 + MediaQuery.textScalerOf(context).scale(48),
            ),
            children: [
              for (final e in o)
                Card(
                  margin: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    key: ValueKey('o_${e.khoa}'),
                    onTap: () => _mo(e.man()),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: e.mau.withValues(alpha: 0.14),
                            child: Icon(e.icon, color: e.mau, size: 30),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            chu(e.khoa),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, color: MauApp.chu),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
          }),
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              key: const ValueKey('o_lop'),
              leading: const Icon(Icons.list_alt_outlined),
              title: Text(chu('classList')),
              subtitle: Text('${_lop.length}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _mo(const DanhSachLopQT()),
            ),
          ),
        ],
      ),
    );
  }
}

class _O {
  final String khoa;
  final IconData icon;
  final Color mau;
  final Widget Function() man;
  const _O(this.khoa, this.icon, this.mau, this.man);
}
