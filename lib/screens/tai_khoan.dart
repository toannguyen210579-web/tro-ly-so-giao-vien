import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/tien_ich.dart';
import '../main.dart';
import '../services/tro_ly_api.dart';
import 'bieu_tuong.dart';
import 'dieu_huong.dart';

const phienBanApp = '0.3.0';
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
// Hỏi Trợ lý không hiện số câu (đã chốt 19/11), nên chỉ hiện các tiện ích có giới hạn rõ.
const luotMienPhi = {'giaide': 10, 'nhanxet': 100, 'tinnhan': 100};

class TaiKhoan extends StatefulWidget {
  const TaiKhoan({super.key});

  @override
  State<TaiKhoan> createState() => _TaiKhoanState();
}

class _TaiKhoanState extends State<TaiKhoan> {
  List<String> _hoSo = ['', '', ''];
  int _luotGiaiDe = luotMienPhi['giaide']!;
  int _luotNhanXet = luotMienPhi['nhanxet']!;
  String _maMay = '';

  @override
  void initState() {
    super.initState();
    _tai();
  }

  Future<void> _tai() async {
    final h = await HoSo.doc();
    final ma = await TroLyApi.maMay();
    await TroLyApi.layLuot();
    final a = await TroLyApi.luotConLai('giai_de', luotMienPhi['giaide']!);
    final b = await TroLyApi.luotConLai('nhanxet', luotMienPhi['nhanxet']!);
    if (mounted) {
      setState(() {
        _hoSo = h;
        _luotGiaiDe = a;
        _luotNhanXet = b;
        _maMay = ma;
      });
    }
  }

  Future<void> _moTrang(String url) async {
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Chưa mở được trang. Địa chỉ: $url')));
    }
  }

  Future<void> _xoaDuLieu() async {
    final dongY = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Xóa dữ liệu trên máy chủ?'),
        content: const Text(
          'Máy chủ sẽ xóa số lượt đã dùng và các báo cáo thầy cô đã gửi từ máy này. '
          'Dữ liệu lưu trong điện thoại (lớp học, biên bản, tệp) không bị ảnh hưởng. '
          'Việc xóa không hoàn tác được.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Thôi')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Xóa')),
        ],
      ),
    );
    if (dongY != true) return;
    final loi = await TroLyApi.xoaDuLieuMayChu();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loi)));
    await _tai();
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
                Expanded(child: _oSo('$_luotGiaiDe/${luotMienPhi['giaide']}', 'Lượt giải đề hôm nay', const Color(0xFFFFF4D6))),
                const SizedBox(width: 8),
                Expanded(child: _oSo('$_luotNhanXet/${luotMienPhi['nhanxet']}', 'Lượt AI viết nhận xét', const Color(0xFFE3ECF8))),
              ],
            ),
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('Lượt miễn phí được làm mới lúc 0 giờ mỗi ngày.', style: TextStyle(fontSize: 12, color: MauApp.chuPhu)),
            ),
            const SizedBox(height: 12),
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
                    leading: const Icon(Icons.support_agent, color: MauApp.xanhDam),
                    title: const Text('Hỗ trợ'),
                    subtitle: const Text(emailHoTro),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _moTrang(trangHoTro),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined, color: MauApp.xanhDam),
                    title: const Text('Chính sách quyền riêng tư'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _moTrang(trangQuyenRiengTu),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.gavel_outlined, color: MauApp.xanhDam),
                    title: const Text('Điều khoản sử dụng'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _moTrang(trangDieuKhoan),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.fingerprint, color: MauApp.xanhDam),
                    title: const Text('Mã máy'),
                    subtitle: Text(_maMay.isEmpty ? '…' : _maMay, style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5)),
                    trailing: const Icon(Icons.copy, size: 18),
                    onTap: () async {
                      await Clipboard.setData(ClipboardData(text: _maMay));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Đã chép mã máy. Gửi mã này khi cần hỗ trợ.')),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    title: const Text('Xóa dữ liệu của tôi trên máy chủ'),
                    subtitle: const Text('Số lượt đã dùng và báo cáo đã gửi'),
                    onTap: _xoaDuLieu,
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
