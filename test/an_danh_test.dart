import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tro_ly_so_giao_vien/services/an_danh.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  test('Đổi mã học sinh trong câu trả lời về tên thật', () {
    final ma = {'Nguyễn Văn An': 'HS01', 'Y Đức Niê': 'HS02', 'Lê Thị Mười': 'HS10'};
    expect(
      traTen('HS01 và HS02 cần nhắc nhở; HS10 học tốt. HS011 không đổi.', ma),
      'Nguyễn Văn An và Y Đức Niê cần nhắc nhở; Lê Thị Mười học tốt. HS011 không đổi.',
    );
  });

  test('Câu có số điện thoại, email được che và đánh dấu riêng tư', () async {
    final kq = await lamSachCauHoi('Gọi 0912 345 678 hoặc gửi an@gmail.com');
    expect(kq.noiDung, 'Gọi [số điện thoại] hoặc gửi [email]');
    expect(kq.riengTu, isTrue);
  });
}
