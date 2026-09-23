import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 流光配色：亮黄拖尾 → 琥珀 → 玫红喷头。
const List<Color> kGlowColors = [
  Color(0xFFFFF59D),
  Color(0xFFFFC107),
  Color(0xFFFF3D6E),
];

/// 「答案就在这几个格子里」用的淡蓝流光，比默认那套暖色收敛一些。
const List<Color> kAnswerGlowColors = [
  Color(0xFFB3E5FC),
  Color(0xFF4FC3F7),
  Color(0xFF039BE5),
];

/// 沿边框转圈的光辉：在子组件四周的圆角描边上画一段走动的高光。
///
/// 用来把「现在能玩的那一个入口」从一堆置灰入口里挑出来。
/// 系统开了「减弱动态效果」时不再转动，只留一圈静止的亮边。
///
/// [spin] 关掉就不转：整圈一起亮，再由亮到灭闪一下（[period] 就是这一下的时长），
/// 给「答案就在这几个格子里」这种瞄一眼就够的提示用。
class GlowBorder extends StatefulWidget {
  const GlowBorder({
    super.key,
    required this.child,
    this.radius = 18,
    this.strokeWidth = 3,
    this.colors = kGlowColors,
    this.period = const Duration(seconds: 3),
    this.spin = true,
  });

  final Widget child;

  /// 圆角，应和子组件自身的圆角一致。
  final double radius;

  /// 描边粗细（外圈柔光按它放大）。
  final double strokeWidth;

  final List<Color> colors;

  /// 光辉绕一圈的时长；[spin] 为 false 时是「闪一下」的时长。
  final Duration period;

  /// 光是否沿边框转圈。false = 整圈一起亮、闪一下。
  final bool spin;

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
    } else if (widget.spin) {
      if (!_turn.isAnimating) _turn.repeat();
    } else if (_turn.value == 0) {
      // 闪一下：从 0 走到 1 就停，不回头。
      _turn.forward();
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
        spin: widget.spin,
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
    required this.spin,
  }) : super(repaint: turn);

  final Animation<double> turn;
  final double radius;
  final double strokeWidth;
  final List<Color> colors;
  final bool spin;

  // 亮带只占圆周约 1/3，看起来才像一段跑动的光而不是半个圈发亮。
  static const List<double> _stops = [0.0, 0.34, 0.52, 0.66, 1.0];

  // 「闪一下」：先全亮，走过这一段再往灭里收。
  static const double _holdUntil = 0.3;

  /// 外圈柔光比实边宽多少、糊多深。都压得比实边高一点，光晕不会溢出去一大团。
  static const double _softWidth = 1.6;
  static const double _softBlur = 0.9;

  double get _opacity {
    if (spin) return 1;
    final t = turn.value;
    if (t <= _holdUntil) return 1;
    return 1 - Curves.easeOutCubic.transform((t - _holdUntil) / (1 - _holdUntil));
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final opacity = _opacity;
    if (opacity <= 0) return;

    final inset = strokeWidth / 2;
    final rect = (Offset.zero & size).deflate(inset);
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(math.max(0, radius - inset)),
    );
    // 不转的时候整圈一个色：同一套画笔走下来，只是把流光换成一段匀光。
    final lit = colors[1].withOpacity(opacity);
    final shader = spin
        ? SweepGradient(
            transform: GradientRotation(turn.value * 2 * math.pi),
            colors: [
              colors.first.withOpacity(0),
              colors.first,
              colors[1],
              colors.last,
              colors.last.withOpacity(0),
            ],
            stops: _stops,
          ).createShader(rect)
        : SweepGradient(colors: [lit, lit]).createShader(rect);

    // 外圈柔光
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = shader
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth * _softWidth
        ..maskFilter =
            MaskFilter.blur(BlurStyle.normal, strokeWidth * _softBlur),
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
      old.colors != colors ||
      old.spin != spin;
}
