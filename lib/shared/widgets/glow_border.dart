import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 流光配色：亮黄拖尾 → 琥珀 → 玫红喷头。
const List<Color> kGlowColors = [
  Color(0xFFFFF59D),
  Color(0xFFFFC107),
  Color(0xFFFF3D6E),
];

/// 沿边框转圈的光辉：在子组件四周的圆角描边上画一段走动的高光。
///
/// 用来把「现在能玩的那一个入口」从一堆置灰入口里挑出来。
/// 系统开了「减弱动态效果」时不再转动，只留一圈静止的亮边。
class GlowBorder extends StatefulWidget {
  const GlowBorder({
    super.key,
    required this.child,
    this.radius = 18,
    this.strokeWidth = 3,
    this.colors = kGlowColors,
    this.period = const Duration(seconds: 3),
  });

  final Widget child;

  /// 圆角，应和子组件自身的圆角一致。
  final double radius;

  /// 描边粗细（外圈柔光按它放大）。
  final double strokeWidth;

  final List<Color> colors;

  /// 光辉绕一圈的时长。
  final Duration period;

  @override
  State<GlowBorder> createState() => _GlowBorderState();
}

class _GlowBorderState extends State<GlowBorder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _turn = AnimationController(
    vsync: this,
    duration: widget.period,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (still) {
      _turn.stop();
      _turn.value = 0;
    } else if (!_turn.isAnimating) {
      _turn.repeat();
    }
  }

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _GlowPainter(
        turn: _turn,
        radius: widget.radius,
        strokeWidth: widget.strokeWidth,
        colors: widget.colors,
      ),
      child: widget.child,
    );
  }
}

class _GlowPainter extends CustomPainter {
  _GlowPainter({
    required this.turn,
    required this.radius,
    required this.strokeWidth,
    required this.colors,
  }) : super(repaint: turn);

  final Animation<double> turn;
  final double radius;
  final double strokeWidth;
  final List<Color> colors;

  // 亮带只占圆周约 1/3，看起来才像一段跑动的光而不是半个圈发亮。
  static const List<double> _stops = [0.0, 0.34, 0.52, 0.66, 1.0];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final inset = strokeWidth / 2;
    final rect = (Offset.zero & size).deflate(inset);
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(math.max(0, radius - inset)),
    );
    final shader = SweepGradient(
      transform: GradientRotation(turn.value * 2 * math.pi),
      colors: [
        colors.first.withOpacity(0),
        colors.first,
        colors[1],
        colors.last,
        colors.last.withOpacity(0),
      ],
      stops: _stops,
    ).createShader(rect);

    // 外圈柔光
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = shader
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth * 3
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, strokeWidth * 2),
    );
    // 内圈实边
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = shader
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_GlowPainter old) =>
      old.radius != radius ||
      old.strokeWidth != strokeWidth ||
      old.colors != colors;
}
