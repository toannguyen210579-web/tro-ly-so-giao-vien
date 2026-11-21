import 'package:flutter/material.dart';

import '../data/tien_ich.dart';
import '../main.dart';
import '../data/lich.dart';
import 'bieu_tuong.dart';
import 'lich_nhac_han.dart';
import 'chu_chay.dart';
import 'dieu_huong.dart';
import 'tai_khoan.dart';
import 'tep_cua_toi.dart';
import 'tin_kenh.dart';

class TrangChu extends StatefulWidget {
  const TrangChu({super.key});

  @override
  State<TrangChu> createState() => _TrangChuState();
}

class _TrangChuState extends State<TrangChu> {
  final _o = TextEditingController();

  @override
  void dispose() {
    _o.dispose();
    super.dispose();
  }

  void _gui([String? cau]) {
    xuLyCauNhap(context, cau ?? _o.text);
    _o.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          children: [
            _dauTrang(),
            const SizedBox(height: 12),
            _oHoi(),
            _nhom('Hành chính', MauApp.xanhDam, const Color(0xFFE3ECF8), noiBatHanhChinh),
            _nhom('Chuyên môn', MauApp.xanhLa, const Color(0xFFDDF1EC), noiBatChuyenMon),
            const SizedBox(height: 8),
            _theHan(),
            const SizedBox(height: 16),
            const DongTinMoi(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (i) {
          final man = switch (i) {
            2 => const ManTin(),
            3 => const TepCuaToi(),
            4 => const TaiKhoan(),
            _ => null,
          };
          if (i == 1) moHoiTroLy(context);
          if (man != null) Navigator.of(context).push(MaterialPageRoute(builder: (_) => man));
        },
        indicatorColor: Colors.transparent,
        destinations: const [
          NavigationDestination(icon: KhoiMau(icon: Icons.home_rounded, mau: mauTrangChu), label: 'Trang chủ'),
          NavigationDestination(icon: KhoiMau(icon: Icons.chat_rounded, mau: mauHoiTroLy), label: 'Hỏi Trợ lý'),
          NavigationDestination(icon: KhoiMau(icon: Icons.play_arrow_rounded, mau: mauTinTuc, coIcon: 23), label: 'Tin tức'),
          NavigationDestination(icon: KhoiMau(icon: Icons.folder_rounded, mau: mauTep), label: 'Tệp của tôi'),
          NavigationDestination(icon: KhoiMau(icon: Icons.person_rounded, mau: mauTaiKhoan), label: 'Tài khoản'),
        ],
      ),
    );
  }

  Widget _dauTrang() {
    return Row(
      children: [
        const KhoiMau(icon: Icons.task_alt_rounded, mau: mauTrangChu, rong: 42, cao: 42, coIcon: 26, bo: 12),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Chào thầy cô',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: MauApp.xanhTroi, shadows: bongChu)),
              Text('Trợ lý số Giáo viên',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: MauApp.xanhDam, shadows: bongChu)),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Thông báo',
          onPressed: () {},
          icon: const KhoiMau(icon: Icons.notifications_rounded, mau: mauTep, rong: 38, cao: 38, coIcon: 22, bo: 19),
        ),
      ],
    );
  }

  Widget _oHoi() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF8FB2F2), width: 1.6),
        boxShadow: const [BoxShadow(color: Color(0x332C6EE8), blurRadius: 18, offset: Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _o,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _gui(),
            decoration: const InputDecoration(
              hintText: 'Thầy cô cần làm gì?',
              hintStyle: TextStyle(fontWeight: FontWeight.w700, color: MauApp.chuPhu),
              border: InputBorder.none,
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final g in const ['Làm biên bản họp tổ', 'Chấm trắc nghiệm'])
                      ActionChip(
                        label: Text(g, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: MauApp.xanhDam)),
                        backgroundColor: const Color(0xFFEAF2FF),
                        side: const BorderSide(color: Color(0xFF9DBCF3)),
                        elevation: 3,
                        shadowColor: const Color(0x552C6EE8),
                        onPressed: () => _gui(g),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Gửi',
                onPressed: () => _gui(),
                // Nút gửi màu xanh, mũi tên màu đỏ (theo ý thầy 21/11/2026)
                icon: const KhoiMau(icon: Icons.arrow_upward_rounded, mau: mauTrangChu, rong: 46, cao: 46, coIcon: 28, bo: 23,
                    mauIcon: Color(0xFFE53935), nenTrang: true),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _nhom(String ten, Color mau, Color nenO, List<String> ma) {
    final ds = ma.map(timTheoMa).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 0, 4),
          child: Row(
            children: [
              Expanded(child: Text(ten, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: mau))),
              TextButton(onPressed: () => moXemThem(context), child: Text('Tất cả', style: TextStyle(color: mau))),
            ],
          ),
        ),
        Row(
          children: [
            for (final t in ds) Expanded(child: _o1(t.ten, t.bieuTuong, t.ma, () => moTienIch(context, t), moTa: t.moTa)),
            Expanded(child: _o1('Khác', Icons.apps, 'khac', () => moXemThem(context), moTa: 'Xem đủ 15 tiện ích')),
          ],
        ),
      ],
    );
  }

  Widget _o1(String ten, IconData icon, String ma, VoidCallback bam, {String? moTa}) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: bam,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Column(
          children: [
            BieuTuongNoi(ma: ma, icon: icon, size: 50),
            const SizedBox(height: 8),
            SizedBox(
              height: 32,
              child: Text(ten,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, height: 1.2)),
            ),
            if (moTa != null) ...[
              const SizedBox(height: 2),
              ChuChay(moTa, style: const TextStyle(fontSize: 10.5, color: MauApp.chuPhu)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _theHan() {
    return FutureBuilder<ViecHan?>(
      future: viecSapDenHan(),
      builder: (context, snap) {
        final v = snap.data;
        return Material(
          color: Colors.white,
          elevation: 4,
          shadowColor: const Color(0x552C6EE8),
          borderRadius: BorderRadius.circular(16),
          child: ListTile(
            onTap: () async {
              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LichNhacHan()));
              if (mounted) setState(() {});
            },
            leading: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: const Color(0xFFFDECEC), borderRadius: BorderRadius.circular(10)),
              child: const Text('HẠN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFA3241C))),
            ),
            title: Text(v == null ? 'Chưa có việc sắp đến hạn' : v.ten,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(v == null ? 'Bấm để thêm việc vào Lịch công tác' : '${conBaoLau(v.han)} · ${v.han.day}/${v.han.month}/${v.han.year}'),
            trailing: const Icon(Icons.chevron_right),
          ),
        );
      },
    );
  }

}


