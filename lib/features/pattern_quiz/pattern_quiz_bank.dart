import 'pattern_quiz_models.dart';

/// 内置「规律题库」，按年龄档位分层、按难度分级。
///
/// 每道题由 4 格图 + 干扰项池组成；答题时在 [PatternQuestion.blankables]
/// 允许的位置里随机挖空一格、并从干扰项池挑选干扰项组成选择题。
/// 换真实图片时，把题目里的 Pic 换成 [Pic.asset] 即可。
final List<PatternQuestion> kPatternQuestions = _buildBank();

/// 按年龄档位分组后的题库。
final Map<PatternAgeGroup, List<PatternQuestion>> kPatternBankByAge = {
  for (final g in PatternAgeGroup.values)
    g: [
      for (final q in kPatternQuestions)
        if (q.age == g) q,
    ],
};

/// 取某个年龄档位的题库（无匹配时返回空表）。
List<PatternQuestion> patternBankFor(PatternAgeGroup age) =>
    kPatternBankByAge[age] ?? const [];

/// 取多个年龄档位的合并题库（按档位由小到大拼接，去重由题目 id 保证）。
///
/// 多选年龄时把若干档位的题混在一起出，题库更大、难度梯度更连续。
List<PatternQuestion> patternBankForAges(Iterable<PatternAgeGroup> ages) {
  final set = ages.toSet();
  return [
    for (final g in PatternAgeGroup.values)
      if (set.contains(g)) ...patternBankFor(g),
  ];
}

/// 周期为 2 的规律（ABAB 等）：挖掉第一格会不唯一，限定可挖后三格。
const List<int> _p2 = [1, 2, 3];

// ---------- emoji 类别（用于「同类辨认」题型） ----------
const List<String> _fruits = ['🍎', '🍌', '🍇', '🍊', '🍓', '🍉', '🍒', '🍑'];
const List<String> _animals = ['🐶', '🐱', '🐭', '🐰', '🐼', '🐯', '🦊', '🐸'];
const List<String> _vehicles = ['🚗', '🚌', '✈️', '🚢', '🚲', '🚕', '🚁', '🚒'];
const List<String> _foods = ['🍕', '🍔', '🍦', '🍰', '🍩', '🥨', '🍟', '🍫'];
const List<String> _toys = ['🧸', '🪀', '🪁', '🎈', '🧩', '🎮', '🪃', '🎯'];
const List<String> _musical = ['🎹', '🎸', '🥁', '🎺', '🎻', '🎷', '🪕', '🪗'];
const List<String> _school = ['✏️', '📚', '📐', '🖍️', '🎒', '📎', '📔', '🖊️'];
const List<String> _sports = ['⚽', '🏀', '🎾', '🏈', '🏓', '🏐', '🥊', '🎳'];
const List<String> _clothes = ['👕', '👖', '🧦', '🧢', '👗', '🧤', '👞', '🧣'];
const List<String> _weather = ['☀️', '🌧️', '⛅', '❄️', '🌈', '⚡', '☁️', '🌪️'];

List<String> get _allEmoji => [
      ..._fruits,
      ..._animals,
      ..._vehicles,
      ..._foods,
      ..._toys,
      ..._musical,
      ..._school,
      ..._sports,
      ..._clothes,
      ..._weather,
    ];

// ---------- 元素构造辅助 ----------
List<Pic> _dots(List<int> counts, {int base = 0}) =>
    [for (final c in counts) Pic.dots(c, base: base)];

List<Pic> _ecount(String emoji, List<int> counts) =>
    [for (final c in counts) Pic.emojiCount(emoji, c)];

List<Pic> _esize(String emoji, List<int> levels) =>
    [for (final l in levels) Pic.emojiSize(emoji, l)];

List<Pic> _arrows(List<int> quarters) =>
    [for (final q in quarters) Pic.arrowQuarter(q)];

List<Pic> _ramp(int base, List<int> levels) =>
    [for (final l in levels) Pic.colorRamp(base, l)];

List<Pic> _nums(List<int> values) => [for (final v in values) Pic.number(v)];

List<Pic> _shapes(int shape, List<int> turns) =>
    [for (final t in turns) Pic.shape(shape, quarter: t)];

List<Pic> _shcount(int shape, List<int> counts, {int color = 0}) =>
    [for (final c in counts) Pic.shapeCount(shape, c, color: color)];

