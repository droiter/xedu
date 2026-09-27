import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../shared/reward_rule.dart';
import '../../state/providers.dart';

/// 逾期不改的缺省值：黑屏 3 秒起、最长 5 秒；每次少看 30 秒、最少看 30 秒。
const int kDefaultFirstBlackoutSeconds = 3;
const int kDefaultMaxBlackoutSeconds = 5;
const int kDefaultRewardStepSeconds = 30;
const int kDefaultRewardMinSeconds = 30;

/// 家长可填的范围：小了没意义，大了孩子等不起 / 看着看着就天亮了。
const int kMinBlackoutSeconds = 1;
const int kMaxBlackoutSecondsLimit = 60;
const int kMinRewardStepSeconds = 1;
const int kMaxRewardStepSecondsLimit = 600;
const int kMinRewardMinSeconds = 0;
const int kMaxRewardMinSecondsLimit = 600;

/// 做题奖惩的全部状态：四条家长配置 + 三个累计计数。
///
/// 全机一份（和视频库、朗读语速一样），不按账号隔离 —— 换个账号也是同一个孩子。
@immutable
class QuizRewardState {
  const QuizRewardState({
    this.firstBlackoutSeconds = kDefaultFirstBlackoutSeconds,
    this.maxBlackoutSeconds = kDefaultMaxBlackoutSeconds,
    this.rewardStepSeconds = kDefaultRewardStepSeconds,
    this.rewardMinSeconds = kDefaultRewardMinSeconds,
    this.wrongTotal = 0,
    this.blackoutCount = 0,
    this.rewardCount = 0,
  });

  factory QuizRewardState.fromJson(Map<String, dynamic> json) => QuizRewardState(
        firstBlackoutSeconds: _int(json['x'], kDefaultFirstBlackoutSeconds),
        maxBlackoutSeconds: _int(json['y'], kDefaultMaxBlackoutSeconds),
        rewardStepSeconds: _int(json['a'], kDefaultRewardStepSeconds),
        rewardMinSeconds: _int(json['b'], kDefaultRewardMinSeconds),
        wrongTotal: _int(json['w'], 0),
        blackoutCount: _int(json['bc'], 0),
        rewardCount: _int(json['rc'], 0),
      );

  /// X：第一次黑屏几秒。
  final int firstBlackoutSeconds;

  /// Y：黑屏最长几秒。
  final int maxBlackoutSeconds;

  /// A：每次奖励少看几秒。
  final int rewardStepSeconds;

  /// B：奖励最少能看几秒。
  final int rewardMinSeconds;

  /// 累计答错次数（跨重启累计，家长可以在设置里清零）。
  final int wrongTotal;

  /// 已经黑屏过几次（决定这次黑几秒）。
  final int blackoutCount;

  /// 已经奖励过几次（决定这次能看多久）。
  final int rewardCount;

  QuizRewardState copyWith({
    int? firstBlackoutSeconds,
    int? maxBlackoutSeconds,
    int? rewardStepSeconds,
    int? rewardMinSeconds,
    int? wrongTotal,
    int? blackoutCount,
    int? rewardCount,
  }) =>
      QuizRewardState(
        firstBlackoutSeconds: firstBlackoutSeconds ?? this.firstBlackoutSeconds,
        maxBlackoutSeconds: maxBlackoutSeconds ?? this.maxBlackoutSeconds,
        rewardStepSeconds: rewardStepSeconds ?? this.rewardStepSeconds,
        rewardMinSeconds: rewardMinSeconds ?? this.rewardMinSeconds,
        wrongTotal: wrongTotal ?? this.wrongTotal,
        blackoutCount: blackoutCount ?? this.blackoutCount,
        rewardCount: rewardCount ?? this.rewardCount,
      );

  Map<String, dynamic> toJson() => {
        'x': firstBlackoutSeconds,
        'y': maxBlackoutSeconds,
        'a': rewardStepSeconds,
        'b': rewardMinSeconds,
        'w': wrongTotal,
        'bc': blackoutCount,
        'rc': rewardCount,
      };

  static int _int(Object? raw, int fallback) =>
      raw is num ? raw.toInt() : fallback;
}

/// 奖惩配置 + 计数，落盘到 SharedPreferences。
class QuizRewardController extends Notifier<QuizRewardState> {
  @override
  QuizRewardState build() => _load();

  QuizRewardState _load() {
    try {
      final raw = ref.read(prefsProvider).getString(kQuizRewardKey);
      if (raw == null || raw.isEmpty) return const QuizRewardState();
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const QuizRewardState();
      return QuizRewardState.fromJson(decoded.cast<String, dynamic>());
    } catch (_) {
      return const QuizRewardState();
    }
  }

  Future<void> _save(QuizRewardState next) async {
    state = next;
    await ref
        .read(prefsProvider)
        .setString(kQuizRewardKey, jsonEncode(next.toJson()));
  }

  /// 记一次答错。**该黑屏就返回黑几秒**，还不到次数返回 null。
  ///
  /// 落盘要等写完再返回：两笔计数抢着写的话，先发的那笔可能后到，
  /// 盘上留下的就不是最新的那份了。
  Future<int?> registerWrong() async {
    final wrongTotal = state.wrongTotal + 1;
    if (wrongTotal <= kPunishAfterWrongs) {
      await _save(state.copyWith(wrongTotal: wrongTotal));
      return null;
    }
    final count = state.blackoutCount + 1;
    final seconds = blackoutSeconds(
      count: count,
      firstSeconds: state.firstBlackoutSeconds,
      maxSeconds: state.maxBlackoutSeconds,
    );
    await _save(state.copyWith(wrongTotal: wrongTotal, blackoutCount: count));
    return seconds;
  }

  /// 记一次奖励，返回这是第几次（1 起）—— 播放页按它算能看多久。
  Future<int> registerReward() async {
    final count = state.rewardCount + 1;
    await _save(state.copyWith(rewardCount: count));
    return count;
  }

  /// 改配置（家长在设置里填的四个数），越界的一律夹到范围内。
  Future<void> setConfig({
    required int firstBlackoutSeconds,
    required int maxBlackoutSeconds,
    required int rewardStepSeconds,
    required int rewardMinSeconds,
  }) =>
      _save(state.copyWith(
        firstBlackoutSeconds: _clamp(
            firstBlackoutSeconds, kMinBlackoutSeconds, kMaxBlackoutSecondsLimit),
        maxBlackoutSeconds: _clamp(
            maxBlackoutSeconds, kMinBlackoutSeconds, kMaxBlackoutSecondsLimit),
        rewardStepSeconds: _clamp(rewardStepSeconds, kMinRewardStepSeconds,
            kMaxRewardStepSecondsLimit),
        rewardMinSeconds: _clamp(
            rewardMinSeconds, kMinRewardMinSeconds, kMaxRewardMinSecondsLimit),
      ));

  /// 只清计数，不动配置：让孩子重新从「前两次不罚」开始。
  Future<void> resetCounters() => _save(state.copyWith(
        wrongTotal: 0,
        blackoutCount: 0,
        rewardCount: 0,
      ));

  static int _clamp(int v, int lo, int hi) => v < lo ? lo : (v > hi ? hi : v);
}

final quizRewardProvider =
    NotifierProvider<QuizRewardController, QuizRewardState>(
        QuizRewardController.new);
