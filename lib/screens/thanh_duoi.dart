import 'package:flutter/material.dart';

import 'dieu_huong.dart';
import 'tai_khoan.dart';
import 'tep_cua_toi.dart';
import 'tin_kenh.dart';
import 'trang_chu.dart' show KhoiMau, mauHoiTroLy, mauTinTuc, mauTrangChu, mauTep, mauTaiKhoan;

/// Vị trí các nút ở thanh dưới: Hỏi Trợ lý, Tin tức, Trang chủ (giữa), Tệp của tôi, Tài khoản.
const nutHoi = 0, nutTin = 1, nutTrangChu = 2, nutTep = 3, nutTaiKhoan = 4;

/// Thanh nút dưới cùng dùng chung cho Trang chủ, Tin tức, Tệp của tôi, Tài khoản (sửa 26/11/2026).
/// Trước đây chỉ Trang chủ có thanh này và nút Trang chủ bấm không có phản hồi, nút đang chọn không được tô.
/// Nay: nút đang chọn có nền xanh nhạt; bấm Trang chủ ở Trang chủ thì cuộn về đầu trang ([veDau]),
/// ở màn khác thì quay ngay về Trang chủ; chuyển giữa Tin tức, Tệp, Tài khoản không chồng thêm màn.
class ThanhDuoi extends StatelessWidget {
  final int chon;
  final VoidCallback? veDau;
  const ThanhDuoi({super.key, required this.chon, this.veDau});

  void _bam(BuildContext context, int i) {
    if (i == chon) {
      veDau?.call();
      return;
    }
    final nav = Navigator.of(context);
    if (i == nutTrangChu) {
      nav.popUntil((r) => r.isFirst);
      return;
    }
    if (i == nutHoi) {
      moHoiTroLy(context);
      return;
    }
    final Widget man = switch (i) {
      nutTin => const ManTin(),
      nutTep => const TepCuaToi(),
      _ => const TaiKhoan(),
    };
    final route = MaterialPageRoute<void>(builder: (_) => man);
    if (chon == nutTrangChu) {
      nav.push(route);
    } else {
      nav.pushReplacement(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: chon,
      onDestinationSelected: (i) => _bam(context, i),
      indicatorColor: const Color(0xFFDCE8FF),
      destinations: const [
        NavigationDestination(icon: KhoiMau(icon: Icons.chat_rounded, mau: mauHoiTroLy), label: 'Hỏi Trợ lý'),
        NavigationDestination(icon: KhoiMau(icon: Icons.play_arrow_rounded, mau: mauTinTuc, coIcon: 23), label: 'Tin tức'),
        NavigationDestination(icon: KhoiMau(icon: Icons.home_rounded, mau: mauTrangChu), label: 'Trang chủ'),
        NavigationDestination(icon: KhoiMau(icon: Icons.folder_rounded, mau: mauTep), label: 'Tệp của tôi'),
        NavigationDestination(icon: KhoiMau(icon: Icons.person_rounded, mau: mauTaiKhoan), label: 'Tài khoản'),
      ],
    );
  }
}