/// Màu các khối nổi (phương án 1, chốt 21/11/2026): mỗi nút ở thanh dưới một màu.
const mauTrangChu = [Color(0xFF6FD0FB), Color(0xFF2C6EE8), Color(0xFF16A58E)];
const mauHoiTroLy = [Color(0xFFC4B5FD), Color(0xFF7C6CF2), Color(0xFF2C6EE8)];
const mauTinTuc = [Color(0xFFFF8A65), Color(0xFFF4511E), Color(0xFFD32F2F)];
const mauTep = [Color(0xFFFFD54F), Color(0xFFFFA726), Color(0xFFF57C00)];
const mauTaiKhoan = [Color(0xFF9BE7A6), Color(0xFF34C759), Color(0xFF1E8E3E)];

/// Bóng nhẹ cho chữ cố định (tiêu đề, tên app) để chữ nổi lên.
const bongChu = [Shadow(color: Color(0x332C6EE8), blurRadius: 3, offset: Offset(0, 1.5))];

/// Khối màu chuyển bo góc, có bóng, hình trắng ở giữa: kiểu biểu tượng nổi dùng chung trong app.
class KhoiMau extends StatelessWidget {
  final IconData icon;
  final List<Color> mau;
  final double rong, cao, coIcon, bo;
  final Color mauIcon;
  /// Nền trắng bên trong viền màu (dùng cho nút gửi: nền xanh, mũi tên đỏ trên lõi trắng)
  final bool nenTrang;
  const KhoiMau({
    super.key,
    required this.icon,
    required this.mau,
    this.rong = 38,
    this.cao = 30,
    this.coIcon = 21,
    this.bo = 9,
    this.mauIcon = Colors.white,
    this.nenTrang = false,
  });

  @override
  Widget build(BuildContext context) {
    final nen = BoxDecoration(
      borderRadius: BorderRadius.circular(bo),
      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: mau, stops: const [0, 0.55, 1]),
      boxShadow: [BoxShadow(color: mau[1].withValues(alpha: 0.45), blurRadius: 9, offset: const Offset(0, 3))],
    );
    final hinh = Icon(icon, color: mauIcon, size: coIcon, shadows: nenTrang ? null : const [Shadow(color: Color(0x40000000), blurRadius: 2, offset: Offset(0, 1))]);
    return Container(
      width: rong,
      height: cao,
      decoration: nen,
      alignment: Alignment.center,
      child: nenTrang
          ? Container(
              width: rong - 12,
              height: cao - 12,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(bo - 6)),
              child: hinh,
            )
          : hinh,
    );
  }
}
