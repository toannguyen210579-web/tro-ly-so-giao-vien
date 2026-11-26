import 'package:flutter/material.dart';

/// Hai màu chuyển cho biểu tượng từng tiện ích (trên sáng, dưới đậm).
const mauTienIch = <String, (Color, Color)>{
  'hop': (Color(0xFFFFA24C), Color(0xFFEF4A23)),
  'quet': (Color(0xFF5CCBFA), Color(0xFF1E6FE5)),
  'minh_chung': (Color(0xFF3EE0A0), Color(0xFF0C9467)),
  'anh_the': (Color(0xFFFF86BE), Color(0xFFE0307A)),
  'doc_to': (Color(0xFFB59CFF), Color(0xFF6A47E0)),
  'sang_word': (Color(0xFF6CB2FF), Color(0xFF2353D6)),
  'lich': (Color(0xFFFF7A7A), Color(0xFFD42539)),
  'luong': (Color(0xFFFFD95A), Color(0xFFF08C00)),
  'danh_gia': (Color(0xFF7EE0C0), Color(0xFF13806A)),
  'nhan_xet': (Color(0xFF5BE38A), Color(0xFF15973F)),
  'cham_tn': (Color(0xFF34DCF0), Color(0xFF0A8AAE)),
  'nhan_ph': (Color(0xFF4CC4FF), Color(0xFF0B63A8)),
  'tao_de': (Color(0xFF8F99FF), Color(0xFF4335C8)),
  'trinh_chieu': (Color(0xFFB8E36A), Color(0xFF4E8A12)),
  'o_chu': (Color(0xFFFFC27A), Color(0xFFE5570B)),
  'gio_the': (Color(0xFFFF7E92), Color(0xFFBC1340)),
  'cong_cu': (Color(0xFF63F0D8), Color(0xFF0E7A70)),
  'dich': (Color(0xFFE29BFF), Color(0xFF8E24AA)),
  'hoi': (Color(0xFF6FD3FF), Color(0xFF2563EB)),
  'dang': (Color(0xFFFF7B6B), Color(0xFFC62828)),
  // Các mục trong Công tác Đảng (biểu tượng kiểu app, thầy cô yêu cầu 24/11/2026): tông đỏ, vàng
  'dang_lich': (Color(0xFFFF7A7A), Color(0xFFC62828)),
  'dang_phi': (Color(0xFFFFD95A), Color(0xFFE08A00)),
  'dang_dvc': (Color(0xFFFF6A6A), Color(0xFF9F1239)),
  'dang_so_tay': (Color(0xFFFFB067), Color(0xFFE0570B)),
  'dang_hoi': (Color(0xFFFF8FA8), Color(0xFFC2185B)),
  'khac': (Color(0xFFA9B6C8), Color(0xFF4B5A70)),
};

/// Biểu tượng nổi: nền chuyển màu, bóng đổ, vệt sáng bóng phía trên, hình trắng có bóng.
class BieuTuongNoi extends StatelessWidget {
  final String ma;
  final IconData icon;
  final double size;
  final bool mo;
  const BieuTuongNoi({super.key, required this.ma, required this.icon, this.size = 52, this.mo = false});

  @override
  Widget build(BuildContext context) {
    final (sang, dam) = mauTienIch[ma] ?? mauTienIch['khac']!;
    final r = size * 0.3;
    final o = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(r),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [sang, dam]),
        boxShadow: [
          BoxShadow(color: dam.withOpacity(0.38), blurRadius: size * 0.22, offset: Offset(0, size * 0.12)),
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 2, offset: const Offset(0, 1)),
        ],
      ),
      child: Stack(
        children: [
          // vệt sáng bóng nửa trên
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: size * 0.52,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(r), bottom: Radius.circular(size * 0.5)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white.withOpacity(0.42), Colors.white.withOpacity(0.0)],
                ),
              ),
            ),
          ),
          // viền sáng mép trên
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(r),
                border: Border.all(color: Colors.white.withOpacity(0.28), width: 1),
              ),
            ),
          ),
          Center(
            child: ma == 'trinh_chieu'
                // Biểu tượng riêng (chốt 25/11/2026): bảng trình chiếu có chân, trên bảng có biểu đồ nhỏ;
                // không dùng, không làm giống biểu tượng PowerPoint
                ? CustomPaint(size: Size.square(size * 0.58), painter: BangTrinhChieu(dam))
                : Icon(
                    icon,
                    size: size * 0.54,
                    color: Colors.white,
                    shadows: [Shadow(color: dam.withOpacity(0.8), blurRadius: size * 0.08, offset: Offset(0, size * 0.04))],
                  ),
          ),
        ],
      ),
    );
    return mo ? Opacity(opacity: 0.55, child: o) : o;
  }
}

