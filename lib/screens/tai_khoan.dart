import 'package:flutter/material.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/tien_ich.dart';
import '../main.dart';
import '../services/tro_ly_api.dart';
import 'bieu_tuong.dart';
import 'dieu_huong.dart';

const phienBanApp = '0.2.0';
const ngayChinhSach = '18/11/2026';

/// Nội dung Chính sách quyền riêng tư. Bản này cũng chép ra tệp CHINH_SACH_QUYEN_RIENG_TU.md
/// để đăng lên mạng (Google Play, App Store bắt buộc có đường dẫn công khai).
const chinhSachQuyenRiengTu = <(String, String)>[
  (
    'Tóm tắt',
    'Trợ lý số Giáo viên không yêu cầu đăng ký tài khoản. Phần lớn tiện ích chạy ngay trên điện thoại, '
        'dữ liệu thầy cô nhập (danh sách học sinh, điểm, biên bản, minh chứng, ảnh) chỉ lưu trong máy. '
        'Chỉ khi thầy cô bấm các nút có biểu tượng AI, nội dung liên quan mới được gửi đi để xử lý.'
  ),
  (
    'Dữ liệu lưu trên máy',
    'Lớp học, điểm, lời nhận xét, bài chấm trắc nghiệm, biên bản họp, sổ minh chứng, tệp PDF và ảnh '
        'được lưu trong vùng riêng của app trên điện thoại. App không tự gửi các dữ liệu này đi đâu. '
        'Khi gỡ app, các dữ liệu này bị xóa theo.'
  ),
  (
    'Quyền máy ảnh, ảnh, micro',
    'Máy ảnh dùng để quét giấy tờ, chụp ảnh thẻ, chụp minh chứng. Thư viện ảnh dùng để chọn ảnh có sẵn. '
        'Micro dùng để chuyển lời nói thành chữ. App chỉ dùng các quyền này khi thầy cô bấm vào tiện ích tương ứng.'
  ),
  (
    'Xử lý ngay trên máy bằng thành phần của Google, Apple',
    'Quét giấy tờ và tách nền ảnh thẻ dùng thành phần có sẵn của Google (Android) hoặc Apple (iPhone), '
        'chạy ngay trên máy. Đọc văn bản thành tiếng dùng bộ đọc của điện thoại. '
        'Chuyển lời nói thành chữ dùng bộ nhận giọng của điện thoại; trên nhiều máy, bộ này gửi âm thanh '
        'tới máy chủ của Google hoặc Apple để nhận dạng, theo chính sách riêng của hãng.'
  ),
  (
    'Khi dùng tính năng AI',
    'Các nút Hỏi Trợ lý, Nhờ AI viết nhận xét, Nhờ AI soạn tin, Nhờ AI sắp xếp biên bản, Giải, soạn đáp án, '
        'Ra đề tương tự gửi nội dung thầy cô nhập (và ảnh đề, nếu thầy cô chụp) tới máy chủ trung gian của app (đặt trên Cloudflare), rồi chuyển tới dịch vụ AI Claude của Anthropic '
        'để soạn câu trả lời. Tên học sinh được thay bằng mã (HS01, HS02…) trước khi gửi. '
        'Với biên bản họp, app hỏi lại và chỉ gửi khi thầy cô đồng ý. '
        'Máy chủ trung gian không lưu nội dung câu hỏi, chỉ đếm số lượt dùng trong ngày.'
  ),
  (
    'Mã máy',
    'Để giới hạn số lượt AI miễn phí mỗi ngày, app tạo một mã ngẫu nhiên lưu trên máy. '
        'Mã này không gắn với tên, số điện thoại hay danh bạ. Số lượt đếm theo mã được tự xóa sau 2 ngày.'
  ),
  (
    'Báo cáo nội dung AI',
    'Khi thầy cô bấm Báo cáo một câu trả lời của AI, câu hỏi, câu trả lời và lý do được lưu trên máy chủ '
        'trung gian tối đa 90 ngày để kiểm tra và cải thiện, sau đó tự xóa.'
  ),
  (
    'Chia sẻ tệp',
    'Khi thầy cô bấm Gửi, Chia sẻ, tệp hoặc tin nhắn được chuyển sang ứng dụng thầy cô chọn (Zalo, email…). '
        'Việc xử lý sau đó theo chính sách của ứng dụng đó.'
  ),
  (
    'Trẻ em',
    'App dành cho giáo viên, không dành cho học sinh tự sử dụng.'
  ),
  (
    'Thay đổi chính sách',
    'Khi app thêm tính năng mới có thu thập hay gửi dữ liệu (ví dụ quảng cáo), chính sách này sẽ được cập nhật '
        'và ghi ngày hiệu lực mới.'
  ),
  (
    'Liên hệ',
    'Mọi thắc mắc về quyền riêng tư, thầy cô gửi về: [email liên hệ của nhà phát triển].'
  ),
];

