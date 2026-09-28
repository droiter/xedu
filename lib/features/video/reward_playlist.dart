import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../shared/reward_rule.dart';
import '../../state/video_library.dart';
import '../../state/video_progress.dart';

/// 续播时「只剩个尾巴」的判据：上次停在离片尾这么近的地方，就当没看过、从头放。
///
/// 否则一进播放页就闪一下「放完」，接着又去开下一片。
const int kResumeTailSeconds = 2;

/// 一次奖励播放：在这局的总额度里，按 [videos] 的顺序一片接一片地放。
///
/// 每片都从 [VideoProgress] 里记着的地方续播；一片放完还有额度就接着放下一个，
/// 额度用完（或者孩子按了返回）就回答题页。
@immutable
class RewardPlayback {
  const RewardPlayback({
    required this.videos,
    required this.index,
    required this.stepSeconds,
    required this.minSeconds,
  });

  /// 播放顺序，至少一个。第一个就是「这一局先放哪个」。
  final List<VideoItem> videos;

  /// 第几次奖励（从 1 起）。
  final int index;

  /// 每次少看几秒（A）。
  final int stepSeconds;

  /// 最少能看几秒（B）。
  final int minSeconds;

  /// 这局的额度按 [RewardWatchLimit] 那套算式算 —— 片长要等播放器
  /// 初始化完才知道，所以这里只带参数，到播放页再算秒数。
  RewardWatchLimit get limit => RewardWatchLimit(
        index: index,
        stepSeconds: stepSeconds,
        minSeconds: minSeconds,
      );
}

/// [planRewardPlaylist] 的结果。
@immutable
class RewardPlan {
  const RewardPlan({required this.videos, required this.restarted});

  /// 这一局的播放顺序。
  final List<VideoItem> videos;

  /// true = 「我的视频」里全都看完过一遍了，进度表该清空重来（从头再轮一轮）。
  final bool restarted;
}

/// 排这一局奖励的播放顺序。
///
/// 先挑没看完过的（随机打乱）；一个不剩说明全都看完过一轮了 —— 这时返回
/// `restarted: true`，由调用方把进度表清空（孩子从头再轮一轮），顺序仍取全部片子。
/// [avoid] 是刚放完的那一个，只要还有别的可选就不排在第一个（别接着重放同一片）。
RewardPlan planRewardPlaylist({
  required VideoLibrary library,
  required VideoProgress progress,
  String? avoid,
  Random? rng,
}) {
  final random = rng ?? Random();
  final all = [
    for (final c in library.categories) ...c.videos,
  ];
  if (all.isEmpty) return const RewardPlan(videos: [], restarted: false);

  var pool = [
    for (final v in all)
      if (!progress.watchedToEnd(v.id)) v,
  ];
  final restarted = pool.isEmpty;
  if (restarted) pool = [...all];

  final order = [...pool]..shuffle(random);
  if (order.length > 1 && avoid != null && order.first.id == avoid) {
    final j = 1 + random.nextInt(order.length - 1);
    final first = order[0];
    order[0] = order[j];
    order[j] = first;
  }
  return RewardPlan(videos: order, restarted: restarted);
}
