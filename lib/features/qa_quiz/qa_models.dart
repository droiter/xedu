import 'package:flutter/foundation.dart';

import '../pattern_quiz/pattern_quiz_models.dart';

/// 「看图问答」的题型。
enum QaKind {
  /// 看图说话：看着图，选出说得对的那句话。
  describe('看图说话', 'DESC'),

  /// 阅读选图：看题目文字，选出对应的图片（题面也朗读，选项是图没法读）。
  pickImage('阅读选图', 'PICK'),

  /// 一样 / 不一样：比一比、找出一样的、找出不一样的。
  sameDiff('比一比', 'SAME'),

  /// 一位数加法：可以直接显示数字，也可以用对应数量的物品代替数字。
  add('算一算', 'ADD'),

  /// 比一比属性：高低 / 厚薄 / 快慢 / 远近 / 深浅 / 长短 / 粗细 / 前后 …
  compare('比一比', 'CMP');

  const QaKind(this.label, this.code);

  final String label;
  final String code;

  static QaKind parse(String raw) => values.firstWhere(
        (k) => k.name == raw,
        orElse: () => throw FormatException('未知题型：$raw'),
      );
}

/// 一个答案选项：可以是纯文字、纯图片，也可以图文都有。
@immutable
class QaOption {
  const QaOption({this.text = '', this.pic});

  /// 选项文字。空串表示这个选项只有图。
  final String text;

  /// 选项配图。null 表示这个选项只有文字。
  final Pic? pic;

  bool get hasText => text.isNotEmpty;
  bool get hasPic => pic != null;
}

/// 一道问答题。
@immutable
class QaQuestion {
  const QaQuestion({
    required this.id,
    required this.age,
    required this.kind,
    required this.sub,
    required this.prompt,
    required this.scene,
    required this.options,
    required this.answer,
    required this.stars,
  });

  /// 题库里的短名，例如 `tallest-tree`。
  final String id;

  final PatternAgeGroup age;
  final QaKind kind;

  /// 细分编码，例如 `HIGH`（比高矮）/ `OBJ`（用物品表示加法）。
  final String sub;

  /// 题面文字。**它同时也是朗读文字和屏幕上显示的文字**，三者必须一致，
  /// 语音高亮才能对得上（所以题面里不要出现阿拉伯数字）。
  final String prompt;

  /// 题面配图（0~3 张，横排展示）。
  final List<Pic> scene;

  final List<QaOption> options;

  /// 正确选项下标。
  final int answer;

  /// 难度星级 1..3。
  final int stars;

  /// 结构化题号，例如 `QA.T.CMP.HIGH.tallest-tower`。反馈 bug 时直接贴这个。
  ///
  /// 拼数组而不是写插值串：`'$this.sub'` 会被 Dart 解析成 `$this` 再接字面量
  /// `.sub`，题号里就混进对象字符串了。
  String get qid => [
        'QA',
        _ageCode[age]!,
        kind.code,
        if (sub.isNotEmpty) sub,
        id,
      ].join('.');

  /// 题面音频在清单里的键（题号把点换成下划线，正好也是文件名）。
  String get clipKey => qid.replaceAll('.', '_');

  /// 第 [i] 个选项的音频键。
  String optionClipKey(int i) => '$clipKey.o$i';
}

/// 一题的朗读顺序里，题面之后紧接着说的那句「答案有」。
const String kQaAnswerHeadKey = 'common_answer_head';

/// 选项读完之后说的那句「你选择哪个」。
const String kQaAnswerTailKey = 'common_answer_tail';

/// 整段跟读里的一小节：题面 / 「答案有」/ 某个选项 / 「你选择哪个」。
@immutable
class QaReadSeg {
  const QaReadSeg(this.key, this.clip);

  /// 片段键，和 [QaQuestion.clipKey] / [QaQuestion.optionClipKey] 同一套。
  final String key;

  final QaVoiceClip clip;
}

/// 年龄段编码，和找规律题库保持一致。
const Map<PatternAgeGroup, String> _ageCode = {
  PatternAgeGroup.baby: 'B',
  PatternAgeGroup.toddler: 'T',
  PatternAgeGroup.preschool: 'P',
  PatternAgeGroup.lowerGrade: 'L',
  PatternAgeGroup.upperGrade: 'U',
  PatternAgeGroup.hundred: '100',
};

const Map<String, PatternAgeGroup> _ageByJson = {
  'baby': PatternAgeGroup.baby,
  'toddler': PatternAgeGroup.toddler,
  'preschool': PatternAgeGroup.preschool,
  'lowerGrade': PatternAgeGroup.lowerGrade,
  'upperGrade': PatternAgeGroup.upperGrade,
};

int _int(Object? v) => (v as num?)?.toInt() ?? 0;

