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

/// 皮球旋转用的四瓣颜色：红、黄、绿、蓝，彼此差别大，转一小步就看得出。
const List<Color> kBallColors = [
  Color(0xFFE53935), // 红
  Color(0xFFFDD835), // 黄
  Color(0xFF43A047), // 绿
  Color(0xFF1E88E5), // 蓝
];

/// 树冠色板：下标按 base 取，都是看着像树叶的绿。
const List<Color> kLeafColors = [
  Color(0xFF43A047), // 绿
  Color(0xFF00796B), // 青绿
  Color(0xFF7CB342), // 黄绿
  Color(0xFF2E7D32), // 深绿
  Color(0xFF827717), // 橄榄
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
        final double box = _boxOf(w, h);

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
          PicKind.pencil => _pencil(box),
          PicKind.tree => _tree(box),
          PicKind.house => _house(box),
          PicKind.tower => _tower(box),
          PicKind.pillar => _pillar(box),
          PicKind.stick => _stick(box),
          PicKind.rod => _rod(box),
          PicKind.trunkWidth => _trunkWidth(box),
          PicKind.pillarWidth => _pillarWidth(box),
          PicKind.ribbon => _ribbon(box),
          PicKind.blob => _blob(box),
          PicKind.balloon => _balloon(box),
          PicKind.dogTree => _dogTree(w, h, scheme),
          PicKind.distance => _distance(box, scheme),
          PicKind.speed => _speed(box, scheme),
          PicKind.depth => _depth(box, scheme),
          PicKind.queue => _queue(w, h, scheme),
          PicKind.place => _place(box, scheme),
          PicKind.clock => _clock(box, scheme),
          PicKind.ballTurn => _ballTurn(box, scheme),
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

  // 长短（铅笔）：横向铅笔，笔身长度随档位增长（0..4）。
  //
  // 笔尖、金属箍、橡皮的尺寸都由 box 定死 —— 比「长短」时只有长短能变。
  // 最短那档也得比「笔尖 + 金属箍 + 橡皮」长（约 0.33box），否则笔身成了负的。
  Widget _pencil(double box) {
    const frac = [0.46, 0.595, 0.73, 0.865, 1.0];
    final lvl = _lvl5(pic.level);
    return SizedBox(
      width: box,
      height: box,
      child: Center(
        child: SizedBox(
          width: box * frac[lvl],
          height: box * 0.16,
          child: CustomPaint(
            painter: _PencilPainter(box: box, color: _barColor()),
          ),
        ),
      ),
    );
  }


  // 高矮（树）：整棵树的高度随档位增长（0 最矮 … 4 最高）。
  //
  // 树干粗细、树冠底宽全由 box 定死 —— 比「高矮」时别的属性不能跟着变。
  // 所有档位都从方框底部长起（同一条地平线），否则没法比高矮。
  Widget _tree(double box) {
    const frac = [0.52, 0.64, 0.76, 0.88, 1.0];
    final w = box * 0.74;
    return SizedBox(
      width: w,
      height: box,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          width: w,
          height: box * frac[_lvl5(pic.level)],
          child: CustomPaint(
            painter: _TreePainter(
              box: box,
              leaf: kLeafColors[_mod(pic.base, kLeafColors.length)],
            ),
          ),
        ),
      ),
    );
  }

  // 粗细（树干）：树冠不动，树干越粗（0 最细 … 4 最粗）。
  //
  // 树冠的大小、离地高度全由 box 定死 —— 比「粗细」时别的属性不能跟着变。
  Widget _trunkWidth(double box) {
    const trunk = [0.06, 0.10, 0.15, 0.21, 0.28];
    final w = box * 0.74;
    return SizedBox(
      width: w,
      height: box,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          width: w,
          height: box * 0.90,
          child: CustomPaint(
            painter: _TreePainter(
              box: box,
              leaf: kLeafColors[_mod(pic.base, kLeafColors.length)],
              trunkWidth: box * trunk[_lvl5(pic.level)],
            ),
          ),
        ),
      ),
    );
  }

  // 高矮（楼）：房子的高度随档位增长（0 最矮 … 4 最高）。
  //
  // 屋顶、门、窗的大小全由 box 定死，且都贴着地面 —— 比「高矮」时只有墙有多高变。
  // 所有档位都站在方框底部（同一条地平线）。
  Widget _house(double box) {
    const frac = [0.62, 0.72, 0.82, 0.91, 1.0];
    final w = box * 0.62;
    return SizedBox(
      width: w,
      height: box,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          width: w,
          height: box * frac[_lvl5(pic.level)],
          child: CustomPaint(
            painter: _HousePainter(box: box, color: _barColor()),
          ),
        ),
      ),
    );
  }

  // 高矮（塔）：塔的高度随档位增长（0 最矮 … 4 最高）。
  //
  // 塔基、屋檐、尖顶都由 box 定死，只有塔身多高变；档位同样站在同一条地平线上。
  Widget _tower(double box) {
    const frac = [0.62, 0.72, 0.82, 0.91, 1.0];
    final w = box * 0.56;
    return SizedBox(
      width: w,
      height: box,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          width: w,
          height: box * frac[_lvl5(pic.level)],
          child: CustomPaint(
            painter: _TowerPainter(box: box, color: _barColor()),
          ),
        ),
      ),
    );
  }

  // 高矮（柱子）：柱子的高度随档位增长（0 最矮 … 4 最高）。
  //
  // 柱头、柱础、柱身粗细都由 box 定死，只有柱身多高变。
  Widget _pillar(double box) {
    const frac = [0.58, 0.69, 0.80, 0.90, 1.0];
    final w = box * 0.60;
    return SizedBox(
      width: w,
      height: box,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          width: w,
          height: box * frac[_lvl5(pic.level)],
          child: CustomPaint(
            painter: _PillarPainter(box: box, color: _barColor()),
          ),
        ),
      ),
    );
  }

  // 粗细（柱子）：柱头、柱础不动，柱身越粗（0 最细 … 4 最粗）。
  Widget _pillarWidth(double box) {
    const shaft = [0.10, 0.19, 0.28, 0.38, 0.48];
    final w = box * 0.60;
    return SizedBox(
      width: w,
      height: box,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          width: w,
          height: box * 0.86,
          child: CustomPaint(
            painter: _PillarPainter(
              box: box,
              color: _barColor(),
              shaftWidth: box * shaft[_lvl5(pic.level)],
            ),
          ),
        ),
      ),
    );
  }

  // 长短（小棒）：横放的小棒，长度随档位增长（0 最短 … 4 最长）。
  //
  // 小棒的粗细（方框高的 0.20）由 box 定死，只有长度变。
  Widget _stick(double box) {
    const frac = [0.34, 0.51, 0.68, 0.85, 1.0];
    return SizedBox(
      width: box,
      height: box,
      child: Center(
        child: SizedBox(
          width: box * frac[_lvl5(pic.level)],
          height: box * 0.20,
          child: CustomPaint(
            painter: _StickPainter(box: box, color: _barColor()),
          ),
        ),
      ),
    );
  }

  // 粗细（小棒）：竖放的小棒，粗细随档位增长（0 最细 … 4 最粗）。
  //
  // 长短（方框高的 0.84）由 box 定死，只有粗细变。
  Widget _rod(double box) {
    const frac = [0.10, 0.18, 0.28, 0.40, 0.54];
    final w = box * frac[_lvl5(pic.level)];
    return SizedBox(
      width: box,
      height: box,
      child: Center(
        child: SizedBox(
          width: w,
          height: box * 0.84,
          child: CustomPaint(
            painter: _RodPainter(box: box, color: _barColor()),
          ),
        ),
      ),
    );
  }

  // 长短（丝带）：丝带长度随档位增长（0 最短 … 4 最长）。
  //
  // 丝带宽度、两端的剪口、中间的蝴蝶结都由 box 定死，只有长度变；
  // 蝴蝶结打在正中间，比挂在右端更像「一条丝带」。
  Widget _ribbon(double box) {
    const frac = [0.34, 0.51, 0.68, 0.85, 1.0];
    return SizedBox(
      width: box,
      height: box,
      child: Center(
        child: SizedBox(
          width: box * frac[_lvl5(pic.level)],
          height: box * 0.40,
          child: CustomPaint(
            painter: _RibbonPainter(box: box, color: _barColor()),
          ),
        ),
      ),
    );
  }

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

  // 胖瘦（气球）：气球的高、气球嘴、绳子都不动，只有胖瘦在变
  // （0 最瘦 … 4 最胖）—— 光画个椭圆看不出是气球，加上嘴和绳就认得出。
  Widget _balloon(double box) {
    const frac = [0.34, 0.44, 0.55, 0.66, 0.78];
    const bodyH = 0.64;
    final color = _barColor();
    final w = box * frac[_lvl5(pic.level)];
    final knot = box * 0.055;
    return SizedBox(
      width: box,
      height: box,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: w,
            height: box * bodyH,
            decoration: BoxDecoration(
              color: color,
              borderRadius:
                  BorderRadius.all(Radius.elliptical(w / 2, box * bodyH / 2)),
            ),
          ),
          Transform.rotate(
            angle: math.pi / 4,
            child: Container(width: knot, height: knot, color: color),
          ),
          Container(
            width: box * 0.012,
            height: box * 0.10,
            color: Color.lerp(color, Colors.black, 0.35),
          ),
        ],
      ),
    );
  }

  // 远近（小狗离树）：树站在左边不动，小狗离它越来越远 —— 间距越来越大、
  // 个头越来越小（近大远小，和 [_distance] 的小球一个道理）。
  //
  // 树的大小和位置按画面定死，每一档都一样：它是孩子比较的基准，动了就没法比。
  // 「间距 + 个头」两个线索一起画，是因为找规律那边一格只有七十来像素宽，只管
  // 间距的话五档只差十几个像素，「越走越远」根本看不出来。
  Widget _dogTree(double w, double h, ColorScheme scheme) {
    // 0 紧挨着树，4 顶到最右边；中间几档均匀分布。
    const gapFrac = [0.0, 0.25, 0.5, 0.75, 1.0];
    const shrink = 0.45; // 最远那档缩到最近那档的 55%
    final lvl = _lvl5(pic.level);
    // 「树 + 最近那只小狗」的自然宽度按高度算，宽度不够就整体等比缩小
    // —— 缩的倍数是各档共用的，所以树在每一档里还是同样大小。
    final k = math.min(1.0, w / (h * 1.02));
    final treeH = h * 0.92 * k;
    final treeW = treeH * 0.55;
    final dog = h * 0.46 * k * (1 - shrink * lvl / 4);
    final gap = w - treeW - dog;
    final ground = scheme.onSurface.withOpacity(0.30);
    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        children: [
          // 地平线：树和小狗都站在它上面。
          Positioned(
            left: 0,
            right: 0,
            top: h - 2,
            child: Container(height: 2, color: ground),
          ),
          Positioned(
            left: 0,
            bottom: 2,
            width: treeW,
            height: treeH,
            child: CustomPaint(
              painter: _TreePainter(
                box: treeH,
                leaf: kLeafColors[_mod(pic.base, kLeafColors.length)],
              ),
            ),
          ),
          Positioned(
            left: treeW + gap * gapFrac[lvl],
            bottom: 2,
            child: _glyph('🐶', dog, photoSide: dog),
          ),
        ],
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
  //
  // 队列是横着摆的，所以按**可用宽度**排，不能只按方格短边 —— 只按短边算的话，
  // 四五只动物挤在一个方格宽里，每只只有二十几像素，实拍照片根本认不出是谁。
  // 每只动物先尽量长得跟题面图一样高（题面图的高度就是 [h]），整排摆不下再按宽度缩。
  Widget _queue(double w, double h, ColorScheme scheme) {
    final row = pic.emojis;
    if (row.isEmpty) return _asset(_boxOf(w, h));
    final n = row.length;
    const overlap = 0.78; // 每只盖住前一只右边 22%，遮挡感就出来了
    final hintH = (h * 0.18).clamp(12.0, 26.0);
    final avail = h - hintH;
    final byWidth = w / (1 + (n - 1) * overlap);
    final item = avail < byWidth ? avail : byWidth;
    final step = item * overlap;
    final total = item + (n - 1) * step;
    final hint = scheme.onSurface.withOpacity(0.55);

    return SizedBox(
      width: total,
      height: h,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: hintH,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('前',
                    style: TextStyle(fontSize: hintH * 0.72, color: hint)),
                Icon(Icons.arrow_forward_rounded,
                    size: hintH * 0.95, color: hint),
              ],
            ),
          ),
          SizedBox(
            height: item,
            width: total,
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

  /// 单个图形可用的方格边长：取宽高里的短边，留一点余量并封顶。
  double _boxOf(double w, double h) {
    final shorter = w < h ? w : h;
    if (shorter > 260.0) return 260.0;
    return shorter < 12.0 ? 12.0 : shorter;
  }

  // 方位：小球在箱子的上面 / 下面 / 左边 / 右边 / 里面。
  //
  // 箱子的边长固定，只有球的位置变 —— 比「在哪里」时箱子跟着变就没法看了。
  Widget _place(double box, ColorScheme scheme) {
    final lvl = _mod(pic.level, 5);
    final side = box * 0.42;
    final ball = box * 0.22;
    final gap = box * 0.06;
    final ballArt = Container(
      width: ball,
      height: ball,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFF43F6E),
      ),
    );
    Widget boxArt() => Container(
          width: side,
          height: side,
          decoration: BoxDecoration(
            // 半透明才看得见「里面」那颗球。
            color: scheme.onSurface.withOpacity(0.16),
            border: Border.all(color: scheme.onSurface.withOpacity(0.55), width: 2),
            borderRadius: BorderRadius.circular(box * 0.07),
          ),
        );
    final art = switch (lvl) {
      0 => Column(
          mainAxisSize: MainAxisSize.min,
          children: [ballArt, SizedBox(height: gap), boxArt()],
        ),
      1 => Column(
          mainAxisSize: MainAxisSize.min,
          children: [boxArt(), SizedBox(height: gap), ballArt],
        ),
      2 => Row(
          mainAxisSize: MainAxisSize.min,
          children: [ballArt, SizedBox(width: gap), boxArt()],
        ),
      3 => Row(
          mainAxisSize: MainAxisSize.min,
          children: [boxArt(), SizedBox(width: gap), ballArt],
        ),
      _ => SizedBox(
          width: side,
          height: side,
          child: Stack(
            alignment: Alignment.center,
            children: [boxArt(), ballArt],
          ),
        ),
    };
    return SizedBox(width: box, height: box, child: Center(child: art));
  }

  // 时钟：时针分针指着整点 / 半点。表盘上只画刻度，不写阿拉伯数字。
  Widget _clock(double box, ColorScheme scheme) {
    final face = scheme.brightness == Brightness.dark
        ? scheme.surfaceContainerHighest
        : Colors.white;
    final d = box * 0.94;
    return SizedBox(
      width: box,
      height: box,
      child: Center(
        child: Container(
          width: d,
          height: d,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: face,
            border:
                Border.all(color: scheme.onSurface.withOpacity(0.55), width: 2),
          ),
          child: CustomPaint(
            painter: _ClockPainter(
              hour: _mod(pic.n, 12),
              minute: pic.level == 0 ? 0 : 30,
              color: scheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  Widget _ballTurn(double box, ColorScheme scheme) {
    final d = box * 0.94;
    return SizedBox(
      width: box,
      height: box,
      child: Center(
        child: SizedBox(
          width: d,
          height: d,
          child: CustomPaint(
            painter: _BallTurnPainter(
              eighth: _mod(pic.level, 8),
              outline: scheme.onSurface.withOpacity(0.45),
            ),
          ),
        ),
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

/// 皮球：四瓣彩色花纹 + 球面高光。花纹跟着 [eighth] 转，高光不动
/// （光一直照在球的左上角，动的是球上的花纹，这样才像球在转）。
class _BallTurnPainter extends CustomPainter {
  _BallTurnPainter({required this.eighth, required this.outline});

  /// 顺时针转过的八分之一圈数，0..7。
  final int eighth;

  final Color outline;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    final c = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: c, radius: r);

    canvas.save();
    canvas.clipPath(Path()..addOval(rect));
    final start = -math.pi / 2 + eighth * math.pi / 4;
    for (var k = 0; k < 4; k++) {
      canvas.drawArc(
        rect,
        start + k * math.pi / 2,
        math.pi / 2,
        true,
        Paint()..color = kBallColors[k % kBallColors.length],
      );
    }
    // 球面明暗：左上亮、右边和下方暗，四瓣花纹才不像一块圆色盘
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.5, -0.5),
          radius: 0.78,
          colors: [
            Colors.white.withOpacity(0.40),
            Colors.white.withOpacity(0.02),
            Colors.black.withOpacity(0.0),
            Colors.black.withOpacity(0.26),
          ],
          stops: const [0.0, 0.38, 0.78, 1.0],
        ).createShader(rect),
    );
    // 左上角一小片柔光（球的反光），跟着光走、不跟着花纹转
    final hl = Rect.fromCenter(
      center: c + Offset(-r * 0.40, -r * 0.46),
      width: r * 0.66,
      height: r * 0.46,
    );
    canvas.drawOval(
      hl,
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.white.withOpacity(0.9), Colors.white.withOpacity(0)],
        ).createShader(hl),
    );
    canvas.restore();

    canvas.drawCircle(
      c,
      r - r * 0.035,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.07
        ..color = outline,
    );
  }

  @override
  bool shouldRepaint(_BallTurnPainter old) =>
      old.eighth != eighth || old.outline != outline;
}

/// 时钟表盘：十二个刻度 + 时针分针。十二点在上，顺时针走。
class _ClockPainter extends CustomPainter {
  _ClockPainter({required this.hour, required this.minute, required this.color});

  /// 小时，0..11（0 就是十二点）。
  final int hour;

  /// 分钟，只支持 0（整点）和 30（半点）。
  final int minute;

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final c = Offset(size.width / 2, size.height / 2);
    final r = s / 2;

    final tick = Paint()..strokeCap = StrokeCap.round;
    for (var i = 0; i < 12; i++) {
      final a = -math.pi / 2 + i * math.pi / 6;
      final big = i % 3 == 0;
      tick
        ..color = color.withOpacity(big ? 0.8 : 0.5)
        ..strokeWidth = big ? s * 0.03 : s * 0.016;
      canvas.drawLine(
        c + Offset(math.cos(a), math.sin(a)) * (r * (big ? 0.70 : 0.80)),
        c + Offset(math.cos(a), math.sin(a)) * (r * 0.88),
        tick,
      );
    }

    final hourAngle = -math.pi / 2 +
        (hour % 12) * math.pi / 6 +
        minute / 60 * math.pi / 6;
    final minuteAngle = -math.pi / 2 + minute * math.pi / 30;
    canvas.drawLine(
      c,
      c + Offset(math.cos(hourAngle), math.sin(hourAngle)) * (r * 0.46),
      Paint()
        ..color = color
        ..strokeCap = StrokeCap.round
        ..strokeWidth = s * 0.055,
    );
    canvas.drawLine(
      c,
      c + Offset(math.cos(minuteAngle), math.sin(minuteAngle)) * (r * 0.70),
      Paint()
        ..color = color
        ..strokeCap = StrokeCap.round
        ..strokeWidth = s * 0.032,
    );
    canvas.drawCircle(c, s * 0.035, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ClockPainter old) =>
      old.hour != hour || old.minute != minute || old.color != color;
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

/// 横向铅笔：橡皮 + 金属箍 + 笔身（颜色随 base）+ 木锥 + 笔芯。
///
/// 画布宽度 = 铅笔全长，[box] 是外层方格边长：除笔身外的部件尺寸全由 box 定死，
/// 这样比「长短」时只有笔身跟着变。
class _PencilPainter extends CustomPainter {
  _PencilPainter({required this.box, required this.color});

  final double box;
  final Color color;

  static const Color _eraserColor = Color(0xFFF06292);
  static const Color _ferruleColor = Color(0xFFB0BEC5);
  static const Color _woodColor = Color(0xFFFFE0B2);
  static const Color _leadColor = Color(0xFF455A64);

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final cy = h / 2;
    final eraser = box * 0.055;
    final ferrule = box * 0.05;
    final cone = box * 0.18;
    final lead = box * 0.055;
    final bodyEnd = size.width - cone;
    final fill = Paint()..isAntiAlias = true;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, eraser, h),
        Radius.circular(h * 0.42),
      ),
      fill..color = _eraserColor,
    );
    canvas.drawRect(
      Rect.fromLTWH(eraser, 0, ferrule, h),
      fill..color = _ferruleColor,
    );
    canvas.drawRect(
      Rect.fromLTWH(eraser + ferrule, 0, bodyEnd - eraser - ferrule, h),
      fill..color = color,
    );
    canvas.drawPath(
      Path()
        ..moveTo(bodyEnd, 0)
        ..lineTo(bodyEnd, h)
        ..lineTo(size.width - lead, cy)
        ..close(),
      fill..color = _woodColor,
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width - lead, h * 0.28)
        ..lineTo(size.width - lead, h * 0.72)
        ..lineTo(size.width, cy)
        ..close(),
      fill..color = _leadColor,
    );
  }

  @override
  bool shouldRepaint(_PencilPainter old) =>
      old.box != box || old.color != color;
}

