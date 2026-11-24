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
  'nhan_xet': (Color(0xFF5BE38A), Color(0xFF15973F)),
  'cham_tn': (Color(0xFF34DCF0), Color(0xFF0A8AAE)),
  'nhan_ph': (Color(0xFF4CC4FF), Color(0xFF0B63A8)),
  'tao_de': (Color(0xFF8F99FF), Color(0xFF4335C8)),
  'o_chu': (Color(0xFFFFC27A), Color(0xFFE5570B)),
  'gio_the': (Color(0xFFFF7E92), Color(0xFFBC1340)),
  'cong_cu': (Color(0xFF63F0D8), Color(0xFF0E7A70)),
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
            child: Icon(
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
