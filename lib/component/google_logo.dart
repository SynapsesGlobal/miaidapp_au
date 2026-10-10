import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 用画笔画出的 Google「G」标志，用于登录按钮和个人页的登录方式列表。
///
/// 画成矢量而不是放 PNG，是为了在任何尺寸下都清晰、不需要登记资源文件。
/// 四段圆弧加一条横杠，颜色取 Google 品牌色。
class GoogleLogo extends StatelessWidget {
  const GoogleLogo({Key? key, this.size = 18}) : super(key: key);

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: const _GoogleLogoPainter(),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  static const Color _blue = Color(0xFF4285F4);
  static const Color _green = Color(0xFF34A853);
  static const Color _yellow = Color(0xFFFBBC05);
  static const Color _red = Color(0xFFEA4335);

  /// 各色段的起止角度（度，0 为三点钟方向，顺时针为正），右上留出「G」的开口
  static const List<_Arc> _arcs = [
    _Arc(_blue, 0, 50),
    _Arc(_green, 50, 135),
    _Arc(_yellow, 135, 210),
    _Arc(_red, 210, 315),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.2;
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - strokeWidth / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    for (final arc in _arcs) {
      paint.color = arc.color;
      canvas.drawArc(
        rect,
        _radians(arc.startDegrees),
        _radians(arc.endDegrees - arc.startDegrees),
        false,
        paint,
      );
    }

    // 横杠：从圆心向右延伸到圆环外沿，与蓝色弧相接
    final bar = Rect.fromLTWH(
      center.dx,
      center.dy - strokeWidth / 2,
      size.width / 2,
      strokeWidth,
    );
    canvas.drawRect(bar, Paint()..color = _blue);
  }

  static double _radians(double degrees) => degrees * math.pi / 180;

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Arc {
  const _Arc(this.color, this.startDegrees, this.endDegrees);

  final Color color;
  final double startDegrees;
  final double endDegrees;
}