/// 纵向的树：树干 + 上下两层三角树冠。
///
/// 画布就是树的外接矩形（宽由调用处定死、高随档位变），[box] 是外层方格边长：
/// 树干粗细、树冠底宽都按 box 算，所以只有高度跟着档位走。
class _TreePainter extends CustomPainter {
  _TreePainter({required this.box, required this.leaf, double? trunkWidth})
      : trunkWidth = trunkWidth ?? box * 0.12;

  final double box;
  final Color leaf;

  /// 树干宽度。不传就是按 [box] 算的默认粗细（比高矮时用）。
  final double trunkWidth;

  static const Color _trunkColor = Color(0xFF8D6E63);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final fill = Paint()..isAntiAlias = true;

    // 树干先画，上半截会被树冠盖住。
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH((w - trunkWidth) / 2, h * 0.52, trunkWidth, h * 0.48),
        Radius.circular(trunkWidth * 0.3),
      ),
      fill..color = _trunkColor,
    );

    canvas.drawPath(
      Path()
        ..moveTo(w / 2, h * 0.12)
        ..lineTo(w * 0.02, h * 0.68)
        ..lineTo(w * 0.98, h * 0.68)
        ..close(),
      fill..color = Color.lerp(leaf, Colors.black, 0.22)!,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w / 2, 0)
        ..lineTo(w * 0.16, h * 0.46)
        ..lineTo(w * 0.84, h * 0.46)
        ..close(),
      fill..color = leaf,
    );
  }

  @override
  bool shouldRepaint(_TreePainter old) =>
      old.box != box || old.leaf != leaf || old.trunkWidth != trunkWidth;
}

