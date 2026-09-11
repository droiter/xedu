import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../state/providers.dart';
import 'pattern_quiz_models.dart';
import 'question_taxonomy.dart';

/// 单道题的作答记录。
///
/// 一次「作答」指这道题被展示一次；[firstTry] 是这次一次就答对，
/// [wrongPicks] 是这次答错的次数（答错后可以再试，所以可能 > 1）。
@immutable
class QuestionStat {
  const QuestionStat({this.attempts = 0, this.firstTry = 0, this.wrongPicks = 0});

  factory QuestionStat.fromJson(Map<String, dynamic> json) => QuestionStat(
        attempts: (json['a'] as num?)?.toInt() ?? 0,
        firstTry: (json['f'] as num?)?.toInt() ?? 0,
        wrongPicks: (json['w'] as num?)?.toInt() ?? 0,
      );

  /// 展示次数。
  final int attempts;

  /// 其中一次答对的次数。
  final int firstTry;

  /// 累计答错次数。
  final int wrongPicks;

  /// 至少答错一次的次数。
  int get missedAttempts => attempts - firstTry;

  /// 一次答对率，0..1。
  double get accuracy => attempts == 0 ? 0 : firstTry / attempts;

  QuestionStat plusAttempt({required int wrong}) => QuestionStat(
        attempts: attempts + 1,
        firstTry: firstTry + (wrong == 0 ? 1 : 0),
        wrongPicks: wrongPicks + wrong,
      );

  Map<String, dynamic> toJson() =>
      {'a': attempts, 'f': firstTry, 'w': wrongPicks};
}

/// 一个账号的「看图找规律」全部做题记录：结构化题 id → 记录。
@immutable
class PatternStats {
  const PatternStats({this.byQuestion = const {}});

  factory PatternStats.fromJson(Map<String, dynamic> json) {
    final raw = json['q'];
    if (raw is! Map) return const PatternStats();
    return PatternStats(
      byQuestion: {
        for (final e in raw.entries)
          e.key as String:
              QuestionStat.fromJson(Map<String, dynamic>.from(e.value as Map)),
      },
    );
  }

  final Map<String, QuestionStat> byQuestion;

  int get totalAttempts =>
      byQuestion.values.fold(0, (s, v) => s + v.attempts);
  int get totalFirstTry => byQuestion.values.fold(0, (s, v) => s + v.firstTry);
  int get totalWrongPicks =>
      byQuestion.values.fold(0, (s, v) => s + v.wrongPicks);

  /// 总体一次答对率，0..1。
  double get accuracy =>
      totalAttempts == 0 ? 0 : totalFirstTry / totalAttempts;

  Map<String, dynamic> toJson() => {
        'q': byQuestion.map((k, v) => MapEntry(k, v.toJson())),
      };
}

/// 做题统计控制器：按登录账号持久化，切换用户时自动加载 / 清空。
class PatternStatsController extends Notifier<PatternStats> {
  @override
  PatternStats build() {
    final uid = ref.watch(authControllerProvider.select((s) => s.user?.id));
    if (uid == null) return const PatternStats();
    final raw = ref.watch(prefsProvider).getString(patternStatsKeyFor(uid));
    if (raw == null || raw.isEmpty) return const PatternStats();
    try {
      return PatternStats.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const PatternStats();
    }
  }

  String? get _uid => ref.read(authControllerProvider).user?.id;

  /// 记录一次作答：[wrong] 为这次答错的次数（0 表示一次答对）。
  void record({required String qid, required int wrong}) {
    final uid = _uid;
    if (uid == null) return;
    final prev = state.byQuestion[qid] ?? const QuestionStat();
    final next = PatternStats(
      byQuestion: {...state.byQuestion, qid: prev.plusAttempt(wrong: wrong)},
    );
    _persist(uid, next);
  }

  /// 清空当前账号的做题记录。
  void clear() {
    final uid = _uid;
    if (uid == null) return;
    _persist(uid, const PatternStats());
  }

  void _persist(String uid, PatternStats next) {
    ref
        .read(prefsProvider)
        .setString(patternStatsKeyFor(uid), jsonEncode(next.toJson()));
    state = next;
  }
}

final patternStatsProvider =
    NotifierProvider<PatternStatsController, PatternStats>(
        PatternStatsController.new);

// ---------- 多维度聚合（纯函数，方便测试） ----------

/// 统计维度。
enum StatDimension {
  age('年龄段'),
  family('规律大类'),
  type('具体类型'),
  difficulty('难度');

  const StatDimension(this.label);

  final String label;
}

