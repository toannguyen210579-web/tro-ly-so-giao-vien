import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tro_ly_so_giao_vien/data/tien_ich.dart';

// Hỏi Trợ lý phải biết mọi tiện ích của app để chỉ thầy cô mở đúng chỗ (26/11/2026: trước đó Trợ lý trả lời chung
// chung khi hỏi app có gì). Danh sách nằm trong lời dặn GIOI_THIEU_APP ở server/worker.js: thêm tiện ích mới thì phép
// thử này báo nếu quên ghi vào đó.
void main() {
  test('Lời dặn Hỏi Trợ lý trên máy chủ có tên mọi tiện ích', () {
    final may = File('server/worker.js').readAsStringSync();
    final dau = may.indexOf('const GIOI_THIEU_APP');
    expect(dau, greaterThan(0));
    final gioiThieu = may.substring(dau, may.indexOf('const SYSTEM', dau));
    final thieu = [for (final t in dsTienIch) if (!gioiThieu.contains(t.ten)) t.ten];
    expect(thieu, isEmpty, reason: 'Thêm các tiện ích này vào GIOI_THIEU_APP trong server/worker.js');
  });
}
