import 'pattern_quiz_models.dart';

/// 内置「规律题库」。
///
/// 每道题由 4 格图 + 干扰项池组成；答题时随机挖空一格、并从干扰项池挑选
/// 干扰项组成选择题。换真实图片时，把题目里的 Pic 换成 [Pic.asset] 即可。
final List<PatternQuestion> kPatternQuestions = _buildBank();

// ---------- emoji 类别（用于「同类辨认」题型） ----------
const List<String> _fruits = ['🍎', '🍌', '🍇', '🍊', '🍓', '🍉', '🍒', '🍑'];
const List<String> _animals = ['🐶', '🐱', '🐭', '🐰', '🐼', '🐯', '🦊', '🐸'];
const List<String> _vehicles = ['🚗', '🚌', '✈️', '🚢', '🚲', '🚕', '🚁', '🚒'];
const List<String> _foods = ['🍕', '🍔', '🍦', '🍰', '🍩', '🥨', '🍟', '🍫'];

// ---------- 元素构造辅助 ----------
List<Pic> _dotsOf(List<int> counts, {int base = 0}) =>
    [for (final c in counts) Pic.dots(c, base: base)];

List<Pic> _emojiCountOf(String emoji, List<int> counts) =>
    [for (final c in counts) Pic.emojiCount(emoji, c)];

List<Pic> _emojiSizeOf(String emoji, List<int> levels) =>
    [for (final l in levels) Pic.emojiSize(emoji, l)];

List<Pic> _arrows(List<int> quarters) =>
    [for (final q in quarters) Pic.arrowQuarter(q)];

/// 数量题的干扰项池：同一色系圆点，数量 1..maxCount。
List<Pic> _dotsPool(int maxCount, {int base = 0}) =>
    [for (var c = 1; c <= maxCount; c++) Pic.dots(c, base: base)];

/// emoji 数量题的干扰项池。
List<Pic> _emojiCountPool(String emoji, int maxCount) =>
    [for (var c = 1; c <= maxCount; c++) Pic.emojiCount(emoji, c)];

/// 大小题的干扰项池：同款 emoji 的 0..3 档大小。
List<Pic> _emojiSizePool(String emoji) => _emojiSizeOf(emoji, [0, 1, 2, 3]);

/// 方向题的干扰项池：上右下左四个朝向。
List<Pic> _arrowPool() => _arrows([0, 1, 2, 3]);

/// 颜色题的干扰项池：全部 5 个色系 × 0..3 深浅档。
List<Pic> _rampPool() => [
      for (var b = 0; b < 5; b++)
        for (var l = 0; l < 4; l++) Pic.colorRamp(b, l),
    ];

/// 从若干类别里挑出不与 [exclude] 同类的 emoji 作为干扰项池。
List<Pic> _categoryPool(List<String> exclude) {
  final others = [..._fruits, ..._animals, ..._vehicles, ..._foods]
      .where((e) => !exclude.contains(e))
      .toList();
  return [for (final e in others) Pic.emojiSingle(e)];
}