/// 正面的房子：屋顶 + 墙体 + 门 + 两扇窗。
///
/// 画布 = 房子的外接矩形（宽由调用处定死、高随档位变），[box] 是外层方格边长：
/// 屋顶、门、窗的大小和离地高度都按 box 算，所以只有墙的高度跟着档位走。
class _HousePainter extends CustomPainter {
  _HousePainter({required this.box, required this.color});

  final double box;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final fill = Paint()..isAntiAlias = true;
    final roofH = box * 0.20;
    final wall = Color.lerp(color, Colors.white, 0.62)!;
    final roof = Color.lerp(color, Colors.black, 0.18)!;
    final door = Color.lerp(color, Colors.black, 0.42)!;

    canvas.drawRect(Rect.fromLTWH(0, roofH, w, h - roofH), fill..color = wall);

    // 屋顶比墙宽一点，两侧就是屋檐。
    final eave = w * 1.10;
    canvas.drawPath(
      Path()
        ..moveTo(w / 2, 0)
        ..lineTo(w / 2 - eave / 2, roofH)
        ..lineTo(w / 2 + eave / 2, roofH)
        ..close(),
      fill..color = roof,
    );

    // 门（贴地）与两扇窗（离地高度固定，所以矮房子只是墙少一截）。
    final doorW = box * 0.17;
    final doorH = box * 0.24;
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH((w - doorW) / 2, h - doorH, doorW, doorH),
        topLeft: Radius.circular(doorW * 0.45),
        topRight: Radius.circular(doorW * 0.45),
      ),
      fill..color = door,
    );
    final win = box * 0.12;
    final winY = h - box * 0.36;
    final frame = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = box * 0.014
      ..color = Color.lerp(color, Colors.black, 0.30)!;
    for (final dx in [-box * 0.19, box * 0.19]) {
      final rect = Rect.fromLTWH(w / 2 + dx - win / 2, winY, win, win);
      final rrect =
          RRect.fromRectAndRadius(rect, Radius.circular(win * 0.18));
      canvas.drawRRect(rrect, fill..color = const Color(0xFFFFF8E1));
      canvas.drawRRect(rrect, frame);
    }
  }

  @override
  bool shouldRepaint(_HousePainter old) =>
      old.box != box || old.color != color;
}

