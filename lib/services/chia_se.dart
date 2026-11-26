import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
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

/// Mở xem tệp bằng trình xem của máy (Word, PDF, Excel, ảnh). Không mở được thì đưa bảng gửi để thầy cô chọn app mở.
Future<void> moXemTep(BuildContext context, File f) async {
  try {
    final kq = await OpenFilex.open(f.path);
    if (kq.type == ResultType.done) return;
  } catch (_) {}
  if (!context.mounted) return;
  _baoLoi(context, 'Máy chưa có app mở được loại tệp này. Thầy cô chọn app trong bảng gửi để mở.');
  await guiTep([f.path], context: context);
}

/// Lưu một bản tệp ra nơi thầy cô chọn trong máy (ứng dụng Tệp, thư mục Tải về, Drive…).
Future<void> luuVaoMay(BuildContext context, File f) async {
  final ten = f.uri.pathSegments.last;
  try {
    final duong = await FilePicker.platform.saveFile(dialogTitle: 'Lưu vào máy', fileName: ten, bytes: await f.readAsBytes());
    if (duong == null || !context.mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text('Đã lưu $ten vào máy.')));
  } catch (_) {
    if (!context.mounted) return;
    _baoLoi(context, 'Chưa mở được nơi lưu. Thầy cô bấm Gửi rồi chọn "Lưu vào Tệp".');
  }
}

IconData _bieuTuongTep(String ten) {
  final d = ten.split('.').last.toLowerCase();
  if (d == 'pdf') return Icons.picture_as_pdf_outlined;
  if (d == 'docx' || d == 'doc') return Icons.description_outlined;
  if (d == 'xlsx' || d == 'csv') return Icons.table_chart_outlined;
  if (d == 'jpg' || d == 'jpeg' || d == 'png') return Icons.image_outlined;
  if (d == 'zip') return Icons.folder_zip_outlined;
  return Icons.insert_drive_file_outlined;
}

/// Báo đã lưu tệp ngay tại màn đang làm, với 3 việc: Mở xem, Gửi, Lưu vào máy (quy tắc chung chốt 24/11/2026:
/// tiện ích nào tạo tệp thì thầy cô lấy tệp luôn tại chỗ, mục Tệp của tôi chỉ để xem lại, lấy khi cần).
/// [nutThem]: nút riêng của từng tiện ích (ví dụ In ngay), đặt trên nút Gửi.
Future<void> baoDaLuuTep(BuildContext context, File f, {String tieuDe = 'Đã lưu tệp', List<Widget> nutThem = const []}) =>
    baoDaLuu(context, [f], tieuDe: tieuDe, nutThem: nutThem);

/// Như [baoDaLuuTep] cho nhiều tệp cùng lúc (ví dụ biên bản ra cả Word và PDF): mỗi tệp một dòng có nút
/// Mở xem, Lưu vào máy; nút Gửi gửi tất cả.
Future<void> baoDaLuu(BuildContext context, List<File> ds, {String tieuDe = 'Đã lưu tệp', List<Widget> nutThem = const []}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    // Cao theo nội dung, cuộn được: máy màn nhỏ không bị tràn (thử trên máy giả lập 320x640, 24/11/2026)
    isScrollControlled: true,
    builder: (c) => SafeArea(
      child: SingleChildScrollView(
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
            const SizedBox(height: 4),
            Text(noiLuuTep, style: const TextStyle(fontSize: 12.5, color: Color(0xFF55657A), height: 1.35)),
            const SizedBox(height: 10),
            for (final f in ds)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.fromLTRB(10, 8, 6, 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F6FB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFDCE3EE)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      Icon(_bieuTuongTep(f.uri.pathSegments.last), color: const Color(0xFF1F4E8C)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(f.uri.pathSegments.last,
                            maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ]),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 4,
                      children: [
                        Builder(
                          builder: (b) => TextButton.icon(
                            onPressed: () => moXemTep(b, f),
                            icon: const Icon(Icons.visibility_outlined, size: 18),
                            label: const Text('Mở xem'),
                          ),
                        ),
                        Builder(
                          builder: (b) => TextButton.icon(
                            onPressed: () => luuVaoMay(b, f),
                            icon: const Icon(Icons.save_alt, size: 18),
                            label: const Text('Lưu vào máy'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            ...nutThem,
            Builder(
              builder: (b) => FilledButton.icon(
                onPressed: () => guiTep([for (final f in ds) f.path], context: b),
                icon: const Icon(Icons.ios_share),
                label: Text(ds.length > 1 ? 'Gửi cả ${ds.length} tệp qua Zalo, email…' : 'Gửi qua Zalo, email…'),
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
