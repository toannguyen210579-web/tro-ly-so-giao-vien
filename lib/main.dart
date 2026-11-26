import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/trang_chu.dart';
import 'services/giong_may.dart';

void main() {
  // Phông DejaVu đóng gói trong app để in PDF có dấu: ghi giấy phép vào trang Giấy phép phần mềm.
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(['DejaVu Serif (phông chữ PDF)'], await rootBundle.loadString('assets/fonts/LICENSE_DejaVu.txt'));
    yield LicenseEntryWithLineBreaks(
        ['Be Vietnam Pro (phông chữ PDF bài trình chiếu)'], await rootBundle.loadString('assets/fonts/LICENSE_BeVietnamPro_OFL.txt'));
  });
  runApp(const TroLyApp());
  // Máy thiếu giọng tiếng Việt: tải sẵn giọng cài sẵn (ưu tiên wifi) để Đọc to dùng được ngay lần đầu.
  unawaited(GiongMay.taiSanNeuCan());
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

const _bong = [Shadow(color: Color(0x332C6EE8), blurRadius: 3, offset: Offset(0, 1.5))];

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
        // Kiểu "nổi" cho cả app (chốt 21/11/2026): chữ cố định đậm, có bóng nhẹ; nút, ô, thẻ có bóng; biểu tượng có màu.
        // Chữ người dùng gõ (bodyLarge) giữ bình thường.
        appBarTheme: const AppBarTheme(
          backgroundColor: MauApp.nen,
          foregroundColor: MauApp.xanhDam,
          elevation: 0,
          centerTitle: false,
          iconTheme: IconThemeData(color: MauApp.xanhTroi),
          // Tiêu đề không đổ bóng: bóng làm chữ nhòe trên iPhone (thầy cô báo 26/11/2026)
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: MauApp.xanhDam,
          ),
        ),
        textTheme: const TextTheme(
          titleLarge: TextStyle(fontWeight: FontWeight.w900, color: MauApp.xanhDam, shadows: _bong),
          titleMedium: TextStyle(fontWeight: FontWeight.w800, color: MauApp.chu),
          titleSmall: TextStyle(fontWeight: FontWeight.w800, color: MauApp.chu),
          labelLarge: TextStyle(fontWeight: FontWeight.w800),
          labelMedium: TextStyle(fontWeight: FontWeight.w700),
          labelSmall: TextStyle(fontWeight: FontWeight.w700),
        ),
        iconTheme: const IconThemeData(color: MauApp.xanhTroi),
        cardTheme: const CardThemeData(
          color: Colors.white,
          elevation: 4,
          shadowColor: Color(0x552C6EE8),
          surfaceTintColor: Colors.transparent,
        ),
        listTileTheme: const ListTileThemeData(
          iconColor: MauApp.xanhTroi,
          titleTextStyle: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: MauApp.chu),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            elevation: 4,
            shadowColor: const Color(0x882C6EE8),
            textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: MauApp.xanhDam,
            elevation: 3,
            shadowColor: const Color(0x552C6EE8),
            side: const BorderSide(color: Color(0xFF8FB2F2), width: 1.4),
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(elevation: 4, textStyle: const TextStyle(fontWeight: FontWeight.w800)),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(textStyle: const TextStyle(fontWeight: FontWeight.w800)),
        ),
        chipTheme: const ChipThemeData(
          elevation: 2,
          pressElevation: 4,
          shadowColor: Color(0x552C6EE8),
          backgroundColor: Colors.white,
          labelStyle: TextStyle(fontWeight: FontWeight.w700, color: MauApp.chu),
          side: BorderSide(color: Color(0xFFB9CCEF)),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          elevation: 6,
          backgroundColor: MauApp.xanhTroi,
          foregroundColor: Colors.white,
          extendedTextStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          labelStyle: TextStyle(fontWeight: FontWeight.w700),
          floatingLabelStyle: TextStyle(fontWeight: FontWeight.w800, color: MauApp.xanhTroi),
        ),
        tabBarTheme: const TabBarThemeData(
          labelStyle: TextStyle(fontWeight: FontWeight.w900),
          unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w700),
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Colors.white,
          elevation: 8,
          shadowColor: Color(0x442C6EE8),
          labelTextStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: MauApp.chu)),
        ),
      ),
      // iPad, máy Mac, máy tính bảng Android (chốt 24/11/2026): màn rộng thì giữ nội dung một cột
      // rộng tối đa 800, đặt giữa, để ô nhập, nút, danh sách không bị kéo giãn hết bề ngang.
      // Chạm ra ngoài ô chữ thì hạ bàn phím: bàn phím iPhone không có nút ẩn, che mất nút bên dưới
      // (lỗi Đọc to thầy cô báo 24/11/2026). Nút, ô chữ nằm trong vẫn nhận chạm như thường.
      builder: (context, child) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: KhungManRong(child: child!),
      ),
      home: const TrangChu(),
    );
  }
}

/// Giới hạn bề ngang nội dung trên màn rộng (iPad, Mac, máy tính bảng). Điện thoại giữ nguyên.
class KhungManRong extends StatelessWidget {
  const KhungManRong({super.key, required this.child});
  final Widget child;
  static const rongToiDa = 800.0;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    if (mq.size.width <= rongToiDa + 80) return child;
    return ColoredBox(
      color: const Color(0xFFE3E8F0),
      child: Center(
        child: SizedBox(
          width: rongToiDa,
          child: MediaQuery(
            data: mq.copyWith(size: Size(rongToiDa, mq.size.height)),
            child: ClipRect(child: child),
          ),
        ),
      ),
    );
  }
}