/// 塔：塔身（上窄下宽）+ 屋檐 + 尖顶 + 塔基。
///
/// 画布 = 塔的外接矩形（宽由调用处定死、高随档位变），[box] 是外层方格边长：
/// 尖顶、屋檐、塔基都按 box 算，只有塔身高度跟着档位走。
class _TowerPainter extends CustomPainter {
  _TowerPainter({required this.box, required this.color});

  final double box;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final fill = Paint()..isAntiAlias = true;
    final roofH = box * 0.18;
    final plinthH = box * 0.07;
    final body = Color.lerp(color, Colors.black, 0.08)!;
    final roof = Color.lerp(color, Colors.black, 0.42)!;

    // 塔基
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, h - plinthH, w, plinthH),
        Radius.circular(plinthH * 0.3),
      ),
      fill..color = Color.lerp(color, Colors.black, 0.30)!,
    );

    // 塔身：底边略收一点、顶边收得更多，看上去是往上收的。
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.07, h - plinthH)
        ..lineTo(w * 0.93, h - plinthH)
        ..lineTo(w * 0.73, roofH)
        ..lineTo(w * 0.27, roofH)
        ..close(),
      fill..color = body,
    );

    // 尖顶 + 屋檐
    canvas.drawPath(
      Path()
        ..moveTo(w / 2, 0)
        ..lineTo(-w * 0.04, roofH)
        ..lineTo(w * 1.04, roofH)
        ..close(),
      fill..color = roof,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-w * 0.06, roofH - box * 0.015, w * 1.12, box * 0.05),
        Radius.circular(box * 0.02),
      ),
      fill..color = roof,
    );
  }

  @override
  bool shouldRepaint(_TowerPainter old) =>
      old.box != box || old.color != color;
}

