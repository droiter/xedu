import 'package:flutter/foundation.dart';

/// 图片 / 动画元素的渲染类型。
///
/// 演示内容全部用 Flutter 内置矢量绘制（圆点 / emoji / 色块 / 几何图形），
/// 无需任何图片资源。若之后要换成自己的真实图片，新增元素使用 [Pic.asset]
/// 并把文件放进 `assets/`。
enum PicKind {
  /// 一排「●」圆点，数量变化形成规律（数量递增 / 递减）。
  dots,

  /// 同一 emoji 重复 n 次（例如 3 个苹果）。
  emojiCount,

  /// 单个大 emoji（类别辨认、序列交替）。
  emojiSingle,

  /// 同一 emoji 按档位放大缩小（大小递增 / 递减）。
  emojiSize,

  /// 朝向上 / 右 / 下 / 左的箭头（方向旋转规律）。
  arrowQuarter,

  /// 同一色系的色块深浅变化（颜色由浅到深 / 由深到浅）。
  colorRamp,

  /// 阿拉伯数字（数列找规律，例如 2 4 6 8）。
  number,

  /// 单个几何图形。[Pic.base] 是图形编号，[Pic.level] 是旋转的 90° 格数。
  shape,

  /// n 个同一几何图形。[Pic.base] 是图形编号，[Pic.level] 是颜色编号。
  shapeCount,

  /// 骰子点数（1..6），点阵布局体现数量 / 点数规律。
  dice,

  /// 纯色块（颜色交替、颜色循环规律）。
  colorBlock,

  /// 柱状条，[Pic.n] 为高度档数（阶梯 / 生长规律，也用于「高矮」）。
  bar,

  /// 长短：横向长条，[Pic.level] 为长度档（0 最短 … 4 最长）。
  lengthBar,

  /// 厚薄：横向薄板，[Pic.level] 为厚度档（0 最薄 … 4 最厚）。
  thickness,

  /// 粗细：竖向圆棒，[Pic.level] 为粗细档（0 最细 … 4 最粗）。
  widthBar,

  /// 粗细（蜡烛）：蜡烛身子的粗细随档位变化（0 最细 … 4 最粗），火苗大小不变。
  candle,

  /// 胖瘦：椭圆，[Pic.level] 为胖瘦档（0 最瘦 … 4 最胖）。
  blob,

  /// 远近：地平线上的小球，[Pic.level] 为远近档（0 最近 … 4 最远）。
  distance,

  /// 快慢：物体身后的速度线，[Pic.level] 为速度档（0 最慢 … 4 最快）。
  speed,

  /// 深浅：杯子里的水，[Pic.level] 为水位档（0 最浅 … 4 最深）。
  depth,

  /// 前后：一队小动物依次遮挡，[Pic.emojis] 从左到右 = 从最后面到最前面。
  queue,

  /// 方位：小球在箱子的上面 / 下面 / 左边 / 右边 / 里面，[Pic.level] 为方位编号。
  place,

  /// 时钟：时针分针指着整点或半点，[Pic.n] 为小时（1..12），[Pic.level] 0 整点 1 半点。
  clock,

  /// 外部图片资源（预留，需要配合 pubspec.yaml 的 assets 目录）。
  asset,
}

/// 方位的名字，下标与 [Pic.place] 的 level 对应。
const List<String> kPlaceNames = ['上面', '下面', '左边', '右边', '里面'];

/// 几何图形的中文名，下标与 [Pic.shape] / [Pic.shapeCount] 的 base 对应。
const List<String> kShapeNames = [
  '圆形', '正方形', '三角形', '五角星', '爱心', '菱形', '五边形', '六边形', '十字',
];

/// 一个可显示的「图片 / 动画」元素。
///
/// [id] 是唯一身份标识，用于判定答案是否正确；同一个 id 一定渲染成同一张图。
@immutable
class Pic {
  const Pic({
    required this.kind,
    required this.id,
    this.emoji = '',
    this.n = 0,
    this.level = 0,
    this.base = 0,
    this.path = '',
    this.label,
    this.emojis = const [],
  });

