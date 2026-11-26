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

  testWidgets('Clip chưa có đường dẫn Facebook: không hiện nút phát, nút Xem trên Facebook; có đường dẫn thì hiện', (t) async {
    Future<void> ve(String? link) => t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: TheTin(
                    tin: TinKenh(
                        id: 'c', ngay: DateTime(2026, 11, 17), tit: 'Clip', tomTat: 'Tóm tắt', anhBia: 'asset:assets/tin/17-11_thuong-tet-giao-vien-nghi-dinh-161.jpg', linkFacebook: link),
                    thich: false,
                    boThich: () {})))));
    await ve(null);
    expect(find.text('Xem trên Facebook'), findsNothing);
    expect(find.byIcon(Icons.play_arrow), findsNothing);
    await ve('https://www.facebook.com/reel/2538632786617837');
    expect(find.text('Xem trên Facebook'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
  });
}
