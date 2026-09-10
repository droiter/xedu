import 'package:flutter/material.dart';

import 'pattern_quiz_models.dart';

/// 圆点数量用的调色板（按 base 下标取色）。
const List<Color> kDotColors = [
  Color(0xFF3D7BFF), // 蓝
  Color(0xFF00BFA5), // 青
  Color(0xFFF59E0B), // 橙
  Color(0xFF9A5CF5), // 紫
  Color(0xFFF43F6E), // 玫红
];

/// 色阶调色板：下标 0..4 = 蓝 / 青绿 / 橙 / 紫 / 粉，每组由浅到深 4 档。
const List<List<Color>> kRampPalettes = [
  [
    Color(0xFFC9DDFF),
    Color(0xFF6FA0FF),
    Color(0xFF2E6BFF),
    Color(0xFF0A2B8C),
  ],
  [
    Color(0xFFC9F7E8),
    Color(0xFF5BD9A9),
    Color(0xFF0FA47A),
    Color(0xFF05603F),
  ],
  [
    Color(0xFFFFE6BF),
    Color(0xFFFFB84D),
    Color(0xFFF57C00),
    Color(0xFF9C3D00),
  ],
  [
    Color(0xFFE6D9FF),
    Color(0xFFB48CFF),
    Color(0xFF7B3FFF),
    Color(0xFF3B1B8F),
  ],
  [
    Color(0xFFFFD9E0),
    Color(0xFFFF7B96),
    Color(0xFFF22E5B),
    Color(0xFF8F0F2B),
  ],
];

/// 一个 [Pic] 元素的自适应渲染：在给定的方格内居中绘制对应图片 / 图形。
class PicView extends StatelessWidget {
  const PicView({super.key, required this.pic, this.color});

  final Pic pic;

  /// 强调色（箭头等），缺省使用主题主色。
  final Color? color;

  int _mod(int v, int m) => ((v % m) + m) % m;

  int _level01(int v) => v < 0 ? 0 : (v > 3 ? 3 : v);

  @override
  Widget build(BuildContext context) {
    final accent = color ?? Theme.of(context).colorScheme.primary;
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth.isFinite ? constraints.maxWidth : 96.0;
        final h = constraints.maxHeight.isFinite ? constraints.maxHeight : 96.0;
        final shorter = w < h ? w : h;
        final double box = shorter > 260.0 ? 260.0 : (shorter < 12.0 ? 12.0 : shorter);

        final Widget art = switch (pic.kind) {
          PicKind.dots => _dots(box),
          PicKind.emojiCount =>
            _text(box, pic.emoji * (pic.n > 0 ? pic.n : 1), scale: 0.62),
          PicKind.emojiSingle => _text(box, pic.emoji, scale: 1.0),
          PicKind.emojiSize =>
            _text(box, pic.emoji, scale: _sizeScale(_level01(pic.level))),
          PicKind.arrowQuarter => _arrow(box, accent),
          PicKind.colorRamp => _ramp(box),
          PicKind.asset => _asset(box),
        };
        return Center(child: art);
      },
    );
  }

  double _sizeScale(int level) {
    const scales = [0.5, 0.63, 0.78, 1.0];
    return scales[level];
  }

  Widget _dots(double box) {
    final color = kDotColors[_mod(pic.base, kDotColors.length)];
    final count = pic.n > 0 ? pic.n : 1;
    return SizedBox(
      width: box,
      height: box,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          '●' * count,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color,
            fontSize: box * 0.32,
            height: 1.1,
          ),
        ),
      ),
    );
  }

  Widget _text(double box, String glyph, {required double scale}) {
    return SizedBox(
      width: box,
      height: box,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          glyph,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: box * 0.5 * scale),
        ),
      ),
    );
  }

  Widget _arrow(double box, Color accent) {
    final turns = _mod(pic.level, 4);
    return SizedBox(
      width: box,
      height: box,
      child: RotatedBox(
        quarterTurns: turns,
        child: Icon(Icons.arrow_upward_rounded, size: box * 0.6, color: accent),
      ),
    );
  }

  Widget _ramp(double box) {
    final palette = kRampPalettes[_mod(pic.base, kRampPalettes.length)];
    final color = palette[_level01(pic.level)];
    return Container(
      width: box,
      height: box,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(box * 0.2),
      ),
    );
  }

  Widget _asset(double box) {
    return Container(
      width: box,
      height: box,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(box * 0.2),
      ),
      child: Icon(Icons.image_outlined, size: box * 0.45, color: Colors.black38),
    );
  }
}