  final PicKind kind;
  final String id;

  /// emoji 字面量（emojiCount / emojiSingle / emojiSize 用）。
  final String emoji;

  /// 数量（dots / emojiCount / shapeCount / dice / bar 用）。
  final int n;

  /// 档位：emojiSize 的大小档、arrowQuarter 的朝向(0上 1右 2下 3左)、
  /// colorRamp 的深浅档、shape 的旋转格数、shapeCount 的颜色编号，
  /// 以及 lengthBar/thickness/widthBar/candle/blob/distance 的属性档（0..4）。
  final int level;

  /// 底座下标：dots / colorRamp 的调色板编号、shape/shapeCount 的图形编号、
  /// colorBlock 与各属性条（含 candle）的颜色编号。
  final int base;

  /// 资源路径（asset 类型用）。
  final String path;

  /// 选项上的文字说明（可选）。
  final String? label;

  /// 队列（[PicKind.queue] 用），从左到右 = 从最后面到最前面。
  final List<String> emojis;

  static Pic dots(int count, {int base = 0}) => Pic(
        kind: PicKind.dots,
        id: 'dots:$count@$base',
        n: count,
        base: base,
        label: '$count 个点',
      );

  static Pic emojiCount(String emoji, int count) => Pic(
        kind: PicKind.emojiCount,
        id: 'ec:$emoji@$count',
        emoji: emoji,
        n: count,
        label: '$count 个 $emoji',
      );

  static Pic emojiSingle(String emoji) => Pic(
        kind: PicKind.emojiSingle,
        id: 'es:$emoji',
        emoji: emoji,
      );

  static Pic emojiSize(String emoji, int level) => Pic(
        kind: PicKind.emojiSize,
        id: 'ez:$emoji@$level',
        emoji: emoji,
        level: level,
      );

  static Pic arrowQuarter(int quarter) => Pic(
        kind: PicKind.arrowQuarter,
        id: 'arrow:$quarter',
        level: quarter,
        label: const ['朝上', '朝右', '朝下', '朝左'][quarter & 3],
      );

  static Pic colorRamp(int base, int level) => Pic(
        kind: PicKind.colorRamp,
        id: 'ramp:$base:$level',
        base: base,
        level: level,
        label: '颜色',
      );

  /// 阿拉伯数字（数列题）。
  static Pic number(int value) => Pic(
        kind: PicKind.number,
        id: 'num:$value',
        n: value,
        label: '$value',
      );

  /// 单个几何图形。[quarter] 是顺时针 90° 的格数。
  static Pic shape(int shape, {int quarter = 0}) => Pic(
        kind: PicKind.shape,
        id: 'shp:$shape@$quarter',
        base: shape,
        level: quarter,
        label: kShapeNames[shape % kShapeNames.length],
      );

  /// [count] 个同一几何图形。
  static Pic shapeCount(int shape, int count, {int color = 0}) => Pic(
        kind: PicKind.shapeCount,
        id: 'shc:$shape@$count:$color',
        base: shape,
        n: count,
        level: color,
        label: '$count 个${kShapeNames[shape % kShapeNames.length]}',
      );

  /// 骰子点数 1..6。
  static Pic dice(int count) => Pic(
        kind: PicKind.dice,
        id: 'dice:$count',
        n: count,
        label: '$count 点',
      );

  /// 纯色块。
  static Pic colorBlock(int color) => Pic(
        kind: PicKind.colorBlock,
        id: 'blk:$color',
        base: color,
        label: '色块',
      );

  /// 柱状条，[units] 为高度档数。
  static Pic bar(int units) => Pic(
        kind: PicKind.bar,
        id: 'bar:$units',
        n: units,
        label: '高度 $units',
      );

  /// 长短：横向长条。[level] 0 最短 … 4 最长；[base] 为颜色编号。
  static Pic lengthBar(int level, {int base = 0}) => Pic(
        kind: PicKind.lengthBar,
        id: 'len:$base:$level',
        level: level,
        base: base,
        label: '长短',
      );

