import 'package:flutter/material.dart';

import '../data/tien_ich.dart';
import '../main.dart';
import '../data/lich.dart';
import 'bieu_tuong.dart';
import 'lich_nhac_han.dart';
import 'dieu_huong.dart';
import 'nut_gui.dart';
import 'thanh_duoi.dart';
import 'tin_kenh.dart';

class TrangChu extends StatefulWidget {
  const TrangChu({super.key});

  @override
  State<TrangChu> createState() => _TrangChuState();
}

class _TrangChuState extends State<TrangChu> {
  final _o = TextEditingController();
  final _cuon = ScrollController();

  @override
  void dispose() {
    _o.dispose();
    _cuon.dispose();
    super.dispose();
  }

  void _gui([String? cau]) {
    xuLyCauNhap(context, cau ?? _o.text);
    _o.clear();
  }

  /// Bấm nút Trang chủ khi đang ở Trang chủ: cuộn về đầu trang
  void _veDau() {
    if (_cuon.hasClients) _cuon.animateTo(0, duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          controller: _cuon,
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
      bottomNavigationBar: ThanhDuoi(chon: nutTrangChu, veDau: _veDau),
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
          // Chữ nhắc "Hỏi AI…" (thay "Thầy cô cần làm gì?", 24/11/2026); dùng dấu nháy mặc định của máy.
          // Gõ đúng tên tiện ích thì mở thẳng tiện ích, câu khác chuyển sang hỏi AI (xuLyCauNhap).
          TextField(
            controller: _o,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _gui(),
            style: const TextStyle(fontSize: 16),
            decoration: const InputDecoration(
              hintText: 'Hỏi AI…',
              hintStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: MauApp.chuPhu),
              border: InputBorder.none,
            ),
          ),
          Row(
            children: [
              Expanded(
                // Hai gợi ý luôn nằm gọn một dòng (máy hẹp thì tự thu nhỏ)
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      for (final g in const ['Làm biên bản họp tổ', 'Chấm trắc nghiệm'])
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ActionChip(
                            label: Text(g, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: MauApp.xanhDam)),
                            backgroundColor: const Color(0xFFEAF2FF),
                            side: const BorderSide(color: Color(0xFF9DBCF3)),
                            elevation: 3,
                            shadowColor: const Color(0x552C6EE8),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                            onPressed: () => _gui(g),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Nút gửi xanh trời tươi, mũi tên trắng (thầy cô chốt 24/11/2026, thay nút mũi tên đỏ ngày 21/11)
              NutGui(bam: () => _gui(), co: 46),
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
        // Các ô căn trên: tên một dòng hay hai dòng thì biểu tượng vẫn thẳng hàng (thầy cô báo lệch 24/11/2026)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final t in ds)
              Expanded(child: OTienIch(ma: t.ma, icon: t.bieuTuong, ten: t.ten, bam: () => moTienIch(context, t))),
            Expanded(child: OTienIch(ma: 'khac', icon: Icons.apps, ten: 'Khác', bam: () => moXemThem(context))),
          ],
        ),
      ],
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
