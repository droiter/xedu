import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../pattern_quiz/pattern_quiz_models.dart';
import 'qa_models.dart';

/// 题目数据文件。语音清单由 `scripts/gen_qa_voice.py` 生成，和题库一一对应。
const String kQaQuestionsAsset = 'assets/data/qa_questions.json';
const String kQaVoiceAsset = 'assets/data/qa_voice.json';

/// 加载完成的「看图问答」题库：题目 + 语音时间轴。
class QaBank {
  const QaBank({required this.questions, required this.clips});

  final List<QaQuestion> questions;

  /// 片段键 → 音频与时间轴。键就是题号（点换成下划线）或 `题号.o2`。
  final Map<String, QaVoiceClip> clips;

  bool get isEmpty => questions.isEmpty;

  /// 某个年龄段的题目。
  List<QaQuestion> forAge(PatternAgeGroup age) =>
      [for (final q in questions) if (q.age == age) q];

  /// 多个年龄段的合并题库，按年龄段由小到大拼接。
  List<QaQuestion> forAges(Iterable<PatternAgeGroup> ages) {
    final set = ages.toSet();
    return [
      for (final g in PatternAgeGroup.values)
        if (set.contains(g)) ...forAge(g),
    ];
  }

  QaVoiceClip? clipOf(String key) => clips[key];

  /// 某题的题面语音（阅读选图题没有）。
  QaVoiceClip? promptClip(QaQuestion q) => clips[q.clipKey];

  /// 某题第 [i] 个选项的语音（选项没文字就没有）。
  QaVoiceClip? optionClip(QaQuestion q, int i) => clips[q.optionClipKey(i)];

  static QaBank parse(String questionsJson, String voiceJson) {
    final qs = jsonDecode(questionsJson) as Map<String, dynamic>;
    final rawQuestions = qs['questions'] as List;

    final clips = <String, QaVoiceClip>{};
    final vs = jsonDecode(voiceJson) as Map<String, dynamic>;
    for (final e in (vs['clips'] as Map).entries) {
      clips[e.key as String] =
          QaVoiceClip.fromJson(Map<String, dynamic>.from(e.value as Map));
    }

    return QaBank(
      questions: [
        for (final raw in rawQuestions)
          qaQuestionFromJson(Map<String, dynamic>.from(raw as Map)),
      ],
      clips: clips,
    );
  }

  static Future<QaBank> load() async {
    final results = await Future.wait([
      rootBundle.loadString(kQaQuestionsAsset),
      rootBundle.loadString(kQaVoiceAsset),
    ]);
    return parse(results[0], results[1]);
  }
}

/// 题库只在 App 启动后加载一次，之后所有页面共用。
final qaBankProvider = FutureProvider<QaBank>((ref) => QaBank.load());
