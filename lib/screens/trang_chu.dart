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
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Trang chủ'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), label: 'Hỏi Trợ lý'),
          NavigationDestination(icon: Icon(Icons.play_circle_outline), label: 'Tin'),
          NavigationDestination(icon: Icon(Icons.folder_outlined), label: 'Tệp của tôi'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Tài khoản'),
        ],
      ),
    );
  }

  Widget _dauTrang() {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Container(
            width: 38,
            height: 38,
            color: Colors.white,
            child: const Icon(Icons.task_outlined, color: MauApp.xanhTroi),
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Chào thầy cô', style: TextStyle(fontSize: 12.5, color: MauApp.chuPhu)),
              Text('Trợ lý số Giáo viên', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Thông báo',
          onPressed: () {},
          icon: const Icon(Icons.notifications_none),
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
        border: Border.all(color: const Color(0xFFBFD0F5), width: 1.5),
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
                    for (final g in const ['Làm biên bản họp tổ', 'Nhận xét lớp 6A'])
                      ActionChip(label: Text(g, style: const TextStyle(fontSize: 12.5)), onPressed: () => _gui(g)),
                  ],
                ),
              ),
              IconButton.filled(
                tooltip: 'Gửi',
                onPressed: () => _gui(),
                icon: const Icon(Icons.arrow_upward),
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
