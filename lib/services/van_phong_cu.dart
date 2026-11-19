import 'dart:typed_data';

/// Đọc tệp Word .doc và Excel .xls đời cũ (Office 97–2003) ngay trên máy, không cần mạng.
/// Hai loại tệp này là "tệp ghép" OLE2 (Compound File) chứa các luồng dữ liệu nhị phân.

class LoiTepCu implements Exception {
  final String message;
  const LoiTepCu(this.message);
  @override
  String toString() => message;
}

const _het = 0xFFFFFFFA; // các số >= giá trị này là ký hiệu kết thúc chuỗi, sector trống...

class _Ole {
  final Uint8List d;
  late final ByteData b = ByteData.sublistView(d);
  late final int ss; // cỡ sector
  late final int mss; // cỡ mini sector
  late final int cutoff;
  final fat = <int>[];
  final miniFat = <int>[];
  final ents = <(String, int, int, int)>[]; // tên, loại, sector đầu, cỡ
  final _con = <int>[]; // trái, phải, con của từng mục
  final goc = <int>{}; // các mục nằm ngay dưới gốc (tệp nhúng bên trong có thể trùng tên)
  late final Uint8List mini;

  _Ole(this.d) {
    if (d.length < 512 || d[0] != 0xD0 || d[1] != 0xCF || d[2] != 0x11 || d[3] != 0xE0) {
      throw const LoiTepCu('Tệp không đúng định dạng Office 97–2003.');
    }
    ss = 1 << b.getUint16(30, Endian.little);
    mss = 1 << b.getUint16(32, Endian.little);
    final nFat = b.getUint32(44, Endian.little);
    final dirStart = b.getUint32(48, Endian.little);
    cutoff = b.getUint32(56, Endian.little);
    final miniStart = b.getUint32(60, Endian.little);
    var dif = b.getUint32(68, Endian.little);
    var nDif = b.getUint32(72, Endian.little);

    final fatSec = <int>[for (var i = 0; i < 109; i++) b.getUint32(76 + 4 * i, Endian.little)];
    while (dif < _het && nDif > 0) {
      final o = 512 + dif * ss;
      for (var i = 0; i < ss ~/ 4 - 1; i++) {
        fatSec.add(b.getUint32(o + 4 * i, Endian.little));
      }
      dif = b.getUint32(o + ss - 4, Endian.little);
      nDif--;
    }
    for (final s in fatSec.where((x) => x < _het).take(nFat)) {
      final o = 512 + s * ss;
      for (var i = 0; i < ss ~/ 4 && o + 4 * i + 4 <= d.length; i++) {
        fat.add(b.getUint32(o + 4 * i, Endian.little));
      }
    }
    for (final s in _chuoi(miniStart)) {
      final o = 512 + s * ss;
      for (var i = 0; i < ss ~/ 4 && o + 4 * i + 4 <= d.length; i++) {
        miniFat.add(b.getUint32(o + 4 * i, Endian.little));
      }
    }
    final dir = _doc(dirStart);
    final bd = ByteData.sublistView(dir);
    for (var i = 0; i + 128 <= dir.length; i += 128) {
      final nl = bd.getUint16(i + 64, Endian.little);
      final ten = nl >= 2
          ? String.fromCharCodes([for (var k = 0; k < nl - 2; k += 2) bd.getUint16(i + k, Endian.little)])
          : '';
      ents.add((ten, dir[i + 66], bd.getUint32(i + 116, Endian.little), bd.getUint32(i + 120, Endian.little)));
      _con.addAll([bd.getUint32(i + 68, Endian.little), bd.getUint32(i + 72, Endian.little), bd.getUint32(i + 76, Endian.little)]);
    }
    if (ents.isNotEmpty) {
      final ngan = <int>[_con[2]];
      while (ngan.isNotEmpty) {
        final k = ngan.removeLast();
        if (k >= ents.length || !goc.add(k)) continue;
        ngan
          ..add(_con[3 * k])
          ..add(_con[3 * k + 1]);
      }
    }
    mini = ents.isEmpty ? Uint8List(0) : _doc(ents.first.$3);
  }

