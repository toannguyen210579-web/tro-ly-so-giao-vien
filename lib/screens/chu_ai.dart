import 'package:flutter/material.dart';

/// Hiện câu trả lời của AI có định dạng markdown đơn giản:
/// tiêu đề (#), chữ đậm (**...**), gạch đầu dòng (- hoặc *), danh sách số.
class ChuAI extends StatelessWidget {
  final String noiDung;
  final TextStyle style;
  const ChuAI(this.noiDung, {super.key, required this.style});

  static List<TextSpan> _dam(String dong, TextStyle st) {
    final ra = <TextSpan>[];
    final m = RegExp(r'\*\*(.+?)\*\*');
    var i = 0;
    for (final k in m.allMatches(dong)) {
      if (k.start > i) ra.add(TextSpan(text: dong.substring(i, k.start), style: st));
      ra.add(TextSpan(text: k.group(1), style: st.copyWith(fontWeight: FontWeight.w700)));
      i = k.end;
    }
    if (i < dong.length) ra.add(TextSpan(text: dong.substring(i), style: st));
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
