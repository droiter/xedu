import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xedu/core/constants.dart';
import 'package:xedu/features/pattern_quiz/pattern_quiz_bank.dart';
import 'package:xedu/features/pattern_quiz/pattern_quiz_models.dart';
import 'package:xedu/features/pattern_quiz/pattern_stats.dart';
import 'package:xedu/features/pattern_quiz/question_taxonomy.dart';
import 'package:xedu/state/providers.dart';

PatternQuestion _byAge(PatternAgeGroup age) =>
    kPatternQuestions.firstWhere((q) => q.age == age);

PatternQuestion _byFamily(PatternFamily f) =>
    kPatternQuestions.firstWhere((q) => familyOf(q) == f);

PatternStats _stats(Map<String, QuestionStat> m) => PatternStats(byQuestion: m);

void main() {
  group('单题记录', () {
    test('每次作答累加：首答对 / 答错次数分别统计', () {
      final s = const QuestionStat()
          .plusAttempt(wrong: 0)
          .plusAttempt(wrong: 2)
          .plusAttempt(wrong: 1);
      expect(s.attempts, 3);
      expect(s.firstTry, 1);
      expect(s.wrongPicks, 3);
      expect(s.missedAttempts, 2);
      expect(s.accuracy, closeTo(1 / 3, 1e-9));
    });
  });

  group('序列化', () {
    test('记录能原样存取（按账号持久化用）', () {
      final q = kPatternQuestions.first;
      final qid = qidOf(q);
      final stats = _stats({
        qid: const QuestionStat(attempts: 5, firstTry: 3, wrongPicks: 4),
      });
      final back = PatternStats.fromJson(
          jsonDecode(jsonEncode(stats.toJson())) as Map<String, dynamic>);
      expect(back.byQuestion[qid]!.attempts, 5);
      expect(back.byQuestion[qid]!.firstTry, 3);
      expect(back.byQuestion[qid]!.wrongPicks, 4);
    });

    test('空数据 / 脏数据不炸', () {
      expect(PatternStats.fromJson(const {}).totalAttempts, 0);
      expect(PatternStats.fromJson(const {'q': 'bad'}).totalAttempts, 0);
    });
  });

  group('多维度聚合', () {
    test('按年龄段聚合', () {
      final a = _byAge(PatternAgeGroup.baby);
      final b = _byAge(PatternAgeGroup.toddler);
      final stats = _stats({
        qidOf(a): const QuestionStat(attempts: 2, firstTry: 2),
        qidOf(b): const QuestionStat(attempts: 3, firstTry: 1, wrongPicks: 2),
      });
      final buckets = bucketsBy(stats, StatDimension.age);
      expect(buckets.length, 2);
      final baby = buckets.firstWhere((x) => x.key == PatternAgeGroup.baby.name);
      expect(baby.attempts, 2);
      expect(baby.accuracy, 1.0);
    });

    test('按规律大类聚合会把同类题合并', () {
      final qs = kPatternQuestions
          .where((q) => familyOf(q) == PatternFamily.sequence)
          .take(2)
          .toList();
      final stats = _stats({
        qidOf(qs[0]): const QuestionStat(attempts: 2, firstTry: 2),
        qidOf(qs[1]): const QuestionStat(attempts: 2, firstTry: 0, wrongPicks: 3),
      });
      final bucket = bucketsBy(stats, StatDimension.family)
          .firstWhere((x) => x.key == PatternFamily.sequence.code);
      expect(bucket.attempts, 4);
      expect(bucket.firstTry, 2);
      expect(bucket.wrongPicks, 3);
      expect(bucket.accuracy, 0.5);
    });

    test('题库里已删除的题 id 会被跳过', () {
      final stats = _stats({
        'PT.Z.OTH.gone': const QuestionStat(attempts: 9, firstTry: 0),
        qidOf(kPatternQuestions.first): const QuestionStat(attempts: 1, firstTry: 1),
      });
      expect(bucketsBy(stats, StatDimension.age).single.attempts, 1);
    });
  });

  group('易错题', () {
    test('只挑答错过的题，按答错次数排序', () {
      final hard = _byFamily(PatternFamily.sequence);
      final easy = _byFamily(PatternFamily.recognition);
      final stats = _stats({
        qidOf(hard): const QuestionStat(attempts: 4, firstTry: 1, wrongPicks: 5),
        qidOf(easy): const QuestionStat(attempts: 4, firstTry: 4),
      });
      final list = hardestQuestions(stats);
      expect(list.length, 1);
      expect(list.single.key, qidOf(hard));
    });
  });

  group('年龄段 × 规律大类交叉表', () {
    test('每个出现过的年龄段一行', () {
      final a = _byAge(PatternAgeGroup.baby);
      final p = _byAge(PatternAgeGroup.preschool);
      final stats = _stats({
        qidOf(a): const QuestionStat(attempts: 2, firstTry: 1, wrongPicks: 1),
        qidOf(p): const QuestionStat(attempts: 3, firstTry: 3),
      });
      final rows = crossByAgeFamily(stats);
      expect(rows.length, 2);
      final babyRow = rows.firstWhere((r) => r.label == PatternAgeGroup.baby.ageText);
      expect(babyRow.cells[familyOf(a).code]!.attempts, 2);
    });
  });

  group('统计控制器', () {
    test('record 累加并写入当前账号的独立 key', () async {
      SharedPreferences.setMockInitialValues({
        kSessionKey:
            jsonEncode({'id': 'u1', 'name': '测试', 'email': 't@x.com'}),
      });
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [prefsProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final qid = qidOf(kPatternQuestions.first);
      final ctrl = container.read(patternStatsProvider.notifier);
      ctrl.record(qid: qid, wrong: 0);
      ctrl.record(qid: qid, wrong: 2);

      final s = container.read(patternStatsProvider);
      expect(s.byQuestion[qid]!.attempts, 2);
      expect(s.byQuestion[qid]!.firstTry, 1);
      expect(s.byQuestion[qid]!.wrongPicks, 2);
      expect(prefs.getString(patternStatsKeyFor('u1')), isNotNull);
    });

    test('没登录时记录写进游客档，登录后看的是账号那一档', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [prefsProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final qid = qidOf(kPatternQuestions.first);
      container.read(patternStatsProvider.notifier).record(qid: qid, wrong: 0);
      expect(container.read(patternStatsProvider).totalAttempts, 1);
      expect(prefs.getString(patternStatsKeyFor(kGuestUid)), isNotNull);

      // 注册一个账号：游客档的题不进账号里，账号自己从零开始记。
      await container
          .read(authControllerProvider.notifier)
          .register('小明', 'x@x.com', '1234');
      expect(container.read(patternStatsProvider).totalAttempts, 0);

      container.read(patternStatsProvider.notifier).record(qid: qid, wrong: 0);
      expect(container.read(patternStatsProvider).totalAttempts, 1);
      expect(
        container.read(patternStatsProvider).byQuestion[qid]!.attempts,
        1,
        reason: '账号这一档只该有登录之后做的那一次',
      );
    });
  });
}