/// 柱子：柱头 + 柱础 + 柱身（带两道凹槽）。
///
/// 画布 = 柱子的外接矩形（宽由调用处定死、高随档位变），[box] 是外层方格边长：
/// 柱头、柱础和柱身粗细都按 box 算，只有柱身高度跟着档位走。
class _PillarPainter extends CustomPainter {
  _PillarPainter({required this.box, required this.color, double? shaftWidth})
      : shaftWidth = shaftWidth ?? box * 0.34;

  final double box;
  final Color color;

  /// 柱身宽度。不传就是按 [box] 算的默认粗细（比高矮时用）。
  final double shaftWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final fill = Paint()..isAntiAlias = true;
    final capH = box * 0.05;
    final baseH = box * 0.06;
    final shaftW = shaftWidth;
    final trim = Color.lerp(color, Colors.black, 0.30)!;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, h - baseH, w, baseH),
        Radius.circular(baseH * 0.3),
      ),
      fill..color = trim,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH((w - w * 0.94) / 2, 0, w * 0.94, capH),
        Radius.circular(capH * 0.3),
      ),
      fill..color = trim,
    );

    final sx = (w - shaftW) / 2;
    canvas.drawRect(
      Rect.fromLTWH(sx, capH, shaftW, h - capH - baseH),
      fill..color = color,
    );
    final groove = Paint()
      ..color = Color.lerp(color, Colors.white, 0.45)!
      ..strokeWidth = box * 0.018;
    for (final fx in [0.30, 0.70]) {
      final x = sx + shaftW * fx;
      canvas.drawLine(Offset(x, capH), Offset(x, h - baseH), groove);
    }
  }

  @override
  bool shouldRepaint(_PillarPainter old) =>
      old.box != box || old.color != color || old.shaftWidth != shaftWidth;
}

