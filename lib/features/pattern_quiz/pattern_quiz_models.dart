import 'package:flutter/foundation.dart';

/// 图片 / 动画元素的渲染类型。
///
/// 演示内容全部用 Flutter 内置矢量绘制（圆点 / emoji / 色块），无需任何图片资源。
/// 若之后要换成自己的真实图片，新增元素使用 [Pic.asset] 并把文件放进 `assets/`。
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

  /// 外部图片资源（预留，需要配合 pubspec.yaml 的 assets 目录）。
  asset,
}

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
  });

  final PicKind kind;
  final String id;

  /// emoji 字面量（emojiCount / emojiSingle / emojiSize 用）。
  final String emoji;

  /// 数量（dots / emojiCount 用）。
  final int n;

  /// 档位：emojiSize 的大小档、arrowQuarter 的朝向(0上 1右 2下 3左)、colorRamp 的深浅档。
  final int level;

  /// 颜色底座下标：dots / colorRamp 的调色板编号。
  final int base;

  /// 资源路径（asset 类型用）。
  final String path;

  /// 选项上的文字说明（可选）。
  final String? label;

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
        label: const ['朝上', '朝右', '朝下', '朝左'][quarter],
      );

  static Pic colorRamp(int base, int level) => Pic(
        kind: PicKind.colorRamp,
        id: 'ramp:$base:$level',
        base: base,
        level: level,
        label: '颜色',
      );

  static Pic asset(String path, {String? label}) => Pic(
        kind: PicKind.asset,
        id: 'asset:$path',
        path: path,
        label: label ?? '图片',
      );
}

/// 一道规律题：完整 4 格图 + 干扰项池。
@immutable
class PatternQuestion {
  const PatternQuestion({
    required this.id,
    required this.title,
    required this.items,
    required this.distractors,
  });

  final String id;

  /// 规律说明，例如「数量依次加 1」「同类水果」。
  final String title;

  /// 完整一行的 4 格图。答题时随机挖去其中一格作为空白。
  final List<Pic> items;

  /// 干扰项池：正确答案之外的备选项都从这里取（池中会避开正确答案）。
  final List<Pic> distractors;
}
