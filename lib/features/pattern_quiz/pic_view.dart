import 'dart:math' as math;

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

/// 纯色块 / 几何图形用的鲜明色板（颜色交替、颜色循环规律）。
const List<Color> kBlockColors = [
  Color(0xFFE53935), // 红
  Color(0xFFFB8C00), // 橙
  Color(0xFFFDD835), // 黄
  Color(0xFF43A047), // 绿
  Color(0xFF1E88E5), // 蓝
  Color(0xFF8E24AA), // 紫
  Color(0xFFEC407A), // 粉
  Color(0xFF00897B), // 青绿
  Color(0xFF6D4C41), // 棕
  Color(0xFF546E7A), // 蓝灰
];

/// 骰子点阵布局：值为每个点的相对位置 (x, y)，范围 0..1。
const Map<int, List<List<double>>> kDiceLayouts = {
  1: [
    [0.5, 0.5],
  ],
  2: [
    [0.28, 0.28],
    [0.72, 0.72],
  ],
  3: [
    [0.26, 0.26],
    [0.5, 0.5],
    [0.74, 0.74],
  ],
  4: [
    [0.28, 0.28],
    [0.72, 0.28],
    [0.28, 0.72],
    [0.72, 0.72],
  ],
  5: [
    [0.28, 0.28],
    [0.72, 0.28],
    [0.5, 0.5],
    [0.28, 0.72],
    [0.72, 0.72],
  ],
  6: [
    [0.28, 0.26],
    [0.72, 0.26],
    [0.28, 0.5],
    [0.72, 0.5],
    [0.28, 0.74],
    [0.72, 0.74],
  ],
};

