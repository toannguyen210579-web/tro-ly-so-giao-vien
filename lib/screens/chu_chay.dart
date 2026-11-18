import 'package:flutter/material.dart';

/// Dòng chữ chạy ngang: nếu câu dài hơn ô thì chạy từ phải sang trái rồi lặp lại;
/// câu ngắn vừa ô thì đứng yên ở giữa.
class ChuChay extends StatefulWidget {
  final String chu;
  final TextStyle style;

  /// Bề rộng tối đa của khung chữ chạy.
  final double toiDa;
  const ChuChay(this.chu, {super.key, required this.style, this.toiDa = 150});

  @override
  State<ChuChay> createState() => _ChuChayState();
}

class _ChuChayState extends State<ChuChay> with SingleTickerProviderStateMixin {
  late final AnimationController _ac = AnimationController(vsync: this);
  double _rongChu = 0;
  double _rongO = 0;
  static const _khoangCach = 40.0;
  static const _tocDo = 30.0; // điểm ảnh mỗi giây

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  void _datLai(double rongO) {
    final tp = TextPainter(
      text: TextSpan(text: widget.chu, style: widget.style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    if (tp.width == _rongChu && rongO == _rongO) return;
    _rongChu = tp.width;
    _rongO = rongO;
    if (_rongChu > _rongO) {
      _ac.duration = Duration(milliseconds: ((_rongChu + _khoangCach) / _tocDo * 1000).round());
      _ac.repeat();
    } else {
      _ac.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cao = (widget.style.fontSize ?? 12) * 1.45;
    return LayoutBuilder(builder: (context, c) {
      // Khung chữ chạy gọn dưới biểu tượng, không tràn sang ô bên cạnh khi màn hình rộng.
      final rong = c.maxWidth.isFinite ? (c.maxWidth > widget.toiDa ? widget.toiDa : c.maxWidth) : widget.toiDa;
      _datLai(rong);
      if (_rongChu <= _rongO) {
        return Center(
          child: SizedBox(
            height: cao,
            child: Text(widget.chu, style: widget.style, maxLines: 1, textAlign: TextAlign.center),
          ),
        );
      }
      return Center(
        child: SizedBox(
        height: cao,
        width: rong,
        child: ShaderMask(
          // Mờ dần hai mép cho chữ vào ra êm, không bị cắt ngang giữa chữ.
          shaderCallback: (r) => const LinearGradient(
            colors: [Color(0x00000000), Color(0xFF000000), Color(0xFF000000), Color(0x00000000)],
            stops: [0, 0.12, 0.88, 1],
          ).createShader(r),
          blendMode: BlendMode.dstIn,
          child: ClipRect(
          child: AnimatedBuilder(
            animation: _ac,
            builder: (_, __) {
              final dx = -_ac.value * (_rongChu + _khoangCach);
              return OverflowBox(
                alignment: Alignment.centerLeft,
                maxWidth: double.infinity,
                child: Transform.translate(
                  offset: Offset(dx, 0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(widget.chu, style: widget.style, maxLines: 1, softWrap: false),
                      const SizedBox(width: _khoangCach),
                      Text(widget.chu, style: widget.style, maxLines: 1, softWrap: false),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        ),
        ),
      );
    });
  }
}
