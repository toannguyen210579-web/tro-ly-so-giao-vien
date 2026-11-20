import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

// Lưu ảnh chụp màn hình vào thư mục anh_chay_thu/ để xem lại
Future<void> main() => integrationDriver(
      onScreenshot: (ten, byte, [args]) async {
        final f = File('anh_chay_thu/$ten.png');
        f.parent.createSync(recursive: true);
        f.writeAsBytesSync(byte);
        return true;
      },
    );