  List<int> _chuoi(int s) {
    final ra = <int>[];
    while (s < _het && s < fat.length && ra.length <= fat.length) {
      ra.add(s);
      s = fat[s];
    }
    return ra;
  }

  Uint8List _doc(int s) {
    final b = BytesBuilder(copy: false);
    for (final i in _chuoi(s)) {
      final o = 512 + i * ss;
      if (o >= d.length) break;
      b.add(Uint8List.sublistView(d, o, o + ss > d.length ? d.length : o + ss));
    }
    return b.toBytes();
  }

  Uint8List? luong(String ten) {
    for (final k in goc) {
      final (n, loai, dau, co) = ents[k];
      if (n != ten || loai != 2) continue;
      if (co < cutoff) {
        final b = BytesBuilder(copy: false);
        var c = dau, dem = 0;
        while (c < _het && c < miniFat.length && dem++ <= miniFat.length) {
          final o = c * mss;
          if (o + mss > mini.length) break;
          b.add(Uint8List.sublistView(mini, o, o + mss));
          c = miniFat[c];
        }
        final r = b.toBytes();
        return r.length > co ? Uint8List.sublistView(r, 0, co) : r;
      }
      final r = _doc(dau);
      return r.length > co ? Uint8List.sublistView(r, 0, co) : r;
    }
    return null;
  }
}

// Bảng mã Windows-1252 cho các byte 0x80–0x9F (phần còn lại trùng Latin-1)
const _cp1252 = [
  0x20AC, 0x81, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021, 0x02C6, 0x2030, 0x0160, 0x2039, 0x0152, 0x8D, 0x017D, 0x8F, //
  0x90, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014, 0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, 0x9D, 0x017E, 0x0178,
];
String _giaiMa1252(Uint8List b) => String.fromCharCodes([for (final c in b) (c >= 0x80 && c <= 0x9F) ? _cp1252[c - 0x80] : c]);
String _giaiMa16(Uint8List b) {
  final bd = ByteData.sublistView(b);
  return String.fromCharCodes([for (var i = 0; i + 1 < b.length; i += 2) bd.getUint16(i, Endian.little)]);
}

/// Lấy chữ từ tệp Word .doc (Word 97–2003). Ném [LoiTepCu] khi không đọc được.
String docChuDoc(Uint8List du) {
  try {
    return _docChuDoc(du);
  } on LoiTepCu {
    rethrow;
  } catch (_) {
    throw const LoiTepCu('Tệp Word bị hỏng hoặc không đọc được.');
  }
}