/// 横放的小棒：两头圆的木棒 + 一道高光 + 右端的断面。
///
/// 画布宽度 = 小棒全长，[box] 是外层方格边长：粗细（画布高度）由调用处按 box
/// 定死，所以比「长短」时只有长度变。
class _StickPainter extends CustomPainter {
  _StickPainter({required this.box, required this.color});

  final double box;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final w = size.width;
    final r = h / 2;
    final fill = Paint()..isAntiAlias = true;

    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h), Radius.circular(r)),
      fill..color = color,
    );
    // 高光：两头留出一段，免得在圆头上露出直角。
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(r * 1.3, h * 0.24, math.max(w - r * 2.6, 1), h * 0.24),
        Radius.circular(h * 0.12),
      ),
      fill..color = Color.lerp(color, Colors.white, 0.55)!,
    );
    // 右端的断面，看着像一根木头。
    canvas.drawCircle(
      Offset(w - r, r),
      r * 0.62,
      fill..color = Color.lerp(color, Colors.black, 0.30)!,
    );
  }

  @override
  bool shouldRepaint(_StickPainter old) =>
      old.box != box || old.color != color;
}

/// 竖放的小棒：两头圆的木棒 + 一道竖高光 + 上下两道竹节。
///
/// 画布高度 = 小棒全长，[box] 是外层方格边长：长短由调用处按 box 定死，
/// 所以比「粗细」时只有宽度变。
class _RodPainter extends CustomPainter {
  _RodPainter({required this.box, required this.color});

