import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tro_ly_so_giao_vien/data/tin_kenh.dart';
import 'package:tro_ly_so_giao_vien/screens/tin_kenh.dart';

void main() {
  test('Đọc tin từ báo (có nguồn, đường dẫn bài gốc) và clip của kênh', () {
    final bao = TinKenh.fromJson({
      'id': 'a', 'ngay': '2026-11-21', 'tit': 'Tít', 'tom_tat': 'Tóm tắt', 'anh_bia': '',
      'nguon': 'Báo Chính phủ', 'link': 'https://baochinhphu.vn/bai',
    });
    expect(bao.laTinBao, true);
    expect(bao.link, 'https://baochinhphu.vn/bai');
    final clip = TinKenh.fromJson({'id': 'b', 'ngay': '2026-11-21', 'tit': 'Clip', 'tom_tat': '', 'anh_bia': 'asset:assets/tin/x.jpg'});
    expect(clip.laTinBao, false);
  });

  testWidgets('Thẻ tin báo hiện tên nguồn và nút Đọc bài gốc, không có nút Facebook', (t) async {
    final bao = TinKenh(
      id: 'a', ngay: DateTime(2026, 11, 21), tit: 'Bộ GD&ĐT công bố lịch thi', tomTat: 'Tóm tắt ngắn', anhBia: '',
      nguon: 'Báo Chính phủ', link: 'https://baochinhphu.vn/bai',
    );
    await t.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: TheTin(tin: bao, thich: false, boThich: () {})))));
    expect(find.text('Báo Chính phủ'), findsOneWidget);
    expect(find.text('Đọc bài gốc'), findsOneWidget);
    expect(find.text('Xem trên Facebook'), findsNothing);
  });
}