/// Hồ sơ thầy cô lưu trên máy, dùng để điền sẵn vào biên bản, tin nhắn.
class HoSo {
  static const _khoa = ['hs_ten', 'hs_truong', 'hs_mon'];
  static Future<List<String>> doc() async {
    final p = await SharedPreferences.getInstance();
    return [for (final k in _khoa) p.getString(k) ?? ''];
  }

  static Future<void> ghi(List<String> v) async {
    final p = await SharedPreferences.getInstance();
    for (var i = 0; i < _khoa.length; i++) {
      await p.setString(_khoa[i], v[i].trim());
    }
  }
}

/// Lượt AI miễn phí mỗi ngày (khớp với máy chủ trong server/worker.js).
const luotMienPhi = {'hoi': 5, 'giai_de': 5};

class TaiKhoan extends StatefulWidget {
  const TaiKhoan({super.key});

  @override
  State<TaiKhoan> createState() => _TaiKhoanState();
}

class _TaiKhoanState extends State<TaiKhoan> {
  List<String> _hoSo = ['', '', ''];
  int _luotHoi = luotMienPhi['hoi']!;
  int _luotGiai = luotMienPhi['giai_de']!;

  @override
  void initState() {
    super.initState();
    _tai();
  }

  Future<void> _tai() async {
    final h = await HoSo.doc();
    final a = await TroLyApi.luotConLai('hoi', luotMienPhi['hoi']!);
    final b = await TroLyApi.luotConLai('giai_de', luotMienPhi['giai_de']!);
    if (mounted) {
      setState(() {
        _hoSo = h;
        _luotHoi = a;
        _luotGiai = b;
      });
    }
  }