  final double box;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final r = w / 2;
    final fill = Paint()..isAntiAlias = true;

    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h), Radius.circular(r)),
      fill..color = color,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.24, r * 1.3, math.max(w * 0.20, 1), h - r * 2.6),
        Radius.circular(w * 0.10),
      ),
      fill..color = Color.lerp(color, Colors.white, 0.50)!,
    );
    final ring = Color.lerp(color, Colors.black, 0.22)!;
    final ringH = math.max(w * 0.10, box * 0.012);
    for (final fy in [0.16, 0.84]) {
      canvas.drawRect(
        Rect.fromLTWH(w * 0.10, h * fy - ringH / 2, w * 0.80, ringH),
        fill..color = ring,
      );
    }
  }

  @override
  bool shouldRepaint(_RodPainter old) =>
      old.box != box || old.color != color;
}

/// 丝带：微微起伏、两端剪成 V 口、正中间打了个蝴蝶结的带子。
///
/// 画布宽度 = 丝带全长，[box] 是外层方格边长：带宽、剪口、起伏、蝴蝶结都按 box 算，
/// 所以比「长短」时只有长度变。
///
/// 蝴蝶结打在两端的正中间、翼比带身浅一号：以前挂在右端、颜色又跟带身几乎一样，
/// 缩到选项格里就是一根亮闪闪的粗条加个疙瘩，像铅笔也像电池；现在两边都露出剪口和
/// 缎面高光，中间一个浅色的结，才认得出是「一条丝带」。
class _RibbonPainter extends CustomPainter {
  _RibbonPainter({required this.box, required this.color});