List<Pic> _dice(List<int> counts) => [for (final c in counts) Pic.dice(c)];

List<Pic> _blocks(List<int> colors) =>
    [for (final c in colors) Pic.colorBlock(c)];

List<Pic> _bars(List<int> units) => [for (final u in units) Pic.bar(u)];

List<Pic> _singles(List<String> emoji) =>
    [for (final e in emoji) Pic.emojiSingle(e)];

// ---------- 干扰项池 ----------
List<Pic> _dotsPool(int max, {int base = 0}) =>
    [for (var c = 1; c <= max; c++) Pic.dots(c, base: base)];

List<Pic> _ecountPool(String emoji, int max) =>
    [for (var c = 1; c <= max; c++) Pic.emojiCount(emoji, c)];

List<Pic> _esizePool(String emoji) => _esize(emoji, [0, 1, 2, 3]);

List<Pic> _arrowPool() => _arrows([0, 1, 2, 3]);

List<Pic> _rampPool() => [
      for (var b = 0; b < 5; b++)
        for (var l = 0; l < 4; l++) Pic.colorRamp(b, l),
    ];

/// 数列题的干扰项池：正确答案各值 ±[span] 范围内的数字（贴近的易混淆项）。
List<Pic> _numPool(List<int> correct, {int span = 3}) {
  final s = <int>{};
  for (final v in correct) {
    for (var d = -span; d <= span; d++) {
      if (v + d > 0 && v + d <= 200) s.add(v + d);
    }
  }
  final list = s.toList()..sort();
  return [for (final v in list) Pic.number(v)];
}

/// 图形识别题的干扰项池：全部内置图形。
List<Pic> _shapePool() =>
    [for (var s = 0; s < kShapeNames.length; s++) Pic.shape(s)];

/// 图形旋转题的干扰项池：同一图形的四个朝向。
List<Pic> _shapeTurnPool(int shape) => _shapes(shape, [0, 1, 2, 3]);

/// 图形数量题的干扰项池。
List<Pic> _shcountPool(int shape, int max, {int color = 0}) =>
    _shcount(shape, [for (var c = 1; c <= max; c++) c], color: color);

List<Pic> _dicePool() => _dice([1, 2, 3, 4, 5, 6]);

/// 纯色块题的干扰项池：[n] 种鲜明颜色。
List<Pic> _blockPool([int n = 6]) =>
    [for (var c = 0; c < n; c++) Pic.colorBlock(c)];

List<Pic> _barPool() => _bars([1, 2, 3, 4, 5]);

/// 从其它类别挑 emoji 作为干扰项池（排除 [exclude] 里的同类项）。
List<Pic> _catPool(List<String> exclude) => [
      for (final e in _allEmoji)
        if (!exclude.contains(e)) Pic.emojiSingle(e),
    ];

/// 交替题的干扰项池：排除用到的两种 emoji。
List<Pic> _altPool(List<String> used) => [
      for (final e in _allEmoji)
        if (!used.contains(e)) Pic.emojiSingle(e),
    ];

/// 二维图形题的干扰项池：若干图形 × 若干数量。
List<Pic> _shapeCountAllPool() => [
      for (var s = 0; s < 6; s++)
        for (var c = 1; c <= 5; c++) Pic.shapeCount(s, c),
    ];

/// 「数量 + 颜色」二维题的干扰项池：固定图形，数量 1..5 × 前 4 种颜色。
List<Pic> _shapeCountColorPool(int shape) => [
      for (var c = 1; c <= 5; c++)
        for (var col = 0; col < 4; col++) Pic.shapeCount(shape, c, color: col),
    ];

// ---------- 题目构造 ----------
PatternQuestion _q(
  String id,
  String title,
  List<Pic> items,
  List<Pic> distractors,
  PatternAgeGroup age, {
  int diff = 1,
  List<int>? blankable,
}) =>
    PatternQuestion(
      id: id,
      title: title,
      items: items,
      distractors: distractors,
      age: age,
      difficulty: diff,
      blankable: blankable,
    );