/// Một ô trong lưới biểu tượng (Trang chủ, Tất cả tiện ích, Tài khoản, Công tác Đảng): biểu tượng ở trên, tên bên dưới
/// tối đa 2 dòng, có thể thêm một dòng chú thích ngắn đứng yên. Nội dung căn trên nên biểu tượng cùng hàng luôn thẳng nhau;
/// chiều cao ô lấy theo [chieuCaoOTienIch] nên máy để chữ to không bị cắt chữ (thầy cô báo 24/11/2026).
/// Không dùng dòng chữ chạy nữa (thầy cô chê chữ nhỏ, chạy rối, 24/11/2026).
class OTienIch extends StatelessWidget {
  final String ma;
  final IconData icon;
  final String ten;
  final VoidCallback bam;
  final double size;
  final bool mo;

  /// Dòng chú thích ngắn dưới tên, ví dụ "Mở app iCPV - Book"
  final String? chuThich;

  /// Dấu nhỏ "mở ra ngoài" ở góc biểu tượng: bấm vào là sang app, trang web khác
  final bool moRaNgoai;

  const OTienIch({
    super.key,
    required this.ma,
    required this.icon,
    required this.ten,
    required this.bam,
    this.size = 50,
    this.mo = false,
    this.chuThich,
    this.moRaNgoai = false,
  });

  @override
  Widget build(BuildContext context) {
    final bieuTuong = BieuTuongNoi(ma: ma, icon: icon, size: size, mo: mo);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: bam,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(2, 6, 2, 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            if (moRaNgoai)
              SizedBox(
                width: size + 8,
                height: size + 4,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(left: 4, top: 0, child: bieuTuong),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: size * 0.4,
                        height: size * 0.4,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 3, offset: Offset(0, 1))],
                          border: Border.all(color: const Color(0xFFDCE3EE)),
                        ),
                        child: Icon(Icons.open_in_new_rounded, size: size * 0.24, color: const Color(0xFF1F4E8C)),
                      ),
                    ),
                  ],
                ),
              )
            else
              bieuTuong,
            const SizedBox(height: 8),
            Text(
              ten,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, height: 1.2, color: Color(0xFF14233A)),
            ),
            if (chuThich != null) ...[
              const SizedBox(height: 2),
              Text(
                chuThich!,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11.5, height: 1.2, color: Color(0xFF55657A)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Chiều cao một ô [OTienIch] theo cỡ chữ đang đặt trên máy: biểu tượng, khoảng cách, 2 dòng tên
/// (và 2 dòng chú thích nếu có), cộng phần đệm. Dùng làm mainAxisExtent của lưới.
double chieuCaoOTienIch(BuildContext context, {double size = 50, bool coChuThich = false, bool moRaNgoai = false}) {
  final tl = MediaQuery.textScalerOf(context);
  final ten = tl.scale(12.5) * 1.2 * 2;
  final chuThich = coChuThich ? 2 + tl.scale(11.5) * 1.2 * 2 : 0.0;
  return 6 + size + (moRaNgoai ? 4 : 0) + 8 + ten + chuThich + 10;
}

/// Hình bảng trình chiếu có chân, trên bảng có biểu đồ cột nhỏ (biểu tượng tiện ích Tạo bài trình chiếu).
class BangTrinhChieu extends CustomPainter {
  final Color bong;
  const BangTrinhChieu(this.bong);

  void _ve(Canvas c, Size s, Paint net, Paint dac) {
    final w = s.width, h = s.height;
    // mặt bảng
    c.drawRRect(RRect.fromLTRBR(w * 0.08, h * 0.1, w * 0.92, h * 0.64, Radius.circular(w * 0.07)), net);
    // chân bảng
    c.drawLine(Offset(w * 0.42, h * 0.66), Offset(w * 0.26, h * 0.94), net);
    c.drawLine(Offset(w * 0.58, h * 0.66), Offset(w * 0.74, h * 0.94), net);
    c.drawLine(Offset(w * 0.5, h * 0.02), Offset(w * 0.5, h * 0.1), net);
    // biểu đồ cột tăng dần
    final day = h * 0.53;
    for (final (x, cao) in [(0.24, 0.12), (0.42, 0.2), (0.6, 0.29)]) {
      c.drawRRect(RRect.fromLTRBR(w * x, day - h * cao, w * (x + 0.12), day, Radius.circular(w * 0.02)), dac);
    }
  }

  @override
  void paint(Canvas c, Size s) {
    Paint net(Color m) => Paint()
      ..color = m
      ..style = PaintingStyle.stroke
      ..strokeWidth = s.width * 0.075
      ..strokeCap = StrokeCap.round;
    Paint dac(Color m) => Paint()..color = m;
    // bóng đổ nhẹ phía dưới như các biểu tượng khác
    c.save();
    c.translate(0, s.height * 0.06);
    final mo = MaskFilter.blur(BlurStyle.normal, s.width * 0.06);
    _ve(c, s, net(bong.withOpacity(0.7))..maskFilter = mo, dac(bong.withOpacity(0.7))..maskFilter = mo);
    c.restore();
    _ve(c, s, net(Colors.white), dac(Colors.white));
  }

  @override
  bool shouldRepaint(BangTrinhChieu cu) => cu.bong != bong;
}