/// 从题库 JSON 还原一张图。
///
/// 每种类型都走 [Pic] 的工厂构造，保证同一个 id 永远渲染成同一张图 ——
/// 答题判定就是靠 id 比对。
Pic picFromJson(Map<String, dynamic> j) {
  final kind = j['kind'] as String;
  return switch (kind) {
    'dots' => Pic.dots(_int(j['n']), base: _int(j['base'])),
    'emojiCount' => Pic.emojiCount(j['emoji'] as String, _int(j['n'])),
    'emojiSingle' => Pic.emojiSingle(j['emoji'] as String),
    'emojiSize' => Pic.emojiSize(j['emoji'] as String, _int(j['level'])),
    'arrowQuarter' => Pic.arrowQuarter(_int(j['level'])),
    'colorRamp' => Pic.colorRamp(_int(j['base']), _int(j['level'])),
    'number' => Pic.number(_int(j['n'])),
    'shape' => Pic.shape(_int(j['base']), quarter: _int(j['level'])),
    'shapeCount' =>
      Pic.shapeCount(_int(j['base']), _int(j['n']), color: _int(j['level'])),
    'dice' => Pic.dice(_int(j['n'])),
    'colorBlock' => Pic.colorBlock(_int(j['base'])),
    'bar' => Pic.bar(_int(j['n'])),
    'lengthBar' => Pic.lengthBar(_int(j['level']), base: _int(j['base'])),
    'thickness' => Pic.thickness(_int(j['level']), base: _int(j['base'])),
    'widthBar' => Pic.widthBar(_int(j['level']), base: _int(j['base'])),
    'candle' => Pic.candle(_int(j['level']), base: _int(j['base'])),
    'pencil' => Pic.pencil(_int(j['level']), base: _int(j['base'])),
    'tree' => Pic.tree(_int(j['level']), base: _int(j['base'])),
    'house' => Pic.house(_int(j['level']), base: _int(j['base'])),
    'tower' => Pic.tower(_int(j['level']), base: _int(j['base'])),
    'pillar' => Pic.pillar(_int(j['level']), base: _int(j['base'])),
    'stick' => Pic.stick(_int(j['level']), base: _int(j['base'])),
    'rod' => Pic.rod(_int(j['level']), base: _int(j['base'])),
    'ribbon' => Pic.ribbon(_int(j['level']), base: _int(j['base'])),
    'blob' => Pic.blob(_int(j['level']), base: _int(j['base'])),
    'balloon' => Pic.balloon(_int(j['level']), base: _int(j['base'])),
    'trunkWidth' => Pic.trunkWidth(_int(j['level']), base: _int(j['base'])),
    'pillarWidth' => Pic.pillarWidth(_int(j['level']), base: _int(j['base'])),
    'dogTree' => Pic.dogTree(_int(j['level']), base: _int(j['base'])),
    'distance' => Pic.distance(_int(j['level']), base: _int(j['base'])),
    'speed' => Pic.speed(_int(j['level']),
        emoji: (j['emoji'] as String?) ?? '🚗', base: _int(j['base'])),
    'depth' => Pic.depth(_int(j['level']), base: _int(j['base'])),
    'queue' => Pic.queue([for (final e in j['emojis'] as List) e as String]),
    'place' => Pic.place(_int(j['level'])),
    'clock' => Pic.clock(_int(j['n']), minute: _int(j['minute'])),
    'asset' => Pic.asset(j['path'] as String, label: j['label'] as String?),
    _ => throw FormatException('未知的图片类型：$kind'),
  };
}

QaQuestion qaQuestionFromJson(Map<String, dynamic> j) {
  final age = _ageByJson[j['age'] as String];
  if (age == null) throw FormatException('未知年龄段：${j['age']}');
  final options = [
    for (final raw in j['options'] as List)
      () {
        final o = Map<String, dynamic>.from(raw as Map);
        final pic = o['pic'];
        return QaOption(
          text: (o['text'] as String?) ?? '',
          pic: pic == null
              ? null
              : picFromJson(Map<String, dynamic>.from(pic as Map)),
        );
      }(),
  ];
  return QaQuestion(
    id: j['id'] as String,
    age: age,
    kind: QaKind.parse(j['kind'] as String),
    sub: (j['sub'] as String?) ?? '',
    prompt: j['prompt'] as String,
    scene: [
      for (final s in (j['scene'] as List?) ?? const [])
        picFromJson(Map<String, dynamic>.from(s as Map)),
    ],
    options: options,
    answer: _int(j['answer']),
    stars: _int(j['stars']),
  );
}

/// 一段朗读里「第 start 到第 end 个字」在什么时间被读出来（单位：秒，媒体时间）。
@immutable
class QaSpan {
  const QaSpan(this.start, this.end, this.from, this.to);

  final int start;
  final int end;
  final double from;
  final double to;
}

/// 一段朗读音频 + 它的逐词时间轴。时间轴用来做「朗读跟读高亮」。
@immutable
class QaVoiceClip {
  const QaVoiceClip({
    required this.asset,
    required this.duration,
    required this.spans,
  });

  /// 相对 assets 根的路径，例如 `audio/qa/xxx.mp3`。
  final String asset;

  /// 音频总时长（秒）。末尾有一段静音，播放时会被截掉。
  final double duration;

  final List<QaSpan> spans;

  /// 有效朗读时长：最后一段的结束时间。末尾静音不听。
  double get voiced => spans.isEmpty ? duration : spans.last.to;

  static QaVoiceClip fromJson(Map<String, dynamic> j) => QaVoiceClip(
        asset: j['f'] as String,
        duration: (j['d'] as num).toDouble(),
        spans: [
          for (final s in j['s'] as List)
            QaSpan(
              (s as List)[0] as int,
              s[1] as int,
              (s[2] as num).toDouble(),
              (s[3] as num).toDouble(),
            ),
        ],
      );
}