List<PatternQuestion> _buildBank() {
  const b = PatternAgeGroup.baby;
  const t = PatternAgeGroup.toddler;
  const p = PatternAgeGroup.preschool;
  const l = PatternAgeGroup.lowerGrade;
  const u = PatternAgeGroup.upperGrade;

  return [
    // ============================================================
    // 2–3 岁 · 亲子启蒙：找一样 / 认颜色 / 最简单的两两交替
    // ============================================================
    // —— 找一样：四格完全相同，随便挖一格答案都唯一 ——
    _q('b-same-apple', '四张图一模一样，找出缺少的那张',
        _singles(['🍎', '🍎', '🍎', '🍎']), _altPool(['🍎']), b),
    _q('b-same-banana', '都是香蕉，找出缺少的那张',
        _singles(['🍌', '🍌', '🍌', '🍌']), _altPool(['🍌']), b),
    _q('b-same-cat', '都是小猫，找出缺少的那张',
        _singles(['🐱', '🐱', '🐱', '🐱']), _altPool(['🐱']), b),
    _q('b-same-ball', '都是皮球，找出缺少的那张',
        _singles(['⚽', '⚽', '⚽', '⚽']), _altPool(['⚽']), b),
    _q('b-same-balloon', '都是气球，找出缺少的那张',
        _singles(['🎈', '🎈', '🎈', '🎈']), _altPool(['🎈']), b),
    _q('b-same-star', '都是星星，找出缺少的那张',
        _singles(['⭐', '⭐', '⭐', '⭐']), _altPool(['⭐']), b),
    _q('b-same-red', '四块都是红色，找出缺少的那块',
        _blocks([0, 0, 0, 0]), _blockPool(), b),
    _q('b-same-blue', '四块都是蓝色，找出缺少的那块',
        _blocks([4, 4, 4, 4]), _blockPool(), b),

    // —— 最简单的两两交替（只用两种差别很大的图） ——
    _q('b-alt-apple-banana', '苹果、香蕉一个隔一个',
        _singles(['🍎', '🍌', '🍎', '🍌']), _altPool(['🍎', '🍌']), b,
        blankable: _p2),
    _q('b-alt-cat-dog', '小猫、小狗一个隔一个',
        _singles(['🐱', '🐶', '🐱', '🐶']), _altPool(['🐱', '🐶']), b,
        blankable: _p2),
    _q('b-alt-sun-moon', '太阳、月亮一个隔一个',
        _singles(['☀️', '🌙', '☀️', '🌙']), _altPool(['☀️', '🌙']), b,
        blankable: _p2),
    _q('b-alt-red-blue', '红色、蓝色一个隔一个', _blocks([0, 4, 0, 4]),
        _blockPool(), b, blankable: _p2),
    _q('b-alt-yellow-green', '黄色、绿色一个隔一个', _blocks([2, 3, 2, 3]),
        _blockPool(), b, blankable: _p2),
    _q('b-alt-circle-square', '圆形、方形一个隔一个',
        [Pic.shape(0), Pic.shape(1), Pic.shape(0), Pic.shape(1)], _shapePool(),
        b, blankable: _p2),
    _q('b-alt-big-small', '星星一会儿大、一会儿小',
        _esize('⭐', [3, 0, 3, 0]), _esizePool('⭐'), b, blankable: _p2),
    _q('b-alt-count-apple', '苹果一会儿 1 个、一会儿 2 个',
        _ecount('🍎', [1, 2, 1, 2]), _ecountPool('🍎', 4), b,
        diff: 2, blankable: _p2),

    // ============================================================
    // 3–4 岁 · 幼儿启蒙：大小 / 颜色 / 简单交替 / 同类辨认
    // ============================================================
    _q('t-alt-fruit', '苹果和香蕉轮流出现',
        _singles(['🍎', '🍌', '🍎', '🍌']), _altPool(['🍎', '🍌']), t,
        blankable: _p2),
    _q('t-alt-animal', '小猫和小狗轮流出现',
        _singles(['🐶', '🐱', '🐶', '🐱']), _altPool(['🐶', '🐱']), t,
        blankable: _p2),
    _q('t-alt-vehicle', '汽车和公交车轮流出现',
        _singles(['🚗', '🚌', '🚗', '🚌']), _altPool(['🚗', '🚌']), t,
        blankable: _p2),
    _q('t-alt-food', '披萨和汉堡轮流出现',
        _singles(['🍕', '🍔', '🍕', '🍔']), _altPool(['🍕', '🍔']), t,
        blankable: _p2),
    _q('t-alt-sky', '星星和月亮轮流出现',
        _singles(['⭐', '🌙', '⭐', '🌙']), _altPool(['⭐', '🌙']), t,
        blankable: _p2),
    _q('t-alt-bear', '小熊和小兔轮流出现',
        _singles(['🐻', '🐰', '🐻', '🐰']), _altPool(['🐻', '🐰']), t,
        blankable: _p2),
    _q('t-alt-block-ry', '红色和黄色轮流出现', _blocks([0, 2, 0, 2]),
        _blockPool(), t, blankable: _p2),
    _q('t-alt-block-bg', '蓝色和绿色轮流出现', _blocks([4, 3, 4, 3]),
        _blockPool(), t,
        blankable: _p2),
    _q('t-alt-shape-cs', '圆形和方形轮流出现',
        [Pic.shape(0), Pic.shape(1), Pic.shape(0), Pic.shape(1)], _shapePool(),
        t,
        blankable: _p2),
    _q('t-alt-count-apple', '苹果一会儿 1 个、一会儿 2 个',
        _ecount('🍎', [1, 2, 1, 2]), _ecountPool('🍎', 4), t,
        diff: 2, blankable: _p2),
    _q('t-alt-size-fish', '小鱼一会儿大、一会儿小',
        _esize('🐟', [3, 0, 3, 0]), _esizePool('🐟'), t,
        diff: 2, blankable: _p2),
    _q('t-cat-fruit', '找同类：这些全是水果', _singles(_fruits.take(4).toList()),
        _catPool(_fruits), t),
    _q('t-cat-animal', '找同类：这些全是小动物',
        _singles(_animals.take(4).toList()), _catPool(_animals), t),
    _q('t-cat-toy', '找同类：这些全是玩具',
        _singles(_toys.take(4).toList()), _catPool(_toys), t),
    _q('t-cat-vehicle', '找同类：这些全是交通工具',
        _singles(_vehicles.take(4).toList()), _catPool(_vehicles), t),

    // —— 找一样（比 2–3 岁稍快一点，做热身） ——
    _q('t-same-star', '都是星星，找出缺少的那张',
        _singles(['⭐', '⭐', '⭐', '⭐']), _altPool(['⭐']), t),
    _q('t-same-cat', '都是小猫，找出缺少的那张',
        _singles(['🐱', '🐱', '🐱', '🐱']), _altPool(['🐱']), t),
    _q('t-same-red', '四块都是红色，找出缺少的那块',
        _blocks([0, 0, 0, 0]), _blockPool(), t),
    _q('t-same-blue', '四块都是蓝色，找出缺少的那块',
        _blocks([4, 4, 4, 4]), _blockPool(), t),

    // —— 更多两两交替（换主题，练同一规律的迁移） ——
    _q('t-alt-sport', '皮球和篮球轮流出现',
        _singles(['⚽', '🏀', '⚽', '🏀']), _altPool(['⚽', '🏀']), t,
        blankable: _p2),
    _q('t-alt-clothes', '上衣和裤子轮流出现',
        _singles(['👕', '👖', '👕', '👖']), _altPool(['👕', '👖']), t,
        blankable: _p2),
    _q('t-alt-music', '钢琴和鼓轮流出现',
        _singles(['🎹', '🥁', '🎹', '🥁']), _altPool(['🎹', '🥁']), t,
        blankable: _p2),
    _q('t-alt-weather', '太阳和下雨轮流出现',
        _singles(['☀️', '🌧️', '☀️', '🌧️']), _altPool(['☀️', '🌧️']), t,
        blankable: _p2),
    _q('t-alt-block-bo', '蓝色和橙色轮流出现', _blocks([4, 1, 4, 1]),
        _blockPool(), t, blankable: _p2),
    _q('t-alt-block-pg', '紫色和绿色轮流出现', _blocks([5, 3, 5, 3]),
        _blockPool(), t, blankable: _p2),
    _q('t-alt-shape-ct', '圆形和三角形轮流出现',
        [Pic.shape(0), Pic.shape(2), Pic.shape(0), Pic.shape(2)], _shapePool(),
        t, blankable: _p2),
    _q('t-alt-shape-ts', '三角形和方形轮流出现',
        [Pic.shape(2), Pic.shape(1), Pic.shape(2), Pic.shape(1)], _shapePool(),
        t, blankable: _p2),
    _q('t-alt-count-star', '星星一会儿 2 个、一会儿 1 个',
        _ecount('⭐', [2, 1, 2, 1]), _ecountPool('⭐', 4), t,
        diff: 2, blankable: _p2),
    _q('t-alt-count-candy', '糖果一会儿 1 个、一会儿 3 个',
        _ecount('🍬', [1, 3, 1, 3]), _ecountPool('🍬', 5), t,
        diff: 2, blankable: _p2),
    _q('t-alt-size-balloon', '气球一会儿大、一会儿小',
        _esize('🎈', [3, 0, 3, 0]), _esizePool('🎈'), t,
        diff: 2, blankable: _p2),
    _q('t-alt-size-apple', '苹果一会儿小、一会儿大',
        _esize('🍎', [0, 3, 0, 3]), _esizePool('🍎'), t,
        diff: 2, blankable: _p2),

    // —— 三个一循环（比两两交替再难一步） ——
    _q('t-cycle3-fruit', '苹果、香蕉、葡萄轮流出现',
        _singles(['🍎', '🍌', '🍇', '🍎']), _altPool(['🍎', '🍌', '🍇']), t,
        diff: 3, blankable: _p2),
    _q('t-cycle3-block', '红、黄、绿轮流出现', _blocks([0, 2, 3, 0]),
        _blockPool(), t, diff: 3, blankable: _p2),
    _q('t-cycle3-animal', '小狗、小猫、小兔轮流出现',
        _singles(['🐶', '🐱', '🐰', '🐶']), _altPool(['🐶', '🐱', '🐰']), t,
        diff: 3, blankable: _p2),

    // ============================================================
    // 5–6 岁 · 学前预备：数量增减 / 方向 / 深浅 / 阶梯 / 点数
    // ============================================================
    // —— 数量：递增 / 递减 ——
    _q('p-cnt-asc-1', '圆点从少到多，每次加 1', _dots([1, 2, 3, 4]),
        _dotsPool(7), p),
    _q('p-cnt-asc-2', '圆点每次加 2', _dots([2, 4, 6, 8], base: 1),
        _dotsPool(9, base: 1), p, diff: 2),
    _q('p-cnt-asc-apple', '苹果从少到多，每次加 1', _ecount('🍎', [1, 2, 3, 4]),
        _ecountPool('🍎', 6), p),
    _q('p-cnt-asc-star', '星星从少到多，每次加 1', _ecount('⭐', [1, 2, 3, 4]),
        _ecountPool('⭐', 6), p),
    _q('p-cnt-desc-1', '圆点从多到少，每次减 1', _dots([5, 4, 3, 2], base: 2),
        _dotsPool(7, base: 2), p),
    _q('p-cnt-desc-2', '草莓从多到少，每次减 1', _ecount('🍓', [4, 3, 2, 1]),
        _ecountPool('🍓', 5), p),
    _q('p-cnt-desc-dots', '圆点每次减 2', _dots([8, 6, 4, 2], base: 3),
        _dotsPool(9, base: 3), p, diff: 2),

    // —— 大小 ——
    _q('p-size-asc-fish', '小鱼从很小到很大', _esize('🐟', [0, 1, 2, 3]),
        _esizePool('🐟'), p),
    _q('p-size-asc-apple', '苹果从小到大', _esize('🍎', [0, 1, 2, 3]),
        _esizePool('🍎'), p),
    _q('p-size-desc-balloon', '气球从很大到很小', _esize('🎈', [3, 2, 1, 0]),
        _esizePool('🎈'), p),
    _q('p-size-desc-chick', '小鸡从大到小', _esize('🐥', [3, 2, 1, 0]),
        _esizePool('🐥'), p),

    // —— 颜色深浅 ——
    _q('p-ramp-asc-blue', '蓝色由浅到深', _ramp(0, [0, 1, 2, 3]), _rampPool(), p,
        diff: 2),
    _q('p-ramp-desc-green', '绿色由深到浅', _ramp(1, [3, 2, 1, 0]), _rampPool(),
        p, diff: 2),
    _q('p-ramp-asc-purple', '紫色由浅到深', _ramp(3, [0, 1, 2, 3]), _rampPool(),
        p, diff: 2),
    _q('p-ramp-desc-pink', '粉色由深到浅', _ramp(4, [3, 2, 1, 0]), _rampPool(),
        p, diff: 2),

    // —— 方向 ——
    _q('p-dir-alt-ud', '箭头朝上、朝下轮流', _arrows([0, 2, 0, 2]),
        _arrowPool(), p, diff: 2, blankable: _p2),
    _q('p-dir-alt-lr', '箭头朝右、朝左轮流', _arrows([1, 3, 1, 3]),
        _arrowPool(), p, diff: 2, blankable: _p2),

    // —— 骰子点数 ——
    _q('p-dice-asc', '骰子点数从 1 到 4', _dice([1, 2, 3, 4]), _dicePool(), p),
    _q('p-dice-desc', '骰子点数从 5 到 2', _dice([5, 4, 3, 2]), _dicePool(), p,
        diff: 2),

    // —— 阶梯柱高 ——
    _q('p-bar-asc', '柱子一级比一级高', _bars([1, 2, 3, 4]), _barPool(), p),
    _q('p-bar-desc', '柱子一级比一级矮', _bars([4, 3, 2, 1]), _barPool(), p),

    // —— 图形数量 ——
    _q('p-shcount-asc', '圆形从 1 个增加到 4 个', _shcount(0, [1, 2, 3, 4]),
        _shcountPool(0, 6), p, diff: 2),
    _q('p-shcount-desc', '三角形从 4 个减少到 1 个',
        _shcount(2, [4, 3, 2, 1]), _shcountPool(2, 6), p, diff: 2),

    // —— 周期交替 ——
    _q('p-alt-aabb', '两个苹果、两个香蕉，重复出现',
        _singles(['🍎', '🍎', '🍌', '🍌']), _altPool(['🍎', '🍌']), p, diff: 2),
    _q('p-cnt-aabb', '苹果 1 个、1 个、2 个、2 个',
        _ecount('🍎', [1, 1, 2, 2]), _ecountPool('🍎', 5), p, diff: 3),

    // —— 同类辨认 ——
    _q('p-cat-food', '找同类：这些全是食物', _singles(_foods.take(4).toList()),
        _catPool(_foods), p),
    _q('p-cat-school', '找同类：这些全是学习用品',
        _singles(_school.take(4).toList()), _catPool(_school), p, diff: 2),

    // ============================================================
    // 7–8 岁 · 小学低年级：数列 / 旋转 / 组合
    // ============================================================
    // —— 数列（等差 / 递减 / 加倍） ——
    _q('l-num-asc-1', '数字每次加 1：1、2、3、4', _nums([1, 2, 3, 4]),
        _numPool([1, 2, 3, 4]), l),
    _q('l-num-asc-2', '数字每次加 2：2、4、6、8', _nums([2, 4, 6, 8]),
        _numPool([2, 4, 6, 8]), l),
    _q('l-num-asc-3', '数字每次加 3：3、6、9、12', _nums([3, 6, 9, 12]),
        _numPool([3, 6, 9, 12]), l, diff: 2),
    _q('l-num-asc-5', '数字每次加 5：5、10、15、20', _nums([5, 10, 15, 20]),
        _numPool([5, 10, 15, 20]), l, diff: 2),
    _q('l-num-asc-11', '数字每次加 1：11、12、13、14',
        _nums([11, 12, 13, 14]), _numPool([11, 12, 13, 14]), l),
    _q('l-num-desc-1', '数字每次减 1：10、9、8、7', _nums([10, 9, 8, 7]),
        _numPool([10, 9, 8, 7]), l),
    _q('l-num-desc-3', '数字每次减 3：20、17、14、11',
        _nums([20, 17, 14, 11]), _numPool([20, 17, 14, 11]), l, diff: 2),
    _q('l-num-odd', '连续的奇数：1、3、5、7', _nums([1, 3, 5, 7]),
        _numPool([1, 3, 5, 7]), l, diff: 2),
    _q('l-num-even', '连续的偶数：2、4、6、8', _nums([2, 4, 6, 8]),
        _numPool([2, 4, 6, 8]), l),
    _q('l-num-mul2', '每个数都是前一个的 2 倍：1、2、4、8',
        _nums([1, 2, 4, 8]), _numPool([1, 2, 4, 8]), l, diff: 3),
    _q('l-num-addinc', '每次多加了 1：1、2、4、7', _nums([1, 2, 4, 7]),
        _numPool([1, 2, 4, 7]), l, diff: 3, blankable: [3]),

    // —— 方向旋转 ——
    _q('l-dir-cw', '箭头按顺时针转 90°', _arrows([0, 1, 2, 3]), _arrowPool(), l,
        diff: 2),
    _q('l-dir-ccw', '箭头按逆时针转 90°', _arrows([3, 2, 1, 0]), _arrowPool(),
        l, diff: 2),
    _q('l-dir-alt-ud', '箭头：上、下交替', _arrows([0, 2, 0, 2]), _arrowPool(),
        l, blankable: _p2),
    _q('l-shape-rot-tri', '三角形顺时针转 90°', _shapes(2, [0, 1, 2, 3]),
        _shapeTurnPool(2), l, diff: 3),
    _q('l-shape-rot-cross', '十字顺时针转 90°', _shapes(8, [0, 1, 2, 3]),
        _shapeTurnPool(8), l, diff: 3),

    // —— 图形数量 / 图形识别 ——
    _q('l-shcount-square', '正方形从 1 个增加到 4 个',
        _shcount(1, [1, 2, 3, 4]), _shcountPool(1, 6), l),
    _q('l-shcount-star', '五角星从 2 个增加到 5 个',
        _shcount(3, [2, 3, 4, 5]), _shcountPool(3, 7), l, diff: 2),
    _q('l-shape-alt', '圆形和三角形轮流出现',
        [Pic.shape(0), Pic.shape(2), Pic.shape(0), Pic.shape(2)], _shapePool(),
        l, blankable: _p2),

    // —— 颜色循环 ——
    _q('l-block-cycle3', '红、黄、绿循环出现', _blocks([0, 2, 3, 0]),
        _blockPool(), l, diff: 3, blankable: _p2),
    _q('l-block-aabb', '红、红、蓝、蓝', _blocks([0, 0, 4, 4]), _blockPool(), l,
        diff: 2),

    // —— 组合规律：外形 + 数量一起变 ——
    _q('l-two-attr', '图形变、个数也变：1 圆、2 方、3 三角、4 星',
        [
          Pic.shapeCount(0, 1),
          Pic.shapeCount(1, 2),
          Pic.shapeCount(2, 3),
          Pic.shapeCount(3, 4),
        ],
        _shapeCountAllPool(), l, diff: 3),

    // —— 阶梯柱高 ——
    _q('l-bar-asc-2', '柱子每次升高 1 格：2、3、4、5',
        _bars([2, 3, 4, 5]), _barPool(), l, diff: 2),
    _q('l-bar-desc-2', '柱子每次降低 1 格：5、4、3、2',
        _bars([5, 4, 3, 2]), _barPool(), l, diff: 2),

    // —— 同类辨认 ——
    _q('l-cat-sport', '找同类：这些全是运动器材',
        _singles(_sports.take(4).toList()), _catPool(_sports), l),
    _q('l-cat-musical', '找同类：这些全是乐器',
        _singles(_musical.take(4).toList()), _catPool(_musical), l, diff: 2),

    // ============================================================
    // 9–10 岁 · 小学高年级：等差 / 等比 / 二维规律
    // ============================================================
    // —— 等差（含递增增量） ——
    _q('u-num-asc-25', '数字每次加 25：25、50、75、100',
        _nums([25, 50, 75, 100]), _numPool([25, 50, 75, 100], span: 6), u,
        diff: 3),
    _q('u-num-asc-7', '数字每次加 7：7、14、21、28', _nums([7, 14, 21, 28]),
        _numPool([7, 14, 21, 28], span: 5), u, diff: 2),
    _q('u-num-asc-11b', '数字每次加 11：11、22、33、44',
        _nums([11, 22, 33, 44]), _numPool([11, 22, 33, 44], span: 6), u,
        diff: 3),
    _q('u-num-desc-4', '数字每次减 4：40、36、32、28',
        _nums([40, 36, 32, 28]), _numPool([40, 36, 32, 28], span: 5), u,
        diff: 2),
    _q('u-num-desc-7', '数字每次减 7：100、93、86、79',
        _nums([100, 93, 86, 79]), _numPool([100, 93, 86, 79], span: 4), u,
        diff: 3),
    _q('u-num-addinc', '每次多加了 1：2、4、7、11', _nums([2, 4, 7, 11]),
        _numPool([2, 4, 7, 11]), u, diff: 3, blankable: [3]),
    _q('u-num-subinc', '每次多减了 1：20、19、17、14', _nums([20, 19, 17, 14]),
        _numPool([20, 19, 17, 14], span: 4), u, diff: 3, blankable: [3]),
    _q('u-num-tri', '每次多加 1：1、3、6、10', _nums([1, 3, 6, 10]),
        _numPool([1, 3, 6, 10], span: 2), u, diff: 3, blankable: [3]),
    _q('u-num-subinc2', '每次多减 1：30、29、27、24',
        _nums([30, 29, 27, 24]), _numPool([30, 29, 27, 24], span: 3), u,
        diff: 3, blankable: [3]),

    // —— 等比 / 平方 ——
    _q('u-num-mul2', '每个数都是前一个的 2 倍：2、4、8、16',
        _nums([2, 4, 8, 16]), _numPool([2, 4, 8, 16], span: 2), u, diff: 3),
    _q('u-num-mul2b', '每个数都是前一个的 2 倍：3、6、12、24',
        _nums([3, 6, 12, 24]), _numPool([3, 6, 12, 24], span: 2), u, diff: 3),
    _q('u-num-mul3', '每个数都是前一个的 3 倍：2、6、18、54',
        _nums([2, 6, 18, 54]), _numPool([2, 6, 18, 54], span: 3), u, diff: 3),
    _q('u-num-halve', '每个数都是前一个的一半：64、32、16、8',
        _nums([64, 32, 16, 8]), _numPool([64, 32, 16, 8], span: 4), u, diff: 3),
    _q('u-num-square', '平方数：1、4、9、16', _nums([1, 4, 9, 16]),
        _numPool([1, 4, 9, 16], span: 2), u, diff: 3),
    _q('u-num-fib', '前两个数相加得到后一个：1、2、3、5',
        _nums([1, 2, 3, 5]), _numPool([1, 2, 3, 5]), u, diff: 3,
        blankable: _p2),

    // —— 方向 / 图形旋转 ——
    _q('u-dir-cw', '箭头顺时针转 90°', _arrows([0, 1, 2, 3]), _arrowPool(), u,
        diff: 2),
    _q('u-dir-ccw', '箭头逆时针转 90°', _arrows([3, 2, 1, 0]), _arrowPool(), u,
        diff: 2),
    _q('u-shape-rot-tri', '三角形顺时针转 90°', _shapes(2, [0, 1, 2, 3]),
        _shapeTurnPool(2), u, diff: 3),
    _q('u-shape-rot-cross', '十字顺时针转 90°', _shapes(8, [0, 1, 2, 3]),
        _shapeTurnPool(8), u, diff: 3),

    // —— 二维规律 ——
    _q('u-two-attr', '个数变多、颜色也换：1 红、2 橙、3 黄、4 绿',
        [
          Pic.shapeCount(0, 1, color: 0),
          Pic.shapeCount(0, 2, color: 1),
          Pic.shapeCount(0, 3, color: 2),
          Pic.shapeCount(0, 4, color: 3),
        ],
        _shapeCountColorPool(0), u, diff: 3),
    _q('u-two-attr-rev', '个数越来越少、图形也在换：4 星、3 三角、2 方、1 圆',
        [
          Pic.shapeCount(3, 4),
          Pic.shapeCount(2, 3),
          Pic.shapeCount(1, 2),
          Pic.shapeCount(0, 1),
        ],
        _shapeCountAllPool(), u, diff: 3),
    _q('u-block-cycle3', '红、黄、绿循环出现', _blocks([0, 2, 3, 0]),
        _blockPool(), u, diff: 3, blankable: _p2),
    _q('u-num-asc-9', '数字每次加 9：9、18、27、36', _nums([9, 18, 27, 36]),
        _numPool([9, 18, 27, 36], span: 5), u, diff: 2),

    // —— 阶梯柱高 ——
    _q('u-bar-desc', '柱子每次降低 1 格：5、4、3、2', _bars([5, 4, 3, 2]),
        _barPool(), u, diff: 2),

    // —— 同类辨认 ——
    _q('u-cat-clothes', '找同类：这些全是衣物',
        _singles(_clothes.take(4).toList()), _catPool(_clothes), u),
    _q('u-cat-weather', '找同类：这些全是天气 / 天空',
        _singles(_weather.take(4).toList()), _catPool(_weather), u, diff: 2),
  ];
}
