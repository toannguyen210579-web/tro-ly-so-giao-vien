import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'luu_tru.dart';

/// Một việc có hạn trong Lịch công tác.
class ViecHan {
  String id;
  String ten;
  DateTime han;

  /// Nhắc trước bao nhiêu phút (0 = đúng giờ).
  int nhacTruoc;
  String ghiChu;
  bool xong;

  ViecHan({required this.id, required this.ten, required this.han, this.nhacTruoc = 1440, this.ghiChu = '', this.xong = false});

  Map<String, dynamic> toJson() =>
      {'id': id, 'ten': ten, 'han': han.toIso8601String(), 'nhac': nhacTruoc, 'gc': ghiChu, 'xong': xong};

  factory ViecHan.fromJson(Map<String, dynamic> j) => ViecHan(
        id: j['id'] as String,
        ten: j['ten'] as String? ?? '',
        han: DateTime.tryParse(j['han'] as String? ?? '') ?? DateTime.now(),
        nhacTruoc: j['nhac'] as int? ?? 1440,
        ghiChu: j['gc'] as String? ?? '',
        xong: j['xong'] as bool? ?? false,
      );

  int get maThongBao => id.hashCode & 0x7fffffff;
  DateTime get lucNhac => han.subtract(Duration(minutes: nhacTruoc));
}

const _khoa = 'lich_nhac_han';

Future<List<ViecHan>> docViec() async {
  final ds = (await LuuTru.docDanhSach(_khoa)).map(ViecHan.fromJson).toList()..sort((a, b) => a.han.compareTo(b.han));
  return ds;
}

Future<void> ghiViec(List<ViecHan> ds) => LuuTru.ghiDanhSach(_khoa, ds.map((e) => e.toJson()).toList());

/// Việc chưa xong gần nhất (để hiện ở trang chủ).
Future<ViecHan?> viecSapDenHan() async {
  final ds = (await docViec()).where((v) => !v.xong).toList();
  return ds.isEmpty ? null : ds.first;
}

/// "còn 3 ngày", "hôm nay", "quá hạn 2 ngày"
String conBaoLau(DateTime han, [DateTime? bayGio]) {
  final n = bayGio ?? DateTime.now();
  final a = DateTime(n.year, n.month, n.day);
  final b = DateTime(han.year, han.month, han.day);
  final d = b.difference(a).inDays;
  if (d == 0) return 'hôm nay';
  if (d == 1) return 'ngày mai';
  if (d > 0) return 'còn $d ngày';
  return 'quá hạn ${-d} ngày';
}

/// Thông báo nhắc hạn trên điện thoại (chạy cả khi app đóng).
class NhacHan {
  static final _p = FlutterLocalNotificationsPlugin();
  static bool _xongKhoiTao = false;

  static Future<void> khoiTao() async {
    if (_xongKhoiTao) return;
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));
    await _p.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ));
    _xongKhoiTao = true;
  }

  static Future<void> xinQuyen() async {
    await khoiTao();
    await _p.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
    await _p
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  static Future<void> datNhac(ViecHan v) async {
    await khoiTao();
    await _p.cancel(v.maThongBao);
    if (v.xong || v.lucNhac.isBefore(DateTime.now())) return;
    await _p.zonedSchedule(
      v.maThongBao,
      'Nhắc hạn: ${v.ten}',
      'Hạn ${_gio(v.han)}${v.ghiChu.isEmpty ? '' : ' · ${v.ghiChu}'}',
      tz.TZDateTime.from(v.lucNhac, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails('nhac_han', 'Nhắc hạn',
            channelDescription: 'Nhắc việc sắp đến hạn trong Lịch công tác', importance: Importance.high, priority: Priority.high),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> huy(ViecHan v) async {
    await khoiTao();
    await _p.cancel(v.maThongBao);
  }

  static String _gio(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} ngày ${d.day}/${d.month}/${d.year}';
}