String _docChuDoc(Uint8List du) {
  final ole = _Ole(du);
  final wd = ole.luong('WordDocument');
  if (wd == null || wd.length < 0x200) throw const LoiTepCu('Không thấy nội dung Word trong tệp.');
  final b = ByteData.sublistView(wd);
  if (b.getUint16(0, Endian.little) != 0xA5EC) throw const LoiTepCu('Tệp Word đời quá cũ (trước Word 97), chưa đọc được.');
  final co = b.getUint16(10, Endian.little);
  if (co & 0x0100 != 0) throw const LoiTepCu('Tệp Word có đặt mật khẩu. Thầy cô bỏ mật khẩu rồi thử lại.');
  final bang = ole.luong(co & 0x0200 != 0 ? '1Table' : '0Table');
  if (bang == null) throw const LoiTepCu('Tệp Word bị thiếu phần dữ liệu.');

  // Vị trí bảng mảnh chữ (Clx) trong FibRgFcLcb97, mục thứ 33
  final csw = b.getUint16(32, Endian.little);
  var o = 34 + csw * 2;
  final cslw = b.getUint16(o, Endian.little);
  o += 2 + cslw * 4 + 2;
  final fcClx = b.getUint32(o + 33 * 8, Endian.little);
  final lcbClx = b.getUint32(o + 33 * 8 + 4, Endian.little);
  if (fcClx + lcbClx > bang.length || lcbClx == 0) throw const LoiTepCu('Tệp Word bị hỏng phần mục lục chữ.');
  final clx = Uint8List.sublistView(bang, fcClx, fcClx + lcbClx);
  final cb = ByteData.sublistView(clx);
  var i = 0;
  while (i < clx.length && clx[i] == 1) {
    i += 3 + cb.getUint16(i + 1, Endian.little);
  }
  if (i >= clx.length || clx[i] != 2) throw const LoiTepCu('Tệp Word bị hỏng phần mục lục chữ.');
  final lcb = cb.getUint32(i + 1, Endian.little);
  final p = i + 5;
  final n = (lcb - 4) ~/ 12;
  final ra = StringBuffer();
  for (var k = 0; k < n; k++) {
    final cp0 = cb.getUint32(p + 4 * k, Endian.little);
    final cp1 = cb.getUint32(p + 4 * (k + 1), Endian.little);
    final fc = cb.getUint32(p + 4 * (n + 1) + 8 * k + 2, Endian.little);
    final dai = cp1 - cp0;
    if (fc & 0x40000000 != 0) {
      final f = (fc & 0x3FFFFFFF) ~/ 2;
      if (f + dai <= wd.length) ra.write(_giaiMa1252(Uint8List.sublistView(wd, f, f + dai)));
    } else {
      if (fc + 2 * dai <= wd.length) ra.write(_giaiMa16(Uint8List.sublistView(wd, fc, fc + 2 * dai)));
    }
  }
  // Bỏ mã trường (giữa 0x13 và 0x14), giữ kết quả hiển thị
  final goc = ra.toString();
  final bo = StringBuffer();
  final tang = <bool>[]; // true = đang ở phần mã lệnh
  for (final c in goc.codeUnits) {
    if (c == 0x13) {
      tang.add(true);
    } else if (c == 0x14) {
      if (tang.isNotEmpty) tang[tang.length - 1] = false;
    } else if (c == 0x15) {
      if (tang.isNotEmpty) tang.removeLast();
    } else if (!tang.contains(true)) {
      bo.writeCharCode(c);
    }
  }
  final s = bo
      .toString()
      .replaceAll('\r', '\n')
      .replaceAll('\u0007', '\t')
      .replaceAll('\u000B', '\n')
      .replaceAll('\u000C', '\n')
      .split('')
      .where((c) => c.codeUnitAt(0) >= 0x20 || c == '\n' || c == '\t')
      .join();
  return s.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
}

double _rk(int v) {
  double x;
  if (v & 2 != 0) {
    var nguyen = v >> 2;
    if (v & 0x80000000 != 0) nguyen -= 1 << 30;
    x = nguyen.toDouble();
  } else {
    final bd = ByteData(8)..setUint32(0, 0, Endian.little)..setUint32(4, v & 0xFFFFFFFC, Endian.little);
    x = bd.getFloat64(0, Endian.little);
  }
  return v & 1 != 0 ? x / 100 : x;
}