  final double box;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cy = h / 2;
    final t = box * 0.17; // 带宽，不随档位变
    final notch = t * 0.55; // 两端剪口的深度：浅一点，免得收成个箭头
    final amp = box * 0.035; // 起伏幅度：小到不影响比长短，只让带子看着软
    double band(double x) => cy + amp * math.sin(2 * math.pi * x / w);
    final fill = Paint()
      ..isAntiAlias = true
      ..color = color;

    // 带身：两端剪成 V 口，是它和「小棒」最省事的区别。
    canvas.drawPath(
      Path()
        ..moveTo(0, band(0) - t / 2)
        ..lineTo(notch, band(notch))
        ..lineTo(0, band(0) + t / 2)
        ..lineTo(w - notch, band(w - notch) + t / 2)
        ..lineTo(w, band(w))
        ..lineTo(w - notch, band(w - notch) - t / 2)
        ..close(),
      fill,
    );

    // 缎面高光：贴着上沿的一条细亮线，跟着起伏走，被蝴蝶结隔成左右两段。
    final kx = w / 2;
    for (final seg in [
      [notch + t * 0.6, kx - box * 0.20],
      [kx + box * 0.20, w - notch - t * 0.6],
    ]) {
      if (seg[1] <= seg[0]) continue;
      canvas.drawLine(
        Offset(seg[0], band(seg[0]) - t * 0.22),
        Offset(seg[1], band(seg[1]) - t * 0.22),
        Paint()
          ..isAntiAlias = true
          ..strokeCap = StrokeCap.round
          ..strokeWidth = t * 0.22
          ..color = Color.lerp(color, Colors.white, 0.55)!,
      );
    }

    // 蝴蝶结：上下两片翼 + 中间一道结。
    //
    // 翼画成「帽形」（尖朝结、外边圆平）、比带身浅一号再描一圈深边：缩到选项格里
    // 靠的是一整块轮廓，浅色让两片翼从带身上分出来，不会糊成一个疙瘩。
    final wing = Paint()
      ..isAntiAlias = true
      ..color = Color.lerp(color, Colors.white, 0.30)!;
    final edge = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = box * 0.014
      ..color = Color.lerp(color, Colors.black, 0.38)!;
    final hw = box * 0.11;
    final ht = box * 0.095;
    for (final dir in [-1.0, 1.0]) {
      final loop = Path()
        ..moveTo(kx, cy)
        ..lineTo(kx - hw, cy + dir * ht)
        ..quadraticBezierTo(kx, cy + dir * ht * 1.22, kx + hw, cy + dir * ht)
        ..close();
      canvas.drawPath(loop, wing);
      canvas.drawPath(loop, edge);
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(kx, cy), width: box * 0.085, height: t * 0.78),
        Radius.circular(t * 0.3),
      ),
      fill..color = Color.lerp(color, Colors.black, 0.30)!,
    );
  }

  @override
  bool shouldRepaint(_RibbonPainter old) =>
      old.box != box || old.color != color;
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
