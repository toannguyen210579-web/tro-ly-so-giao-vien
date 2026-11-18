import 'package:flutter/material.dart';

import '../data/tien_ich.dart';
import '../main.dart';

/// Dải ngắn ở đầu mỗi tiện ích: tiện ích làm hộ việc gì, không bắt nhập thêm.
class CauGiupViec extends StatelessWidget {
  final String ma;
  final EdgeInsetsGeometry margin;
  const CauGiupViec(this.ma, {super.key, this.margin = const EdgeInsets.only(bottom: 12)});

  @override
  Widget build(BuildContext context) {
    final cau = ma == 'hoi' ? giupGiHoiTroLy : timTheoMa(ma).giupGi;
    return Container(
      margin: margin,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F6EF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBFE6D2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.task_alt, color: MauApp.xanhLa, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(cau, style: const TextStyle(fontSize: 13.5, height: 1.35, fontWeight: FontWeight.w600, color: Color(0xFF0B4F40)))),
        ],
      ),
    );
  }
}
