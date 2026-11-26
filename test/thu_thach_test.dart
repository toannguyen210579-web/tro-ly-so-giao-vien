import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tro_ly_so_giao_vien/data/thu_thach.dart';
import 'package:tro_ly_so_giao_vien/screens/thu_thach.dart';
import 'package:tro_ly_so_giao_vien/services/tro_ly_api.dart';

void main() {
  test('Đọc kiểu mỗi dòng "Câu hỏi | Đáp án"', () {
    final c = tachCauHoi('Thủ đô Việt Nam? | Hà Nội\n2 + 3 = ? | 5\n\n1. Tác giả Truyện Kiều | Nguyễn Du');
    expect(c, const [CauThuThach('Thủ đô Việt Nam?', 'Hà Nội'), CauThuThach('2 + 3 = ?', '5'), CauThuThach('Tác giả Truyện Kiều', 'Nguyễn Du')]);
  });

  test('Đọc kiểu "Câu 1: ... / Đáp án: ...", có câu trắc nghiệm, chép từ Word', () {
    final c = tachCauHoi('''
Câu 1 (0,5 điểm): Hành tinh gần Mặt Trời nhất
là hành tinh nào?
Đáp án: Sao Thủy
Câu 2. Con vật nào là động vật có vú?
A. Cá chép
B. Cá voi
C. Cá mập
D. Cá ngựa
ĐÁP ÁN: B
câu 3: Đỉnh núi cao nhất Việt Nam?
=> Phan Xi Păng
''');
    expect(c.length, 3);
    expect(c[0], const CauThuThach('Hành tinh gần Mặt Trời nhất là hành tinh nào?', 'Sao Thủy'));
    expect(c[1].hoi, 'Con vật nào là động vật có vú?\nA. Cá chép\nB. Cá voi\nC. Cá mập\nD. Cá ngựa');
    expect(c[1].dapAnDayDu, 'B. Cá voi');
    const cungDong = 'Phân số nào bằng 1/2: A. 2/3, B. 3/6, C. 4/9, D. 5/8';
    expect(const CauThuThach(cungDong, 'B').dapAnDayDu, 'B. 3/6');
    expect(const CauThuThach(cungDong, 'd').dapAnDayDu, 'D. 5/8');
    expect(const CauThuThach('Câu hỏi không có lựa chọn', 'C').dapAnDayDu, 'C');
    expect(c[2], const CauThuThach('Đỉnh núi cao nhất Việt Nam?', 'Phan Xi Păng'));
  });

  test('Đọc kiểu hai dòng không ghi "Đáp án", câu thiếu đáp án vẫn giữ', () {
    final c = tachCauHoi('Thủ đô Việt Nam là gì?\nHà Nội\n\nCâu chưa có đáp án\n\nNước sôi ở bao nhiêu độ C?\n100 độ C');
    expect(c, const [
      CauThuThach('Thủ đô Việt Nam là gì?', 'Hà Nội'),
      CauThuThach('Câu chưa có đáp án', ''),
      CauThuThach('Nước sôi ở bao nhiêu độ C?', '100 độ C'),
    ]);
  });

  test('Đọc câu trả lời AI có lời dẫn, markdown, nguồn', () {
    const ai = 'Dưới đây là 2 câu hỏi về phân số:\n\n**Câu 1:** Phân số 1/2 bằng phân số nào: 2/4 hay 2/3?\n**Đáp án:** 2/4\n\n'
        '**Câu 2:** Rút gọn 6/8 được phân số nào?\nĐáp án: 3/4\n\nNguồn: https://vi.wikipedia.org/wiki/Phân_số';
    final c = tachCauHoi(catTuCau1(boDauMarkdown(ai)));
    expect(c, const [
      CauThuThach('Phân số 1/2 bằng phân số nào: 2/4 hay 2/3?', '2/4'),
      CauThuThach('Rút gọn 6/8 được phân số nào?', '3/4'),
    ]);
    expect(cauNhoAISoan('Phân số', 'lớp 6', 10), allOf(contains('10 câu'), contains('Phân số'), contains('lớp 6'), contains('Đáp án:')));
  });

  test('Chuyển bộ câu hỏi về chữ rồi đọc lại ra đúng như cũ', () {
    final mau = boThuThachMau();
    expect(tachCauHoi(vanBanBo(mau.cau)), mau.cau);
    final lai = BoThuThach.fromJson(mau.toJson());
    expect(lai.ten, mau.ten);
    expect(lai.cau, mau.cau);
    expect(mau.cau.every((c) => c.dapAn.isNotEmpty), isTrue);
  });

  test('Loại học sinh trả lời sai, cả lớp sai thì không loại, cứu trợ', () {
    final v = VanThuThach(['An', 'Bình', 'Chi', 'Dũng']);
    expect(v.loai(['An']), isTrue);
    expect(v.conLai, ['Bình', 'Chi', 'Dũng']);
    expect(v.loai(['Bình', 'Chi', 'Dũng']), isFalse);
    expect(v.conLai.length, 3);
    expect(v.loai(['An', 'Bình', 'Lạ']), isTrue, reason: 'em đã loại, tên lạ bị bỏ qua');
    expect(v.conLai, ['Chi', 'Dũng']);
    v.cuuTro();
    expect(v.conLai.length, 4);
    expect(
      ketQuaThuThach(tenBo: 'Ôn tập', tenLop: '7A', soCau: 8, conLai: ['Chi', 'Dũng'], siSo: 4),
      'Thử thách cả lớp · Lớp 7A · Ôn tập\nQua 8 câu hỏi, 2/4 em trụ lại đến cuối: Chi, Dũng.',
    );
  });

  testWidgets('Chơi: đếm giờ, xem đáp án, loại em sai, sang câu sau', (t) async {
    SharedPreferences.setMockInitialValues({});
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    await t.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final bo = boThuThachMau();
    await t.pumpWidget(MaterialApp(home: ChoiThuThach(bo: bo, ten: const ['An', 'Bình', 'Chi'], tenLop: '7A', giay: 3)));
    await t.pump();
    expect(find.text(bo.cau[0].hoi), findsOneWidget);
    expect(find.text('Còn 3/3 em'), findsOneWidget);

    await t.tap(find.text('Bắt đầu tính giờ (3 giây)'));
    await t.pump();
    expect(find.text('3'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await t.pump(const Duration(seconds: 1));
    }
    expect(find.text('Hết giờ! Các em giơ bảng.'), findsOneWidget);

    await t.tap(find.text('Xem đáp án'));
    await t.pump();
    expect(find.text('Đáp án: Hà Nội'), findsOneWidget);
    await t.tap(find.text('An'));
    await t.pump();
    await t.tap(find.text('Câu tiếp theo'));
    await t.pump();
    expect(find.text('Câu 2/${bo.cau.length}'), findsOneWidget);
    expect(find.text('Còn 2/3 em'), findsOneWidget);

    // Câu 2: dừng giờ sớm, hai em còn lại đều sai thì không loại ai
    await t.tap(find.text('Bắt đầu tính giờ (3 giây)'));
    await t.pump();
    await t.tap(find.text('Dừng giờ, xem đáp án'));
    await t.pump();
    await t.tap(find.text('Bình'));
    await t.tap(find.text('Chi'));
    await t.pump();
    await t.tap(find.text('Câu tiếp theo'));
    await t.pumpAndSettle();
    expect(find.text('Còn 2/3 em'), findsOneWidget);
    expect(find.textContaining('không loại ai'), findsOneWidget);

    // Cứu trợ cho em An vào lại
    await t.tap(find.text('Cứu trợ'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, 'Cứu trợ'));
    await t.pumpAndSettle();
    expect(find.text('Còn 3/3 em'), findsOneWidget);
  });

  testWidgets('Thẻ Thử thách có bộ mẫu, soạn bộ mới bằng cách dán chữ', (t) async {
    SharedPreferences.setMockInitialValues({});
    await t.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: ThuThachTab(ten: ['An'], tenLop: '6A'))));
    await t.pumpAndSettle();
    expect(find.text('Mẫu: Kiến thức chung'), findsOneWidget);
    expect(find.text('8 câu · chạm để sửa'), findsOneWidget);

    await t.tap(find.text('Bộ câu hỏi mới'));
    await t.pumpAndSettle();
    await t.enterText(find.widgetWithText(TextField, 'Tên bộ câu hỏi'), 'Ôn tập Bài 1');
    await t.enterText(find.widgetWithText(TextField, 'Câu hỏi và đáp án'), 'Thủ đô Việt Nam? | Hà Nội\n2 + 2 = ? | 4');
    await t.pump();
    expect(find.text('Đọc được 2 câu.'), findsOneWidget);
    await t.tap(find.text('Lưu bộ câu hỏi'));
    await t.pumpAndSettle();
    expect(find.text('Ôn tập Bài 1'), findsOneWidget);
    expect(find.text('2 câu · chạm để sửa'), findsOneWidget);

    final p = await SharedPreferences.getInstance();
    expect(p.getString('thu_thach'), contains('Ôn tập Bài 1'));
    expect(p.getString('thu_thach'), isNot(contains('Mẫu: Kiến thức chung')));
  });
}
