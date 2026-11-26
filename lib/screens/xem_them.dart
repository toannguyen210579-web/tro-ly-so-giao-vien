import 'package:flutter/material.dart';

import '../data/tien_ich.dart';
import '../main.dart';
import 'bieu_tuong.dart';
import 'dieu_huong.dart';

/// Danh sách đủ các tiện ích, chia hai nhóm Hành chính và Chuyên môn.
class XemThem extends StatelessWidget {
  const XemThem({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tất cả tiện ích')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
        children: [
          _nhom(context, 'Hành chính', MauApp.xanhDam, NhomTienIch.hanhChinh),
          _nhom(context, 'Chuyên môn', MauApp.xanhLa, NhomTienIch.chuyenMon),
        ],
      ),
    );
  }

  Widget _nhom(BuildContext context, String ten, Color mau, NhomTienIch nhom) {
    final ds = dsTienIch.where((t) => t.nhom == nhom).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 0, 8),
          child: Text(ten, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: mau)),
        ),
        // Ô căn trên, chiều cao theo cỡ chữ của máy: biểu tượng thẳng hàng, chữ to không bị cắt;
        // không còn dòng chữ chạy giải thích (thầy cô chốt 24/11/2026)
        GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisExtent: chieuCaoOTienIch(context),
            mainAxisSpacing: 4,
          ),
          children: [
            for (final t in ds)
              OTienIch(ma: t.ma, icon: t.bieuTuong, ten: t.ten, mo: !t.coTrongBanDau, bam: () => moTienIch(context, t)),
          ],
        ),
      ],
    );
  }
}