/// 实拍素材表：这些字形一律换成 `assets/img/qa/` 里的照片来画。
///
/// 换的是「画什么」，不是「怎么排」—— 数量题照样重复 n 张、大小题照样按档缩放、
/// 速度题照样在左侧画速度线、排队题照样相互遮挡，所以题库 JSON 一个字都不用改。
/// 表里没有的字形（数学符号 ➕＝❓、数字等）继续按字形渲染。
const Map<String, String> kEmojiPhotos = {
  '🍎': 'assets/img/qa/apple.jpg',
  '🍌': 'assets/img/qa/banana.jpg',
  '🍇': 'assets/img/qa/grapes.jpg',
  '🍉': 'assets/img/qa/watermelon.jpg',
  '🐶': 'assets/img/qa/dog.jpg',
  '🐱': 'assets/img/qa/cat.jpg',
  '🐻': 'assets/img/qa/bear.jpg',
  '🐼': 'assets/img/qa/panda.jpg',
  '🐰': 'assets/img/qa/rabbit.jpg',
  '🦊': 'assets/img/qa/fox.jpg',
  '🐌': 'assets/img/qa/snail.jpg',
  '🚗': 'assets/img/qa/car.jpg',
  '🚕': 'assets/img/qa/taxi.jpg',
  '🚙': 'assets/img/qa/suv.jpg',
  '⚽': 'assets/img/qa/ball.jpg',
  '🎈': 'assets/img/qa/balloon.jpg',
  '⭐': 'assets/img/qa/star.jpg',
};

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
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth.isFinite ? constraints.maxWidth : 96.0;
        final h = constraints.maxHeight.isFinite ? constraints.maxHeight : 96.0;
        final shorter = w < h ? w : h;
        final double box = shorter > 260.0 ? 260.0 : (shorter < 12.0 ? 12.0 : shorter);

        final Widget art = switch (pic.kind) {
          PicKind.dots => _dots(box),
          PicKind.emojiCount => _glyphs(box, pic.emoji, pic.n > 0 ? pic.n : 1,
              scale: 0.62, photoFraction: 1.0),
          PicKind.emojiSingle => _glyphs(box, pic.emoji, 1, scale: 1.0),
          PicKind.emojiSize =>
            _glyphs(box, pic.emoji, 1, scale: _sizeScale(_level01(pic.level))),
          PicKind.arrowQuarter => _arrow(box, accent),
          PicKind.colorRamp => _ramp(box),
          PicKind.number => _number(box, accent),
          PicKind.shape => _shape(box, accent),
          PicKind.shapeCount => _shapeCount(box),
          PicKind.dice => _dice(box, scheme),
          PicKind.colorBlock => _colorBlock(box),
          PicKind.bar => _bar(box, accent, scheme),
          PicKind.lengthBar => _lengthBar(box),
          PicKind.thickness => _thickness(box),
          PicKind.widthBar => _widthBar(box),
          PicKind.candle => _candle(box),
          PicKind.blob => _blob(box),
          PicKind.distance => _distance(box, scheme),
          PicKind.speed => _speed(box, scheme),
          PicKind.depth => _depth(box, scheme),
          PicKind.queue => _queue(box, scheme),
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

  /// 画 [count] 个 [emoji]：有实拍素材就按方框排照片，否则退回原来的字形串。
  ///
  /// 照片没有字形那样的行高留白，边长直接就是画面尺寸，所以按方框本身来排：
  /// 单个就铺满（大小题按 [photoFraction] 缩档），多个排成近方形的网格
  /// —— 并排 count 张的话每张只有 box/count 宽，方框上下都空着。
  ///
  /// [scale] 只作用于字形串。[photoFraction] 缺省与 [scale] 同档（大小题要的
  /// 就是这个），而数量题的 0.62 是给字形串留的，照片要铺满得显式给 1.0。
  Widget _glyphs(double box, String emoji, int count,
      {required double scale, double? photoFraction}) {
    final path = kEmojiPhotos[emoji];
    if (path == null) return _text(box, emoji * count, scale: scale);
    final side = box * 0.92 * (photoFraction ?? scale);
    if (count <= 1) return _photo(path, side, emoji);

    final cols = math.sqrt(count).ceil();
    final rows = (count / cols).ceil();
    final unit = side / math.max(cols, rows);
    final gap = unit * 0.08;
    return SizedBox(
      width: box,
      height: box,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var r = 0; r < rows; r++) ...[
              if (r > 0) SizedBox(height: gap),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var c = 0; c < cols; c++) ...[
                    if (c > 0) SizedBox(width: gap),
                    // 空位补上等大的占位，几个并排的格子才对得齐（好数）。
                    if (r * cols + c < count)
                      _photo(path, unit, emoji)
                    else
                      SizedBox(width: unit, height: unit),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 单个字形：有实拍素材就画照片，否则画字形本身。
  ///
  /// 照片边长默认按字号推 2 倍 —— 字号只有画面高度的一半左右，照片直接给字号
  /// 就只占半格。调用处外面有 FittedBox 的（速度题、排队题）会再缩到实际可用
  /// 范围，所以给大了不会溢出。
  Widget _glyph(String emoji, double size, {double? photoSide}) {
    final path = kEmojiPhotos[emoji];
    if (path == null) return Text(emoji, style: TextStyle(fontSize: size));
    return _photo(path, photoSide ?? size * 2, emoji);
  }

  /// 单个素材：边长由调用方按方框算好（照片不跟着字形字号走）。加载失败退回字形。
  Widget _photo(String path, double side, String emoji) {
    return SizedBox(
      width: side,
      height: side,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(side * 0.18),
        child: Image.asset(
          path,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => FittedBox(
            child: Text(emoji, style: TextStyle(fontSize: side * 0.9)),
          ),
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

  Widget _number(double box, Color accent) {
    return SizedBox(
      width: box,
      height: box,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          '${pic.n}',
          style: TextStyle(
            fontSize: box * 0.68,
            fontWeight: FontWeight.w800,
            color: accent,
            height: 1.0,
          ),
        ),
      ),
    );
  }

  Widget _shape(double box, Color accent) {
    final color = kBlockColors[_mod(pic.base + 4, kBlockColors.length)];
    return SizedBox(
      width: box,
      height: box,
      child: CustomPaint(
        painter: _ShapePainter(
          shape: pic.base,
          color: color,
          turns: _mod(pic.level, 4),
        ),
      ),
    );
  }

  Widget _shapeCount(double box) {
    final color = kBlockColors[_mod(pic.level, kBlockColors.length)];
    final count = pic.n > 0 ? pic.n : 1;
    return SizedBox(
      width: box,
      height: box,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < count; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: CustomPaint(
                    painter:
                        _ShapePainter(shape: pic.base, color: color, turns: 0),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _dice(double box, ColorScheme scheme) {
    final n = pic.n.clamp(1, 6);
    final layout = kDiceLayouts[n]!;
    final fill = scheme.brightness == Brightness.dark
        ? scheme.surfaceContainerHighest
        : Colors.white;
    return SizedBox(
      width: box,
      height: box,
      child: Container(
        decoration: BoxDecoration(
          color: fill,
          border: Border.all(color: kDotColors[0], width: 2),
          borderRadius: BorderRadius.circular(box * 0.18),
        ),
        child: LayoutBuilder(
          builder: (context, c) {
            final d = math.min(c.maxWidth, c.maxHeight) * 0.2;
            return Stack(
              children: [
                for (final p in layout)
                  Positioned(
                    left: p[0] * (c.maxWidth - d),
                    top: p[1] * (c.maxHeight - d),
                    child: Container(
                      width: d,
                      height: d,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF3D7BFF),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _colorBlock(double box) {
    final color = kBlockColors[_mod(pic.base, kBlockColors.length)];
    return Container(
      width: box,
      height: box,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(box * 0.2),
      ),
    );
  }

  Widget _bar(double box, Color accent, ColorScheme scheme) {
    const maxUnits = 5;
    final units = pic.n.clamp(1, maxUnits);
    final frac = units / maxUnits;
    final track = scheme.brightness == Brightness.dark
        ? scheme.surfaceContainerHighest
        : Colors.black.withOpacity(0.06);
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: box * 0.66,
        height: box,
        padding: EdgeInsets.all(box * 0.05),
        decoration: BoxDecoration(
          color: track,
          borderRadius: BorderRadius.circular(box * 0.12),
        ),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: FractionallySizedBox(
            heightFactor: frac,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(box * 0.09),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 属性档位裁剪到 0..4。
  int _lvl5(int v) => v < 0 ? 0 : (v > 4 ? 4 : v);

  /// 属性条用的颜色（按 base 从鲜明色板取）。
  Color _barColor() => kBlockColors[_mod(pic.base, kBlockColors.length)];

  // 长短：横向长条，长度随档位增长（0..4）。
  Widget _lengthBar(double box) {
    const frac = [0.22, 0.40, 0.58, 0.78, 1.0];
    final color = _barColor();
    return SizedBox(
      width: box,
      height: box,
      child: Center(
        child: Container(
          width: box * frac[_lvl5(pic.level)],
          height: box * 0.26,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(box * 0.13),
          ),
        ),
      ),
    );
  }

  // 厚薄：横向薄板，厚度随档位增长（0..4）。
  Widget _thickness(double box) {
    const frac = [0.07, 0.15, 0.24, 0.35, 0.48];
    final color = _barColor();
    return SizedBox(
      width: box,
      height: box,
      child: Center(
        child: Container(
          width: box * 0.92,
          height: box * frac[_lvl5(pic.level)],
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(box * 0.07),
          ),
        ),
      ),
    );
  }

  // 粗细：竖向圆棒，宽度随档位增长（0..4）。
  Widget _widthBar(double box) {
    const frac = [0.10, 0.18, 0.28, 0.40, 0.54];
    final color = _barColor();
    final w = box * frac[_lvl5(pic.level)];
    return SizedBox(
      width: box,
      height: box,
      child: Center(
        child: Container(
          width: w,
          height: box * 0.84,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(w / 2),
          ),
        ),
      ),
    );
  }

  // 粗细（蜡烛）：蜡烛身子的宽度随档位增长（0..4）。
  //
  // 火苗、灯芯、身高都不跟着变 —— 比「粗细」时只有粗细能变，否则成了比高矮。
  Widget _candle(double box) {
    const frac = [0.15, 0.25, 0.37, 0.50, 0.64];
    final lvl = _lvl5(pic.level);
    final color = _barColor();
    final w = box * frac[lvl];
    return SizedBox(
      width: box,
      height: box,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: box * 0.15,
              height: box * 0.19,
              child: CustomPaint(painter: _FlamePainter()),
            ),
            Container(
              width: box * 0.035,
              height: box * 0.06,
              color: const Color(0xFF6D4C41),
            ),
            Container(
              width: w,
              height: box * 0.66,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(w * 0.5),
                  bottom: Radius.circular(w * 0.12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 胖瘦：椭圆（高度固定），宽度随档位增长（0..4）。
  Widget _blob(double box) {
    const frac = [0.30, 0.45, 0.62, 0.80, 0.96];
    final color = _barColor();
    final w = box * frac[_lvl5(pic.level)];
    const h = 0.74;
    return SizedBox(
      width: box,
      height: box,
      child: Center(
        child: Container(
          width: w,
          height: box * h,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.all(
              Radius.elliptical(w / 2, box * h / 2),
            ),
          ),
        ),
      ),
    );
  }

  // 远近：地平线上的小球，越远越小、越向上（0 最近 .. 4 最远）。
  Widget _distance(double box, ColorScheme scheme) {
    const dia = [0.44, 0.34, 0.25, 0.17, 0.11];
    const cy = [0.80, 0.70, 0.60, 0.51, 0.43];
    final lvl = _lvl5(pic.level);
    final d = box * dia[lvl];
    final color = _barColor();
    final line = scheme.onSurface.withOpacity(0.30);
    Widget ground(double top, double thickness) => Positioned(
          left: box * 0.06,
          right: box * 0.06,
          top: box * top,
          child: Container(height: thickness, color: line),
        );
    return SizedBox(
      width: box,
      height: box,
      child: Stack(
        children: [
          ground(0.34, 1.2), // 地平线
          ground(0.94, 1.6), // 地面
          Positioned(
            left: box * 0.5 - d / 2,
            top: box * cy[lvl] - d / 2,
            child: Container(
              width: d,
              height: d,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
          ),
        ],
      ),
    );
  }

  // 快慢：物体身后的速度线，档位越高线越多越长。
  Widget _speed(double box, ColorScheme scheme) {
    final lvl = _lvl5(pic.level);
    final color = _barColor();
    final streaks = lvl + 1; // 1..5 条
    return SizedBox(
      width: box,
      height: box,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: box * 0.30,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < streaks; i++)
                  Container(
                    width: box * (0.12 + 0.05 * lvl) * (1 - 0.12 * i),
                    height: box * 0.045,
                    margin: EdgeInsets.symmetric(vertical: box * 0.03),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.85 - 0.1 * i),
                      borderRadius: BorderRadius.circular(box * 0.03),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: _glyph(pic.emoji.isEmpty ? '🚗' : pic.emoji, box * 0.5,
                  photoSide: box * 0.9),
            ),
          ),
        ],
      ),
    );
  }

  // 深浅：杯子里的水，水位随档位升高。
  Widget _depth(double box, ColorScheme scheme) {
    const frac = [0.12, 0.28, 0.46, 0.66, 0.84];
    final lvl = _lvl5(pic.level);
    final water = _barColor();
    final wall = scheme.onSurface.withOpacity(0.45);
    return SizedBox(
      width: box,
      height: box,
      child: Center(
        child: Container(
          width: box * 0.62,
          height: box * 0.84,
          padding: EdgeInsets.all(box * 0.05),
          decoration: BoxDecoration(
            border: Border.all(color: wall, width: 2),
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(box * 0.14),
            ),
          ),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: frac[lvl],
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: water,
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(box * 0.09),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 前后：一队小动物依次遮挡，右边是前面，越靠前挡得越完整。
  Widget _queue(double box, ColorScheme scheme) {
    final row = pic.emojis;
    if (row.isEmpty) return _asset(box);
    final n = row.length;
    final item = box / (1 + (n - 1) * 0.78);
    final step = item * 0.78;
    final hint = scheme.onSurface.withOpacity(0.55);

    return SizedBox(
      width: box,
      height: box,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: EdgeInsets.only(left: box * 0.55, bottom: box * 0.04),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('前', style: TextStyle(fontSize: box * 0.12, color: hint)),
                Icon(Icons.arrow_forward_rounded, size: box * 0.16, color: hint),
              ],
            ),
          ),
          SizedBox(
            height: item,
            width: box,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // 从左到右依次绘制：后画的在上一层，自然形成「前面的挡住后面的」。
                for (var i = 0; i < n; i++)
                  Positioned(
                    left: i * step,
                    top: 0,
                    width: item,
                    height: item,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: _glyph(row[i], item * 0.9),
                    ),
                  ),
              ],
            ),
          ),
        ],
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

/// 蜡烛火苗：水滴形，外焰橙、内焰黄。
class _FlamePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final flame = Path()
      ..moveTo(w / 2, 0)
      ..cubicTo(w, h * 0.46, w * 0.9, h, w / 2, h)
      ..cubicTo(w * 0.1, h, 0, h * 0.46, w / 2, 0)
      ..close();
    canvas.drawPath(
      flame,
      Paint()
        ..color = const Color(0xFFFF9800)
        ..isAntiAlias = true,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w / 2, h * 0.70),
        width: w * 0.44,
        height: h * 0.42,
      ),
      Paint()
        ..color = const Color(0xFFFFE082)
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(_FlamePainter oldDelegate) => false;
}

/// 绘制内置几何图形，可绕中心旋转 90° 的整数倍。
class _ShapePainter extends CustomPainter {
  _ShapePainter({required this.shape, required this.color, required this.turns});

  final int shape;
  final Color color;
  final int turns;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    if (turns != 0) canvas.rotate(turns * math.pi / 2);
    canvas.drawPath(_pathFor(shape % 9, s), paint);
    canvas.restore();
  }

  Path _pathFor(int shape, double s) {
    final h = s / 2;
    switch (shape) {
      case 0: // 圆形
        return Path()
          ..addOval(Rect.fromCircle(center: Offset.zero, radius: h));
      case 1: // 正方形（圆角）
        return Path()
          ..addRRect(RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: s, height: s),
            Radius.circular(s * 0.14),
          ));
      case 2: // 三角形（尖朝上）
        return Path()
          ..moveTo(0, -h)
          ..lineTo(h * 0.92, h * 0.78)
          ..lineTo(-h * 0.92, h * 0.78)
          ..close();
      case 3: // 五角星
        return _star(h, h * 0.44);
      case 4: // 爱心
        return _heart(s);
      case 5: // 菱形
        return Path()
          ..moveTo(0, -h)
          ..lineTo(h, 0)
          ..lineTo(0, h)
          ..lineTo(-h, 0)
          ..close();
      case 6: // 五边形
        return _regular(h, 5);
      case 7: // 六边形
        return _regular(h, 6);
      default: // 十字
        final t = s * 0.17;
        return Path()
          ..fillType = PathFillType.nonZero
          ..addRect(Rect.fromLTRB(-t, -h, t, h))
          ..addRect(Rect.fromLTRB(-h, -t, h, t));
    }
  }

  Path _star(double outer, double inner) {
    final p = Path();
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? outer : inner;
      final a = -math.pi / 2 + i * math.pi / 5;
      final x = math.cos(a) * r;
      final y = math.sin(a) * r;
      if (i == 0) {
        p.moveTo(x, y);
      } else {
        p.lineTo(x, y);
      }
    }
    return p..close();
  }

  Path _heart(double s) {
    return Path()
      ..moveTo(0, s * 0.4)
      ..cubicTo(-s * 0.78, -s * 0.08, -s * 0.42, -s * 0.66, 0, -s * 0.22)
      ..cubicTo(s * 0.42, -s * 0.66, s * 0.78, -s * 0.08, 0, s * 0.4)
      ..close();
  }

  Path _regular(double r, int sides) {
    final p = Path();
    for (var i = 0; i < sides; i++) {
      final a = -math.pi / 2 + i * 2 * math.pi / sides;
      final x = math.cos(a) * r;
      final y = math.sin(a) * r;
      if (i == 0) {
        p.moveTo(x, y);
      } else {
        p.lineTo(x, y);
      }
    }
    return p..close();
  }

  @override
  bool shouldRepaint(_ShapePainter old) =>
      old.shape != shape || old.color != color || old.turns != turns;
}
