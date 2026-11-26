import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/tien_ich.dart';
import '../main.dart';
import '../services/tro_ly_api.dart';
import 'bieu_tuong.dart';
import 'dieu_huong.dart';
import 'thanh_duoi.dart';

/// Số phiên bản và số bản đọc từ chính app lúc chạy, ví dụ "0.4.0 (9)" (trước 26/11/2026 ghi cứng "0.3.0",
/// nâng phiên bản quên sửa nên màn Tài khoản hiện sai).
Future<String> docPhienBanApp() async {
  try {
    final p = await PackageInfo.fromPlatform();
    return p.buildNumber.isEmpty ? p.version : '${p.version} (${p.buildNumber})';
  } catch (_) {
    return '';
  }
}

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
  String _phienBan = '';

  @override
  void initState() {
    super.initState();
    _tai();
  }

  Future<void> _tai() async {
    final h = await HoSo.doc();
    final ma = await TroLyApi.maMay();
    final pb = await docPhienBanApp();
    if (mounted) setState(() => _phienBan = pb);
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
      bottomNavigationBar: const ThanhDuoi(chon: nutTaiKhoan),
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
            // Ô căn trên, chiều cao theo cỡ chữ của máy (cùng kiểu với Tất cả tiện ích)
            GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisExtent: chieuCaoOTienIch(context, size: 46),
                mainAxisSpacing: 4,
              ),
              children: [
                for (final t in dsTienIch)
                  OTienIch(ma: t.ma, icon: t.bieuTuong, ten: t.ten, size: 46, mo: !t.coTrongBanDau, bam: () => moTienIch(context, t)),
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
                      applicationVersion: _phienBan,
                      applicationLegalese: 'Bớt sổ sách, thêm giờ cho học trò.',
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.info_outline, color: MauApp.xanhDam),
                    title: const Text('Phiên bản'),
                    trailing: Text(_phienBan.isEmpty ? '…' : _phienBan),
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

