import 'dart:math';

import 'package:flutter/material.dart';

/// 庆祝用的喜庆配色（金黄 / 橙 / 粉 / 蓝 / 绿 / 紫）。
const List<Color> kPartyColors = [
  Color(0xFFFFC107),
  Color(0xFFFF7043),
  Color(0xFFEC407A),
  Color(0xFF42A5F5),
  Color(0xFF66BB6A),
  Color(0xFFAB47BC),
];

/// 答对瞬间的「炫光爆发」：光晕 + 光环 + 放射星芒 + 飞散光点。
///
/// 用 [Stack] 的 `clipBehavior: Clip.none` 承载，让光点可以飞出边界。
class SparkleBurst extends StatelessWidget {
  const SparkleBurst({
    super.key,
    required this.animation,
    this.centerFraction = 0.5,
    this.seed = 7,
  });

  /// 0 → 1 的一次性动画（答对时 forward(from: 0)）。
  final Animation<double> animation;

  /// 爆发中心的横向位置（0 左 1 右），一般对准被挖空的那一格。
  final double centerFraction;

  /// 随机种子：每题换一个，星芒和光点不会每题都一样。
  final int seed;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: animation,
        builder: (_, __) => CustomPaint(
          painter: _BurstPainter(
            t: animation.value,
            fx: centerFraction,
            seed: seed,
          ),
          size: Size.infinite,
        ),
      );
}

class _BurstPainter extends CustomPainter {
  _BurstPainter({required this.t, required this.fx, required this.seed});

  final double t;
  final double fx;
  final int seed;

  static const int _rays = 12;
  static const int _sparks = 22;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    final rng = Random(seed);
    final c = Offset(size.width * fx, size.height * 0.5);
    final grow = Curves.easeOutCubic.transform(t);
    final fade = (1 - t).clamp(0.0, 1.0);