  /// 厚薄：横向薄板。[level] 0 最薄 … 4 最厚；[base] 为颜色编号。
  static Pic thickness(int level, {int base = 0}) => Pic(
        kind: PicKind.thickness,
        id: 'thk:$base:$level',
        level: level,
        base: base,
        label: '厚薄',
      );

  /// 粗细：竖向圆棒。[level] 0 最细 … 4 最粗；[base] 为颜色编号。
  static Pic widthBar(int level, {int base = 0}) => Pic(
        kind: PicKind.widthBar,
        id: 'wid:$base:$level',
        level: level,
        base: base,
        label: '粗细',
      );

  /// 粗细（蜡烛）：蜡烛身子的粗细随档位增长。
  /// [level] 0 最细 … 4 最粗；[base] 为颜色编号。
  static Pic candle(int level, {int base = 0}) => Pic(
        kind: PicKind.candle,
        id: 'cnd:$base:$level',
        level: level,
        base: base,
        label: '粗细',
      );

  /// 胖瘦：椭圆。[level] 0 最瘦 … 4 最胖；[base] 为颜色编号。
  static Pic blob(int level, {int base = 0}) => Pic(
        kind: PicKind.blob,
        id: 'blob:$base:$level',
        level: level,
        base: base,
        label: '胖瘦',
      );

  /// 远近：地平线上的小球。[level] 0 最近 … 4 最远；[base] 为颜色编号。
  static Pic distance(int level, {int base = 0}) => Pic(
        kind: PicKind.distance,
        id: 'dist:$base:$level',
        level: level,
        base: base,
        label: '远近',
      );

  /// 快慢：物体 + 速度线。[level] 0 最慢 … 4 最快；[emoji] 是被比较的物体。
  static Pic speed(int level, {String emoji = '🚗', int base = 0}) => Pic(
        kind: PicKind.speed,
        id: 'spd:$emoji:$base:$level',
        level: level,
        emoji: emoji,
        base: base,
        label: '速度 $level',
      );

  /// 深浅：杯子里的水。[level] 0 最浅 … 4 最深；[base] 为水色编号。
  static Pic depth(int level, {int base = 0}) => Pic(
        kind: PicKind.depth,
        id: 'dep:$base:$level',
        level: level,
        base: base,
        label: '水深 $level',
      );

  /// 前后：一队不同的小动物，列表从左到右 = 从最后面到最前面。
  static Pic queue(List<String> emojis) => Pic(
        kind: PicKind.queue,
        id: 'q:${emojis.join()}',
        emojis: emojis,
        label: '排队',
      );

  /// 方位：小球在箱子的什么地方。[level] 0 上面 1 下面 2 左边 3 右边 4 里面。
  static Pic place(int level) => Pic(
        kind: PicKind.place,
        id: 'plc:$level',
        level: level,
        label: kPlaceNames[level % kPlaceNames.length],
      );

  /// 时钟。[hour] 是小时（1..12），[minute] 只支持 0 和 30（整点 / 半点）。
  ///
  /// 表盘上只画刻度不写数字 —— 题面文字和选项文字都不许出现阿拉伯数字，
  /// 钟面上写了数字就成了另一回事。
  static Pic clock(int hour, {int minute = 0}) => Pic(
        kind: PicKind.clock,
        id: 'clk:$hour:$minute',
        n: hour,
        level: minute == 0 ? 0 : 1,
        label: minute == 0 ? '$hour 点' : '$hour 点半',
      );

  /// 队伍里的第 [index] 位（0 = 最后面）。
  String queueAt(int index) =>
      emojis.isEmpty ? '' : emojis[index % emojis.length];

  static Pic asset(String path, {String? label}) => Pic(
        kind: PicKind.asset,
        id: 'asset:$path',
        path: path,
        label: label ?? '图片',
      );
}

