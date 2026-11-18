import 'package:flutter/material.dart';

import '../data/tien_ich.dart';
import '../main.dart';
import 'bieu_tuong.dart';
import 'chu_chay.dart';
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
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 0.72,
          children: [
            for (final t in ds)
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => moTienIch(context, t),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    BieuTuongNoi(ma: t.ma, icon: t.bieuTuong, size: 50, mo: !t.coTrongBanDau),
                    const SizedBox(height: 8),
                    Text(t.ten, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChuChay(t.moTa, style: const TextStyle(fontSize: 10.5, color: MauApp.chuPhu)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}
