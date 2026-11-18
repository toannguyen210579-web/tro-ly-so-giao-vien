import 'package:flutter/material.dart';

import '../data/tien_ich.dart';
import '../main.dart';

/// Màn tạm cho tiện ích chưa làm xong.
class SapCo extends StatelessWidget {
  final TienIch tienIch;
  const SapCo({super.key, required this.tienIch});

  @override
  Widget build(BuildContext context) {
    final ghiChu = tienIch.coTrongBanDau
        ? 'Tiện ích này đang được hoàn thiện cho bản đầu.'
        : 'Tiện ích này sẽ có ở bản sau.';
    return Scaffold(
      appBar: AppBar(title: Text(tienIch.ten)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(tienIch.bieuTuong, size: 56, color: MauApp.xanhTroi),
              const SizedBox(height: 16),
              Text(ghiChu, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }
}