String _so(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

/// Đọc trang tính đầu tiên của tệp Excel .xls (Excel 97–2003) thành bảng chữ. Ném [LoiTepCu] khi không đọc được.
List<List<String>> docBangXls(Uint8List du) {
  try {
    return _docBangXls(du);
  } on LoiTepCu {
    rethrow;
  } catch (_) {
    throw const LoiTepCu('Tệp Excel bị hỏng hoặc không đọc được.');
  }
}

List<List<String>> _docBangXls(Uint8List du) {
  final ole = _Ole(du);
  final wb = ole.luong('Workbook') ?? ole.luong('Book');
  if (wb == null) throw const LoiTepCu('Không thấy nội dung Excel trong tệp.');
  final bd = ByteData.sublistView(wb);
  // Tách các bản ghi BIFF
  final recs = <(int, Uint8List)>[];
  var i = 0;
  while (i + 4 <= wb.length) {
    final loai = bd.getUint16(i, Endian.little);
    final dai = bd.getUint16(i + 2, Endian.little);
    final cuoi = i + 4 + dai > wb.length ? wb.length : i + 4 + dai;
    recs.add((loai, Uint8List.sublistView(wb, i + 4, cuoi)));
    i += 4 + dai;
  }
  if (recs.any((r) => r.$1 == 0x002F)) throw const LoiTepCu('Tệp Excel có đặt mật khẩu. Thầy cô bỏ mật khẩu rồi thử lại.');

  final sst = <String>[];
  final o = <int, Map<int, String>>{};
  void dat(int r, int c, String v) => (o[r] ??= {})[c] = v;
  var soBof = 0;

  for (var k = 0; k < recs.length; k++) {
    final (loai, b) = recs[k];
    final rb = ByteData.sublistView(b);
    if (loai == 0x0809) {
      soBof++;
      if (soBof > 2) break; // chỉ đọc trang tính đầu
      continue;
    }
    if (loai == 0x000A && soBof >= 2) break;
    if (loai == 0x00FC) {
      // Bảng chuỗi dùng chung, có thể nối tiếp qua các bản ghi CONTINUE (0x003C)
      final phan = <Uint8List>[b];
      var j = k + 1;
      while (j < recs.length && recs[j].$1 == 0x003C) {
        phan.add(recs[j].$2);
        j++;
      }
      var pi = 0, po = 8;
      int bytes1() {
        while (pi < phan.length && po >= phan[pi].length) {
          pi++;
          po = 0;
        }
        if (pi >= phan.length) throw const LoiTepCu('Bảng chuỗi Excel bị hỏng.');
        return phan[pi][po++];
      }

      int so(int n) {
        var v = 0;
        for (var q = 0; q < n; q++) {
          v |= bytes1() << (8 * q);
        }
        return v;
      }

      final dem = rb.getUint32(4, Endian.little);
      try {
        for (var q = 0; q < dem; q++) {
          final cch = so(2);
          final co = bytes1();
          final rt = co & 8 != 0 ? so(2) : 0;
          final ext = co & 4 != 0 ? so(4) : 0;
          var rong = co & 1 != 0;
          final ma = <int>[];
          for (var t = 0; t < cch; t++) {
            if (po >= phan[pi].length) {
              pi++;
              po = 0;
              if (pi >= phan.length) break;
              rong = phan[pi][po++] & 1 != 0; // đầu bản ghi CONTINUE có cờ độ rộng ký tự
            }
            ma.add(rong ? so(2) : bytes1());
          }
          for (var t = 0; t < rt * 4 + ext; t++) {
            bytes1();
          }
          sst.add(String.fromCharCodes(ma));
        }
      } on LoiTepCu {
        // dừng ở chuỗi cuối đọc được
      }
      k = j - 1;
      continue;
    }
    if (b.length < 6) continue;
    final r = rb.getUint16(0, Endian.little);
    final c = rb.getUint16(2, Endian.little);
    switch (loai) {
      case 0x00FD: // LABELSST
        final id = rb.getUint32(6, Endian.little);
        dat(r, c, id < sst.length ? sst[id] : '');
      case 0x0204: // LABEL
        final cch = rb.getUint16(6, Endian.little);
        final rong = b.length > 8 && b[8] & 1 != 0;
        dat(r, c, rong ? _giaiMa16(Uint8List.sublistView(b, 9, 9 + 2 * cch > b.length ? b.length : 9 + 2 * cch))
            : _giaiMa1252(Uint8List.sublistView(b, 9, 9 + cch > b.length ? b.length : 9 + cch)));
      case 0x0203: // NUMBER
        if (b.length >= 14) dat(r, c, _so(rb.getFloat64(6, Endian.little)));
      case 0x027E: // RK
        if (b.length >= 10) dat(r, c, _so(_rk(rb.getUint32(6, Endian.little))));
      case 0x00BD: // MULRK
        final n = (b.length - 6) ~/ 6;
        for (var q = 0; q < n; q++) {
          dat(r, c + q, _so(_rk(rb.getUint32(4 + 6 * q + 2, Endian.little))));
        }
    }
  }
  final dong = o.keys.toList()..sort();
  return [
    for (final r in dong)
      [for (var c = 0; c <= (o[r]!.keys.reduce((a, b) => a > b ? a : b)); c++) (o[r]![c] ?? '').trim()],
  ];
}
