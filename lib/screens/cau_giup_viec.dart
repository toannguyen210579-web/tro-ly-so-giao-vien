import 'package:flutter/material.dart';

import '../data/huong_dan.dart';
import '../data/tien_ich.dart';
import '../main.dart';

/// Dải ngắn ở đầu mỗi tiện ích: tiện ích làm hộ việc gì, kèm nút "Hướng dẫn sử dụng".
class CauGiupViec extends StatelessWidget {
  final String ma;
  final EdgeInsetsGeometry margin;
  const CauGiupViec(this.ma, {super.key, this.margin = const EdgeInsets.only(bottom: 12)});

  @override
  Widget build(BuildContext context) {
    final cau = ma == 'hoi' ? giupGiHoiTroLy : timTheoMa(ma).giupGi;
    final coHuongDan = huongDan.containsKey(ma);
    return Container(
      margin: margin,
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F6EF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF9FD8BC)),
        boxShadow: const [BoxShadow(color: Color(0x330B6553), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.task_alt, color: MauApp.xanhLa, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(cau, style: const TextStyle(fontSize: 13.5, height: 1.35, fontWeight: FontWeight.w700, color: Color(0xFF0B4F40)))),
              ],
            ),
          ),
          if (coHuongDan)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: const Key('nut_huong_dan'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF0B4F40),
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ManHuongDan(ma))),
                icon: const Icon(Icons.menu_book_outlined, size: 18),
                label: const Text('Hướng dẫn sử dụng'),
              ),
            )
          else
            const SizedBox(height: 6),
        ],
      ),
    );
  }
}

/// Trang hướng dẫn sử dụng đầy đủ của một tiện ích.
class ManHuongDan extends StatelessWidget {
  final String ma;
  const ManHuongDan(this.ma, {super.key});

  @override
  Widget build(BuildContext context) {
    final ten = ma == 'hoi' ? 'Hỏi Trợ lý' : timTheoMa(ma).ten;
    final cau = ma == 'hoi' ? giupGiHoiTroLy : timTheoMa(ma).giupGi;
    final ds = huongDan[ma] ?? const <MucHuongDan>[];
    return Scaffold(
      appBar: AppBar(title: Text('Hướng dẫn: $ten')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Text(cau, style: const TextStyle(fontSize: 15, height: 1.4, fontWeight: FontWeight.w600, color: Color(0xFF0B4F40))),
          const SizedBox(height: 8),
          for (final m in ds) ...[
            const SizedBox(height: 14),
            Text(m.tieuDe, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            for (var i = 0; i < m.buoc.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      margin: const EdgeInsets.only(right: 10, top: 1),
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(color: MauApp.xanhLa, shape: BoxShape.circle),
                      child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800)),
                    ),
                    Expanded(child: Text(m.buoc[i], style: const TextStyle(fontSize: 15, height: 1.45))),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 12),
          FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Đã hiểu, quay lại')),
        ],
      ),
    );
  }
}