    // 1) 中心光晕
    final glowR = 26 + 78 * grow;
    canvas.drawCircle(
      c,
      glowR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFF3C4).withOpacity(0.85 * fade),
            const Color(0xFFFFC107).withOpacity(0.35 * fade),
            const Color(0xFFFFC107).withOpacity(0.0),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: glowR)),
    );

    // 2) 扩散光环
    canvas.drawCircle(
      c,
      20 + 96 * grow,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7 * (1 - t)
        ..color = Colors.white.withOpacity(0.75 * fade),
    );

    // 3) 放射星芒：每个角度一根由粗到尖的光条
    for (var i = 0; i < _rays; i++) {
      final a = i * 2 * pi / _rays + 0.16 * grow + rng.nextDouble() * 0.1;
      final inner = 22 + 30 * grow;
      final outer = 44 + 84 * grow + rng.nextDouble() * 14;
      final half = 0.055 + rng.nextDouble() * 0.03;
      final color = kPartyColors[i % kPartyColors.length]
          .withOpacity((0.55 + rng.nextDouble() * 0.35) * fade);

      final path = Path()
        ..moveTo(c.dx + cos(a) * inner, c.dy + sin(a) * inner)
        ..lineTo(c.dx + cos(a - half) * ((inner + outer) / 2),
            c.dy + sin(a - half) * ((inner + outer) / 2))
        ..lineTo(c.dx + cos(a) * outer, c.dy + sin(a) * outer)
        ..lineTo(c.dx + cos(a + half) * ((inner + outer) / 2),
            c.dy + sin(a + half) * ((inner + outer) / 2))
        ..close();
      canvas.drawPath(path, Paint()..color = color);
    }

    // 4) 飞散的光点，带一点点重力
    for (var i = 0; i < _sparks; i++) {
      final a = rng.nextDouble() * 2 * pi;
      final speed = 70 + rng.nextDouble() * 130;
      final r = speed * grow;
      final p = Offset(
        c.dx + cos(a) * r,
        c.dy + sin(a) * r + 34 * grow * grow,
      );
      final radius = 2.2 + rng.nextDouble() * 4.2;
      canvas.drawCircle(
        p,
        radius,
        Paint()
          ..color = kPartyColors[rng.nextInt(kPartyColors.length)]
              .withOpacity((0.6 + rng.nextDouble() * 0.4) * fade),
      );
    }

    // 5) 几颗四角小星星点缀
    for (var i = 0; i < 5; i++) {
      final a = rng.nextDouble() * 2 * pi;
      final r = (40 + rng.nextDouble() * 70) * grow;
      final star = Offset(c.dx + cos(a) * r, c.dy + sin(a) * r * 0.75);
      _star(canvas, star, 5 + rng.nextDouble() * 5,
          Colors.white.withOpacity(0.9 * fade));
    }
  }

  /// 画一个四角星芽。
  void _star(Canvas canvas, Offset c, double r, Color color) {
    final path = Path();
    const inner = 0.34;
    for (var i = 0; i < 4; i++) {
      final a = i * pi / 2;
      final tip = Offset(c.dx + cos(a) * r, c.dy + sin(a) * r);
      final waist1 = Offset(c.dx + cos(a - pi / 4) * r * inner,
          c.dy + sin(a - pi / 4) * r * inner);
      final waist2 = Offset(c.dx + cos(a + pi / 4) * r * inner,
          c.dy + sin(a + pi / 4) * r * inner);
      if (i == 0) {
        path.moveTo(tip.dx, tip.dy);
      } else {
        path.lineTo(tip.dx, tip.dy);
      }
      path.lineTo(waist1.dx, waist1.dy);
      path.lineTo(waist2.dx, waist2.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_BurstPainter old) =>
      old.t != t || old.fx != fx || old.seed != seed;
}

/// 通关撒花：彩纸从顶部落下，边落边翻转、左右飘。
///
/// 用 `IgnorePointer` 包住，纯装饰，不挡按钮。
class ConfettiRain extends StatefulWidget {
  const ConfettiRain({super.key, this.count = 64});

  final int count;

  @override
  State<ConfettiRain> createState() => _ConfettiRainState();
}

class _ConfettiRainState extends State<ConfettiRain>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..repeat();

  late final List<_Piece> _pieces = _buildPieces(widget.count);

  List<_Piece> _buildPieces(int n) {
    final rng = Random(2026);
    return [
      for (var i = 0; i < n; i++)
        _Piece(
          x: rng.nextDouble(),
          phase: rng.nextDouble(),
          fall: 0.45 + rng.nextDouble() * 0.5,
          sway: 0.5 + rng.nextDouble() * 1.6,
          swayAmp: 10 + rng.nextDouble() * 26,
          spin: (rng.nextBool() ? 1 : -1) * (0.6 + rng.nextDouble() * 2.2),
          w: 6 + rng.nextDouble() * 7,
          h: 4 + rng.nextDouble() * 6,
          color: kPartyColors[rng.nextInt(kPartyColors.length)],
          round: rng.nextDouble() < 0.3,
        ),
    ];
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) =>
              CustomPaint(painter: _ConfettiPainter(_pieces, _c.value)),
        ),
      );
}

class _Piece {
  const _Piece({
    required this.x,
    required this.phase,
    required this.fall,
    required this.sway,
    required this.swayAmp,
    required this.spin,
    required this.w,
    required this.h,
    required this.color,
    required this.round,
  });

  final double x, phase, fall, sway, swayAmp, spin, w, h;
  final Color color;
  final bool round;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.t);

  final List<_Piece> pieces;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    const margin = 40.0;
    final span = size.height + margin * 2;
    for (final p in pieces) {
      final y = ((t * p.fall + p.phase) % 1.0) * span - margin;
      final x =
          p.x * size.width + sin((t * p.sway + p.phase) * 2 * pi) * p.swayAmp;
      // 接近底部时淡出，避免彩纸在底边「凭空消失」
      final fade =
          (1 - ((y - margin) / (span - margin * 2)).clamp(0.0, 1.0) * 0.35);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate((t * p.spin + p.phase) * 2 * pi);
      final paint = Paint()..color = p.color.withOpacity(fade);
      if (p.round) {
        canvas.drawCircle(Offset.zero, p.w / 2, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: p.w, height: p.h),
            const Radius.circular(2),
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