/// 某个维度下的一档统计。
@immutable
class StatBucket {
  const StatBucket({
    required this.key,
    required this.label,
    required this.attempts,
    required this.firstTry,
    required this.wrongPicks,
  });

  final String key;
  final String label;
  final int attempts;
  final int firstTry;
  final int wrongPicks;

  int get missedAttempts => attempts - firstTry;
  double get accuracy => attempts == 0 ? 0 : firstTry / attempts;
}

/// 按 [dim] 维度把做题记录聚合成若干档，作答次数多的排前面。
///
/// 题库里已不存在的题 id 会被跳过（记录随题库更新自然衰减）。
List<StatBucket> bucketsBy(PatternStats stats, StatDimension dim) {
  final acc = <String, (String, int, int, int)>{};
  for (final e in stats.byQuestion.entries) {
    final q = questionByQid(e.key);
    if (q == null) continue;
    final (key, label) = _bucketKey(dim, q);
    final prev = acc[key];
    final v = e.value;
    acc[key] = prev == null
        ? (label, v.attempts, v.firstTry, v.wrongPicks)
        : (
            prev.$1,
            prev.$2 + v.attempts,
            prev.$3 + v.firstTry,
            prev.$4 + v.wrongPicks,
          );
  }
  final list = [
    for (final e in acc.entries)
      StatBucket(
        key: e.key,
        label: e.value.$1,
        attempts: e.value.$2,
        firstTry: e.value.$3,
        wrongPicks: e.value.$4,
      ),
  ]..sort((a, b) {
      final byAttempts = b.attempts.compareTo(a.attempts);
      return byAttempts != 0 ? byAttempts : a.label.compareTo(b.label);
    });
  return list;
}

(String, String) _bucketKey(StatDimension dim, PatternQuestion q) =>
    switch (dim) {
      StatDimension.age => (q.age.name, q.age.ageText),
      StatDimension.family =>
        (familyOf(q).code, familyOf(q).label),
      StatDimension.type => (typeOf(q).code, typeOf(q).label),
      StatDimension.difficulty => ('$q.difficulty', '难度 ${'★' * q.difficulty}'),
    };

/// 最容易做错的题：按「答错次数多、一次答对率低」排序。
///
/// 只统计作答达到 [minAttempts] 次的题，避免偶然错一次就上榜。
List<MapEntry<String, QuestionStat>> hardestQuestions(
  PatternStats stats, {
  int minAttempts = 1,
  int limit = 8,
}) {
  final list = stats.byQuestion.entries
      .where((e) =>
          e.value.attempts >= minAttempts &&
          e.value.missedAttempts > 0 &&
          questionByQid(e.key) != null)
      .toList()
    ..sort((a, b) {
      final byWrong = b.value.missedAttempts.compareTo(a.value.missedAttempts);
      if (byWrong != 0) return byWrong;
      final byRate = a.value.accuracy.compareTo(b.value.accuracy);
      if (byRate != 0) return byRate;
      return a.key.compareTo(b.key);
    });
  return list.take(limit).toList();
}

/// 「年龄段 × 规律大类」交叉表：行是年龄，列是大类，值是 [StatBucket]。
///
/// 用于一眼看出「哪个年龄段的哪类规律最薄弱」。
List<({String label, Map<String, StatBucket> cells})> crossByAgeFamily(
    PatternStats stats) {
  final rows = <String, String>{};
  final cells = <String, Map<String, StatBucket>>{};

  void add(String ageKey, String ageLabel, String famKey, QuestionStat v) {
    rows[ageKey] = ageLabel;
    final row = cells.putIfAbsent(ageKey, () => {});
    final prev = row[famKey];
    row[famKey] = prev == null
        ? StatBucket(
            key: famKey,
            label: famKey,
            attempts: v.attempts,
            firstTry: v.firstTry,
            wrongPicks: v.wrongPicks,
          )
        : StatBucket(
            key: famKey,
            label: famKey,
            attempts: prev.attempts + v.attempts,
            firstTry: prev.firstTry + v.firstTry,
            wrongPicks: prev.wrongPicks + v.wrongPicks,
          );
  }

  for (final e in stats.byQuestion.entries) {
    final q = questionByQid(e.key);
    if (q == null) continue;
    add(q.age.name, q.age.ageText, familyOf(q).code, e.value);
  }

  final ordered = rows.entries.toList()
    ..sort((a, b) {
      final ai = PatternAgeGroup.values.indexWhere((g) => g.name == a.key);
      final bi = PatternAgeGroup.values.indexWhere((g) => g.name == b.key);
      return ai.compareTo(bi);
    });

  return [
    for (final e in ordered) (label: e.value, cells: cells[e.key] ?? const {}),
  ];
}