List<PatternQuestion> _buildBank() {
  return [
    // ============ 数量：递增 / 递减 ============
    PatternQuestion(
      id: 'cnt-asc-dots-1',
      title: '圆点从少到多，每次加 1',
      items: _dotsOf([1, 2, 3, 4]),
      distractors: _dotsPool(7),
    ),
    PatternQuestion(
      id: 'cnt-asc-dots-2',
      title: '圆点每次加 2',
      items: _dotsOf([2, 4, 6, 8], base: 1),
      distractors: _dotsPool(9, base: 1),
    ),
    PatternQuestion(
      id: 'cnt-asc-apple',
      title: '苹果从少到多，每次加 1',
      items: _emojiCountOf('🍎', [1, 2, 3, 4]),
      distractors: _emojiCountPool('🍎', 6),
    ),
    PatternQuestion(
      id: 'cnt-asc-star',
      title: '星星从少到多，每次加 1',
      items: _emojiCountOf('⭐', [1, 2, 3, 4]),
      distractors: _emojiCountPool('⭐', 6),
    ),
    PatternQuestion(
      id: 'cnt-desc-dots-1',
      title: '圆点从多到少，每次减 1',
      items: _dotsOf([5, 4, 3, 2], base: 2),
      distractors: _dotsPool(7, base: 2),
    ),
    PatternQuestion(
      id: 'cnt-desc-dots-2',
      title: '圆点每次减 2',
      items: _dotsOf([8, 6, 4, 2], base: 3),
      distractors: _dotsPool(9, base: 3),
    ),
    PatternQuestion(
      id: 'cnt-desc-strawberry',
      title: '草莓从多到少，每次减 1',
      items: _emojiCountOf('🍓', [4, 3, 2, 1]),
      distractors: _emojiCountPool('🍓', 5),
    ),

    // ============ 大小：递增 / 递减 ============
    PatternQuestion(
      id: 'size-asc-fish',
      title: '小鱼从很小到很大',
      items: _emojiSizeOf('🐟', [0, 1, 2, 3]),
      distractors: _emojiSizePool('🐟'),
    ),
    PatternQuestion(
      id: 'size-asc-apple',
      title: '苹果从小到大',
      items: _emojiSizeOf('🍎', [0, 1, 2, 3]),
      distractors: _emojiSizePool('🍎'),
    ),
    PatternQuestion(
      id: 'size-desc-balloon',
      title: '气球从很大到很小',
      items: _emojiSizeOf('🎈', [3, 2, 1, 0]),
      distractors: _emojiSizePool('🎈'),
    ),
    PatternQuestion(
      id: 'size-desc-chick',
      title: '小鸡从大到小',
      items: _emojiSizeOf('🐥', [3, 2, 1, 0]),
      distractors: _emojiSizePool('🐥'),
    ),

    // ============ 方向：箭头旋转 ============
    PatternQuestion(
      id: 'dir-cw-full',
      title: '箭头按顺时针转',
      items: _arrows([0, 1, 2, 3]),
      distractors: _arrowPool(),
    ),
    PatternQuestion(
      id: 'dir-ccw-full',
      title: '箭头按逆时针转',
      items: _arrows([3, 2, 1, 0]),
      distractors: _arrowPool(),
    ),
    PatternQuestion(
      id: 'dir-cw-alt',
      title: '箭头朝向：上、下交替',
      items: _arrows([0, 2, 0, 2]),
      distractors: _arrowPool(),
    ),

    // ============ 颜色：深浅变化 ============
    PatternQuestion(
      id: 'color-asc-blue',
      title: '蓝色由浅到深',
      items: [for (var l = 0; l < 4; l++) Pic.colorRamp(0, l)],
      distractors: _rampPool(),
    ),
    PatternQuestion(
      id: 'color-desc-green',
      title: '绿色由深到浅',
      items: [for (var l = 3; l >= 0; l--) Pic.colorRamp(1, l)],
      distractors: _rampPool(),
    ),
    PatternQuestion(
      id: 'color-asc-purple',
      title: '紫色由浅到深',
      items: [for (var l = 0; l < 4; l++) Pic.colorRamp(3, l)],
      distractors: _rampPool(),
    ),
    PatternQuestion(
      id: 'color-desc-pink',
      title: '粉色由深到浅',
      items: [for (var l = 3; l >= 0; l--) Pic.colorRamp(4, l)],
      distractors: _rampPool(),
    ),

    // ============ 交替 ============
    PatternQuestion(
      id: 'alt-fruit',
      title: '苹果、香蕉交替出现',
      items: [Pic.emojiSingle('🍎'), Pic.emojiSingle('🍌'), Pic.emojiSingle('🍎'), Pic.emojiSingle('🍌')],
      distractors: [
        for (final e in [..._fruits.where((e) => e != '🍎' && e != '🍌'), '🐼', '🚗', '🍕'])
          Pic.emojiSingle(e),
      ],
    ),

    // ============ 同类辨认 ============
    PatternQuestion(
      id: 'cat-fruit',
      title: '找同类：全部是水果',
      items: [for (final e in _fruits.take(4)) Pic.emojiSingle(e)],
      distractors: _categoryPool(_fruits),
    ),
    PatternQuestion(
      id: 'cat-animal',
      title: '找同类：全部是小动物',
      items: [for (final e in _animals.take(4)) Pic.emojiSingle(e)],
      distractors: _categoryPool(_animals),
    ),
    PatternQuestion(
      id: 'cat-vehicle',
      title: '找同类：全部是交通工具',
      items: [for (final e in _vehicles.take(4)) Pic.emojiSingle(e)],
      distractors: _categoryPool(_vehicles),
    ),
    PatternQuestion(
      id: 'cat-food',
      title: '找同类：全部是食物',
      items: [for (final e in _foods.take(4)) Pic.emojiSingle(e)],
      distractors: _categoryPool(_foods),
    ),
  ];
}
