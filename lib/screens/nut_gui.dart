import 'package:flutter/material.dart';

/// Màu nút gửi: xanh trời tươi, đủ đậm để mũi tên trắng nổi rõ.
const mauNutGui = Color(0xFF1683F5);

/// Nút gửi dùng chung ở ô hỏi Trang chủ và Hỏi Trợ lý: nền xanh trời tươi, mũi tên trắng to, bóng nhẹ;
/// đang chờ AI trả lời thì hiện vòng xoay trắng (thầy cô yêu cầu 24/11/2026: nút cũ xanh xám, mũi tên chìm).
class NutGui extends StatelessWidget {
  final VoidCallback? bam;
  final bool dangCho;
  final double co;
  const NutGui({super.key, required this.bam, this.dangCho = false, this.co = 46});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: dangCho ? 'Đang chờ Trợ lý trả lời' : 'Gửi câu hỏi',
      child: Material(
        color: mauNutGui,
        shape: const CircleBorder(),
        elevation: 4,
        shadowColor: const Color(0x991683F5),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: dangCho ? null : bam,
          child: SizedBox(
            width: co,
            height: co,
            child: Center(
              child: dangCho
                  ? SizedBox(
                      width: co * 0.42,
                      height: co * 0.42,
                      child: const CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                    )
                  : Icon(
                      Icons.arrow_upward,
                      color: Colors.white,
                      size: co * 0.62,
                      shadows: const [Shadow(color: Color(0x55000000), blurRadius: 2, offset: Offset(0, 1))],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
