import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Hiện câu trả lời của AI có định dạng markdown đơn giản:
/// tiêu đề (#), chữ đậm (**...**), gạch đầu dòng (- hoặc *), danh sách số.
/// Đường dẫn (https://…, [chữ](https://…)) bấm vào là mở trang nguồn.
class ChuAI extends StatelessWidget {
  final String noiDung;
  final TextStyle style;
  const ChuAI(this.noiDung, {super.key, required this.style});

  static final _link = RegExp(r'\[([^\]]+)\]\((https?://[^\s)]+)\)|https?://[^\s)\]>"]+');

  /// Tách đoạn chữ thành chữ thường và đường dẫn bấm được.
  static List<TextSpan> _lienKet(String chu, TextStyle st) {
    final ra = <TextSpan>[];
    var i = 0;
    for (final k in _link.allMatches(chu)) {
      if (k.start > i) ra.add(TextSpan(text: chu.substring(i, k.start), style: st));
      var url = k.group(2) ?? k.group(0)!;
      url = url.replaceAll(RegExp(r'[.,;:]+$'), '');
      final hien = k.group(1) ?? url;
      ra.add(TextSpan(
        text: hien,
        style: st.copyWith(color: const Color(0xFF1F6FE5), decoration: TextDecoration.underline),
        recognizer: TapGestureRecognizer()..onTap = () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      ));
      i = k.group(1) != null ? k.end : k.start + url.length;
    }
    if (i < chu.length) ra.add(TextSpan(text: chu.substring(i), style: st));
    return ra;
  }

  static List<TextSpan> _dam(String dong, TextStyle st) {
    final ra = <TextSpan>[];
    final m = RegExp(r'\*\*(.+?)\*\*');
    var i = 0;
    for (final k in m.allMatches(dong)) {
      if (k.start > i) ra.addAll(_lienKet(dong.substring(i, k.start), st));
      ra.addAll(_lienKet(k.group(1)!, st.copyWith(fontWeight: FontWeight.w700)));
      i = k.end;
    }
    if (i < dong.length) ra.addAll(_lienKet(dong.substring(i), st));
    return ra;
  }

  @override
  Widget build(BuildContext context) {
    final spans = <TextSpan>[];
    final dongs = noiDung.trim().split('\n');
    for (var n = 0; n < dongs.length; n++) {
      var d = dongs[n].trimRight();
      var st = style;
      final tieuDe = RegExp(r'^\s*(#{1,6})\s+').firstMatch(d);
      if (tieuDe != null) {
        d = d.substring(tieuDe.end);
        st = style.copyWith(fontWeight: FontWeight.w800, fontSize: (style.fontSize ?? 15) + (tieuDe.group(1)!.length <= 2 ? 2 : 1));
      } else {
        final dau = RegExp(r'^(\s*)[-*]\s+').firstMatch(d);
        if (dau != null) d = '${dau.group(1)}•  ${d.substring(dau.end)}';
      }
      if (RegExp(r'^\s*(-{3,}|\*{3,})\s*$').hasMatch(d)) d = '';
      spans.addAll(_dam(d, st));
      if (n < dongs.length - 1) spans.add(TextSpan(text: '\n', style: style));
    }
    return SelectableText.rich(TextSpan(children: spans));
  }
}