  Future<void> _suaHoSo() async {
    final c = [for (final v in _hoSo) TextEditingController(text: v)];
    const nhan = ['Họ và tên', 'Trường', 'Môn dạy'];
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hồ sơ thầy cô'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [for (var i = 0; i < 3; i++) TextField(controller: c[i], decoration: InputDecoration(labelText: nhan[i]))],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Thôi')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Lưu')),
        ],
      ),
    );
    if (ok != true) return;
    await HoSo.ghi([for (final x in c) x.text]);
    await _tai();
  }

  void _sapCo(String viec) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$viec sẽ có ở bản sau.')));
  }

  @override
  Widget build(BuildContext context) {
    final ten = _hoSo[0].isEmpty ? 'Thầy cô chưa ghi tên' : _hoSo[0];
    final phu = [_hoSo[2], _hoSo[1]].where((s) => s.isNotEmpty).join(' · ');
    return Scaffold(
      appBar: AppBar(title: const Text('Tài khoản')),
      body: RefreshIndicator(
        onRefresh: _tai,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            // Hồ sơ
            InkWell(
              onTap: _suaHoSo,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 34,
                      backgroundColor: const Color(0xFFDCE6F5),
                      child: Text(
                        _hoSo[0].isEmpty ? '?' : _hoSo[0].trim().split(' ').last.characters.first.toUpperCase(),
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: MauApp.xanhDam),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ten, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                          Text(phu.isEmpty ? 'Bấm để ghi tên, trường, môn dạy' : phu, style: const TextStyle(color: MauApp.chuPhu)),
                          const SizedBox(height: 6),
                          FilledButton(
                            onPressed: () => _sapCo('Gói Pro'),
                            style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                            child: const Text('Nâng cấp Pro'),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Lượt hôm nay
            Row(
              children: [
                Expanded(child: _oSo('$_luotHoi/${luotMienPhi['hoi']}', 'Lượt hỏi Trợ lý', const Color(0xFFFFF4D6))),
                const SizedBox(width: 8),
                Expanded(child: _oSo('$_luotGiai/${luotMienPhi['giai_de']}', 'Lượt giải đề', const Color(0xFFE3ECF8))),
              ],
            ),
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('Lượt miễn phí được làm mới lúc 0 giờ mỗi ngày.', style: TextStyle(fontSize: 12, color: MauApp.chuPhu)),
            ),
            const SizedBox(height: 12),
            // Xem quảng cáo nhận lượt
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFDDE3EA)),
              ),
              child: Row(
                children: [
                  const Expanded(child: Text('Nhận thêm lượt AI khi xem quảng cáo', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
                  FilledButton(
                    onPressed: () => _sapCo('Xem quảng cáo nhận lượt'),
                    style: FilledButton.styleFrom(backgroundColor: MauApp.xanhLa),
                    child: const Text('Làm ngay'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // So sánh gói
            _theSoSanh(),
            const SizedBox(height: 20),
            const Text('Tiện ích', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 0.8,
              children: [
                for (final t in dsTienIch)
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => moTienIch(context, t),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        BieuTuongNoi(ma: t.ma, icon: t.bieuTuong, size: 46, mo: !t.coTrongBanDau),
                        const SizedBox(height: 7),
                        Text(t.ten, textAlign: TextAlign.center, maxLines: 2, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined, color: MauApp.xanhDam),
                    title: const Text('Chính sách quyền riêng tư'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ManChinhSach())),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.article_outlined, color: MauApp.xanhDam),
                    title: const Text('Giấy phép phần mềm'),
                    subtitle: const Text('Các thư viện mã nguồn mở app sử dụng'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => showLicensePage(
                      context: context,
                      applicationName: 'Trợ lý số Giáo viên',
                      applicationVersion: phienBanApp,
                      applicationLegalese: 'Bớt sổ sách, thêm giờ cho học trò.',
                    ),
                  ),
                  const Divider(height: 1),
                  const ListTile(
                    leading: Icon(Icons.info_outline, color: MauApp.xanhDam),
                    title: Text('Phiên bản'),
                    trailing: Text(phienBanApp),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _oSo(String so, String nhan, Color nen) => Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(color: nen, borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(so, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            Text(nhan, style: const TextStyle(color: MauApp.chuPhu)),
          ],
        ),
      );

  Widget _theSoSanh() {
    const dong = [
      ('Hỏi Trợ lý', '5', '50'),
      ('Giải đề, soạn đáp án', '5', '50'),
      ('Ra đề tương tự', '5', '50'),
      ('AI viết nhận xét', '30', '300'),
      ('AI soạn tin phụ huynh', '20', '200'),
      ('AI sắp xếp biên bản', '10', '100'),
      ('Quảng cáo', 'Có', 'Không'),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDDE3EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Trợ lý số GV Pro', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const Text('Gấp 10 lần lượt AI miễn phí, không quảng cáo', style: TextStyle(color: MauApp.chuPhu)),
          const SizedBox(height: 12),
          Table(
            columnWidths: const {0: FlexColumnWidth(2.2), 1: FlexColumnWidth(1.2), 2: FlexColumnWidth(1.2)},
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              const TableRow(children: [
                Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('Lượt mỗi ngày', style: TextStyle(fontWeight: FontWeight.w700))),
                Text('Miễn phí', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700)),
                Text('Pro', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, color: MauApp.xanhTroi)),
              ]),
              for (final (a, b, c) in dong)
                TableRow(children: [
                  Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Text(a)),
                  Text(b, textAlign: TextAlign.center, style: const TextStyle(color: MauApp.chuPhu)),
                  Text(c, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, color: MauApp.xanhDam)),
                ]),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => _sapCo('Gói Pro'),
              style: FilledButton.styleFrom(backgroundColor: MauApp.xanhLa, padding: const EdgeInsets.symmetric(vertical: 14)),
              child: const Text('Nâng cấp ngay', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}

class ManChinhSach extends StatelessWidget {
  const ManChinhSach({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chính sách quyền riêng tư')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          const Text('Có hiệu lực từ ngày $ngayChinhSach', style: TextStyle(fontStyle: FontStyle.italic, color: MauApp.chuPhu)),
          for (final (tieuDe, noiDung) in chinhSachQuyenRiengTu) ...[
            const SizedBox(height: 16),
            Text(tieuDe, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(noiDung, style: const TextStyle(height: 1.45)),
          ],
        ],
      ),
    );
  }
}