/// 题库按年龄分层：每个年龄档位提供难度合适的题型。
enum PatternAgeGroup {
  /// 2–3 岁：找一样、认颜色、最大最简单的交替。
  baby,

  /// 3–4 岁：大小、颜色、简单交替。
  toddler,

  /// 5–6 岁：数量增减、方向、阶梯、深浅。
  preschool,

  /// 7–8 岁：数列、图形旋转、组合规律。
  lowerGrade,

  /// 9–10 岁：等差 / 等比数列、二维规律。
  upperGrade,

  /// 「100 岁」：4 格图里规律只重复一次、孩子没法归纳的题先挪到这里暂存。
  hundred,
}

extension PatternAgeGroupX on PatternAgeGroup {
  /// 年龄区间文案。
  String get ageText => switch (this) {
        PatternAgeGroup.baby => '2–3 岁',
        PatternAgeGroup.toddler => '3–4 岁',
        PatternAgeGroup.preschool => '5–6 岁',
        PatternAgeGroup.lowerGrade => '7–8 岁',
        PatternAgeGroup.upperGrade => '9–10 岁',
        PatternAgeGroup.hundred => '100 岁',
      };

  /// 学段名称。
  String get stageName => switch (this) {
        PatternAgeGroup.baby => '亲子启蒙',
        PatternAgeGroup.toddler => '幼儿启蒙',
        PatternAgeGroup.preschool => '学前预备',
        PatternAgeGroup.lowerGrade => '小学低年级',
        PatternAgeGroup.upperGrade => '小学高年级',
        PatternAgeGroup.hundred => '难题暂存',
      };

  /// 一句话说明题库侧重。
  String get blurb => switch (this) {
        PatternAgeGroup.baby => '找一样 · 认颜色 · 最简单交替',
        PatternAgeGroup.toddler => '大小 · 长短 · 粗细 · 简单交替',
        PatternAgeGroup.preschool => '数量 · 长短 · 高矮 · 厚薄 · 粗细 · 胖瘦 · 远近 · 深浅',
        PatternAgeGroup.lowerGrade => '数列 · 旋转 · 组合 · 属性规律',
        PatternAgeGroup.upperGrade => '等差等比 · 二维规律 · 属性规律',
        PatternAgeGroup.hundred => '规律只重复一次，孩子难以归纳',
      };

  /// 卡片上的装饰 emoji。
  String get emoji => switch (this) {
        PatternAgeGroup.baby => '🍼',
        PatternAgeGroup.toddler => '🧸',
        PatternAgeGroup.preschool => '🎈',
        PatternAgeGroup.lowerGrade => '✏️',
        PatternAgeGroup.upperGrade => '🔢',
        PatternAgeGroup.hundred => '🧓',
      };
}

/// 一道规律题：完整 4 格图 + 干扰项池。
@immutable
class PatternQuestion {
  const PatternQuestion({
    required this.id,
    required this.title,
    required this.items,
    required this.distractors,
    required this.age,
    this.difficulty = 1,
    this.blankable,
  });

  final String id;

  /// 规律说明，例如「数量依次加 1」「同类水果」。
  final String title;

  /// 完整一行的 4 格图。答题时随机挖去其中一格作为空白。
  final List<Pic> items;

  /// 干扰项池：正确答案之外的备选项都从这里取（池中会避开正确答案）。
  final List<Pic> distractors;

  /// 该题所属的年龄档位。
  final PatternAgeGroup age;

  /// 难度星级 1..3。
  final int difficulty;

  /// 允许被挖空的下标。为空表示任意一格都可挖。
  ///
  /// 对周期性规律（ABAB / AABB 等），挖掉最前面的一格可能让答案不唯一，
  /// 此时用本字段把可挖位置限定为「由前文可唯一推断」的格子。
  final List<int>? blankable;

  /// 实际可挖空的格子下标（[blankable] 为空时取全部格子）。
  List<int> get blankables =>
      blankable ?? [for (var i = 0; i < items.length; i++) i];
}
