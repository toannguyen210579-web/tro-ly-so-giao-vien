import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

/// Vùng gốc của bảng chia sẻ (bắt buộc trên iPad, và trên iPhone khi app đóng gói bằng Xcode 26).
///
/// Lỗi thầy cô báo 24/11/2026: bấm In bộ thẻ không thấy gì. Nguyên nhân: thư viện chia sẻ bản 10 báo lỗi
/// "sharePositionOrigin" trên iPhone khi app đóng gói bằng Xcode 26 nếu không có vùng gốc, nên mọi nút
/// gửi, lưu tệp đều im lặng. Luôn truyền một vùng nằm gọn trong màn hình: vùng của nút vừa bấm, không có thì
/// giữa màn hình.
Rect vungGocChiaSe([BuildContext? context]) {
  final v = WidgetsBinding.instance.platformDispatcher.views.first;
  final man = Offset.zero & (v.physicalSize / v.devicePixelRatio);
  final giua = Rect.fromCenter(center: man.center, width: 2, height: 2);
  try {
    final o = context != null && context.mounted ? context.findRenderObject() : null;
    if (o is RenderBox && o.attached && o.hasSize) {
      final r = (o.localToGlobal(Offset.zero) & o.size).intersect(man);
      // Vùng của một nút: dùng làm gốc (trên iPad bảng gửi mọc ra từ nút). Cả màn hình thì để giữa màn hình.
      if (r.width >= 1 && r.height >= 1 && r.width * r.height < man.width * man.height / 4) return r;
    }
  } catch (_) {}
  return giua;
}

/// Gửi, lưu tệp qua bảng chia sẻ của máy (Zalo, email, Lưu vào Tệp, Drive…).
/// Trả về false khi không mở được bảng chia sẻ; có [context] thì báo cho thầy cô.
Future<bool> guiTep(List<String> duong, {BuildContext? context, String? text}) async {
  final goc = vungGocChiaSe(context);
  try {
    await Share.shareXFiles([for (final d in duong) XFile(d)], text: text, sharePositionOrigin: goc);
    return true;
  } catch (_) {
    _baoLoi(context, 'Chưa mở được bảng gửi. Tệp vẫn đã lưu trong mục Tệp của tôi.');
    return false;
  }
}

/// Gửi chữ qua bảng chia sẻ của máy.
Future<bool> guiChu(String chu, {BuildContext? context}) async {
  final goc = vungGocChiaSe(context);
  try {
    await Share.share(chu, sharePositionOrigin: goc);
    return true;
  } catch (_) {
    _baoLoi(context, 'Chưa mở được bảng gửi, thầy cô thử lại.');
    return false;
  }
}

/// Chỗ tệp app lưu nằm, nói cho thầy cô biết sau mỗi lần lưu.
String get noiLuuTep => Platform.isIOS
    ? 'Tệp nằm trong mục Tệp của tôi của app, và trong ứng dụng Tệp của máy: Trên iPhone (iPad) › Trợ lý số GV.'
    : 'Tệp nằm trong mục Tệp của tôi của app (thanh dưới cùng).';

/// Báo đã lưu tệp, kèm nút gửi đi (Zalo, email, Lưu vào Tệp, Drive…). [nutThem]: nút riêng của từng tiện ích
/// (ví dụ In ngay), đặt trên nút Gửi.
Future<void> baoDaLuuTep(BuildContext context, File f, {String tieuDe = 'Đã lưu tệp', List<Widget> nutThem = const []}) {
  final ten = f.uri.pathSegments.last;
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              const Icon(Icons.check_circle, color: Color(0xFF0B8A57)),
              const SizedBox(width: 8),
              Expanded(child: Text(tieuDe, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
            ]),
            const SizedBox(height: 8),
            Text(ten, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(noiLuuTep, style: const TextStyle(fontSize: 12.5, color: Color(0xFF55657A), height: 1.35)),
            const SizedBox(height: 14),
            ...nutThem,
            Builder(
              builder: (b) => FilledButton.icon(
                onPressed: () => guiTep([f.path], context: b),
                icon: const Icon(Icons.ios_share),
                label: const Text('Gửi qua Zalo, email, lưu ra nơi khác'),
              ),
            ),
            const SizedBox(height: 6),
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Xong')),
          ],
        ),
      ),
    ),
  );
}

void _baoLoi(BuildContext? context, String s) {
  if (context == null || !context.mounted) return;
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(s)));
}
