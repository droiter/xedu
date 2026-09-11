import 'pattern_quiz_bank.dart';
import 'pattern_quiz_models.dart';

/// 题目的**多级分类**体系。
///
/// 一道题按 5 级归类：
///   题库 `PT`（找规律）
///     └ 年龄段 `B/T/P/L/U`（2–3 / 3–4 / 5–6 / 7–8 / 9–10 岁）
///         └ 规律大类 [PatternFamily]（辨认 / 序列 / 数量 / 属性 / 颜色 / 形状方向）
///             └ 具体类型 [PatternType]（交替 / 数列 / 长短 …）
///                 └ 实例（题目自己的英文短名）
///
/// 结构化 id 就是把这条路径拼起来，例如
/// `PT.P.ATTR.LEN.asc-1` = 找规律·5–6 岁·属性·长短·第 1 组升序题。
/// 同一道题永远得到同一个 id，新增题目也会自动获得 id（无需手工登记）。

/// 规律大类（分类的第 3 级）。
enum PatternFamily {
  recognition('辨认', 'REC'),
  sequence('序列', 'SEQ'),
  quantity('数量', 'QTY'),
  attribute('属性', 'ATTR'),
  color('颜色', 'COL'),
  geometry('形状方向', 'GEO');

  const PatternFamily(this.label, this.code);

  final String label;
  final String code;
}

/// 具体类型（分类的第 4 级）。[family] 是它所属的大类。
enum PatternType {
  same('找一样', 'SAME', PatternFamily.recognition),
  category('找同类', 'CAT', PatternFamily.recognition),
  alt('交替', 'ALT', PatternFamily.sequence),
  cycle('循环', 'CYC', PatternFamily.sequence),
  number('数列', 'NUM', PatternFamily.sequence),
  twoDim('二维规律', '2D', PatternFamily.sequence),
  count('数量变化', 'CNT', PatternFamily.quantity),
  shapeCount('图形数量', 'SHPN', PatternFamily.quantity),
  dice('骰子点数', 'DICE', PatternFamily.quantity),
  bar('高度阶梯', 'BAR', PatternFamily.quantity),
  height('高矮', 'HIGH', PatternFamily.attribute),
  size('大小', 'SIZE', PatternFamily.attribute),
  length('长短', 'LEN', PatternFamily.attribute),
  thickness('厚薄', 'THK', PatternFamily.attribute),
  width('粗细', 'WID', PatternFamily.attribute),
  blob('胖瘦', 'BLOB', PatternFamily.attribute),
  distance('远近', 'DIST', PatternFamily.attribute),
  ramp('颜色深浅', 'RAMP', PatternFamily.color),
  block('颜色辨认', 'BLK', PatternFamily.color),
  shapeColor('图形+颜色', 'SHPC', PatternFamily.color),
  shape('形状旋转', 'SHP', PatternFamily.geometry),
  direction('方向', 'DIR', PatternFamily.geometry),
  other('其他', 'OTH', PatternFamily.sequence);

  const PatternType(this.label, this.code, this.family);

  final String label;
  final String code;
  final PatternFamily family;
}

/// 年龄段编码。
const Map<PatternAgeGroup, String> _ageCode = {
  PatternAgeGroup.baby: 'B',
  PatternAgeGroup.toddler: 'T',
  PatternAgeGroup.preschool: 'P',
  PatternAgeGroup.lowerGrade: 'L',
  PatternAgeGroup.upperGrade: 'U',
};

/// 题目短名里第 2 段（题型 token）→ 具体类型。
const Map<String, PatternType> _tokenType = {
  'same': PatternType.same,
  'cat': PatternType.category,
  'alt': PatternType.alt,
  'cycle3': PatternType.cycle,
  'num': PatternType.number,
  'two': PatternType.twoDim,
  'cnt': PatternType.count,
  'shcount': PatternType.shapeCount,
  'dice': PatternType.dice,
  'bar': PatternType.bar,
  'tall': PatternType.height,
  'size': PatternType.size,
  'size3': PatternType.size,
  'len': PatternType.length,
  'thick': PatternType.thickness,
  'width': PatternType.width,
  'blob': PatternType.blob,
  'dist': PatternType.distance,
  'ramp': PatternType.ramp,
  'block': PatternType.block,
  'shapecolor': PatternType.shapeColor,
  'shape': PatternType.shape,
  'dir': PatternType.direction,
};

/// 题目短名形如 `p-len-asc-1`：第 1 段年龄、第 2 段题型、其余为实例名。
String _tokenOf(String slug) {
  final parts = slug.split('-');
  return parts.length >= 2 ? parts[1] : '';
}

String _tailOf(String slug) {
  final parts = slug.split('-');
  if (parts.length > 2) return parts.sublist(2).join('-');
  return parts.isEmpty ? slug : parts.last;
}

/// 题目所属的具体类型（未知 token 归入 [PatternType.other]）。
PatternType typeOf(PatternQuestion q) =>
    _tokenType[_tokenOf(q.id)] ?? PatternType.other;

/// 题目所属的规律大类。
PatternFamily familyOf(PatternQuestion q) => typeOf(q).family;

/// 题目的**多级分类 id**，例如 `PT.P.ATTR.LEN.asc-1`。
String qidOf(PatternQuestion q) {
  final t = typeOf(q);
  final age = _ageCode[q.age] ?? 'X';
  return 'PT.$age.${t.family.code}.${t.code}.${_tailOf(q.id)}';
}

/// 分类的中文描述，例如「属性·长短」。
String categoryLabelOf(PatternQuestion q) {
  final t = typeOf(q);
  return '${t.family.label}·${t.label}';
}

/// 题目在分类里的完整中文路径，例如「5–6 岁 / 属性 / 长短」。
String categoryPathOf(PatternQuestion q) {
  final t = typeOf(q);
  return '${q.age.ageText} / ${t.family.label} / ${t.label}';
}

/// 结构化 id → 题目。用于把持久化的做题记录还原回题目。
final Map<String, PatternQuestion> kQuestionByQid = {
  for (final q in kPatternQuestions) qidOf(q): q,
};

/// 该题曾被报告过、但题库里已找不到的 id 一律跳过，不会污染统计。
PatternQuestion? questionByQid(String qid) => kQuestionByQid[qid];
