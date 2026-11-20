import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tro_ly_so_giao_vien/screens/chu_ai.dart';

void main() {
  testWidgets('Đường dẫn nguồn trong câu trả lời bấm được', (t) async {
    await t.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: ChuAI('Giá vàng hôm nay 150 triệu.\nNguồn:\nhttps://vnexpress.net/gia-vang.\n[Báo Tuổi Trẻ](https://tuoitre.vn/a)', style: TextStyle(fontSize: 15)),
      ),
    ));
    final o = t.widget<SelectableText>(find.byType(SelectableText));
    final spans = <TextSpan>[];
    o.textSpan!.visitChildren((s) {
      if (s is TextSpan && s.recognizer is TapGestureRecognizer) spans.add(s);
      return true;
    });
    expect(spans.map((s) => s.text), ['https://vnexpress.net/gia-vang', 'Báo Tuổi Trẻ']);
  });
}
