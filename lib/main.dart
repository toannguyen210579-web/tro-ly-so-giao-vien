import 'package:flutter/material.dart';

import 'screens/trang_chu.dart';

void main() {
  runApp(const TroLyApp());
}

/// Màu chủ đạo của app, lấy theo biểu tượng bản 5.
class MauApp {
  static const xanhDam = Color(0xFF1F4E8C);
  static const xanhTroi = Color(0xFF1F6FE5);
  static const xanhLa = Color(0xFF0B6553);
  static const nen = Color(0xFFF3F5F8);
  static const chu = Color(0xFF14233A);
  static const chuPhu = Color(0xFF55657A);
}

class TroLyApp extends StatelessWidget {
  const TroLyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trợ lý số GV',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: MauApp.xanhTroi),
        scaffoldBackgroundColor: MauApp.nen,
        appBarTheme: const AppBarTheme(
          backgroundColor: MauApp.nen,
          foregroundColor: MauApp.chu,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: MauApp.chu,
          ),
        ),
      ),
      home: const TrangChu(),
    );
  }
}
