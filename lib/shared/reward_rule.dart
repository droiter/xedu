/// 做题奖惩的两条算式（纯函数 + 一个小值对象，方便测试）。
library;

import 'package:flutter/foundation.dart';

/// 累计答错**超过**这么多次之后，再答错才开始黑屏。
///
/// 也就是第 3 次答错才吃第一回黑屏；前两次只是普通的答错反馈。
const int kPunishAfterWrongs = 2;

/// 第 [count] 次黑屏（从 1 起）该黑几秒：X + (count - 1)，封顶 Y。
///
/// 家长把 Y 设得比 X 还小时按 X 封顶，免得「越长越短」这种反直觉的惩罚。
int blackoutSeconds({
  required int count,
  required int firstSeconds,
  required int maxSeconds,
}) {
  if (count < 1) return 0;
  final cap = maxSeconds < firstSeconds ? firstSeconds : maxSeconds;
  final seconds = firstSeconds + (count - 1);
  return seconds > cap ? cap : seconds;
}

/// 第 [rewardIndex] 次奖励（从 1 起）能看几秒。
///
/// 第一次（[rewardIndex] == 1）看完整片；之后每次少 A 秒，但不低于 B 秒。
/// 片子本身比 B 还短时不会因为 B 而「变长」，所以下限取 min(B, 片长)。
int rewardWatchSeconds({
  required int videoSeconds,
  required int rewardIndex,
  required int stepSeconds,
  required int minSeconds,
}) {
  if (rewardIndex <= 1) return videoSeconds;
  final floor = minSeconds < videoSeconds ? minSeconds : videoSeconds;
  final target = videoSeconds - stepSeconds * (rewardIndex - 1);
  return target < floor ? floor : target;
}

/// 一次「奖励看视频」的额度：第几次奖励 + 家长定的 A / B。
///
/// 片长要等播放器初始化完才知道，所以这里只带参数，到播放页再算秒数。
@immutable
class RewardWatchLimit {
  const RewardWatchLimit({
    required this.index,
    required this.stepSeconds,
    required this.minSeconds,
  });

  /// 第几次奖励（从 1 起）。
  final int index;

  /// 每次少看几秒（A）。
  final int stepSeconds;

  /// 最少能看几秒（B）。
  final int minSeconds;

  /// 第一次奖励：整片看完，不截断。
  bool get isFull => index <= 1;

  /// 整片 [full] 时长下，这次能看多久。
  Duration limitFor(Duration full) => Duration(
        seconds: rewardWatchSeconds(
          videoSeconds: full.inSeconds,
          rewardIndex: index,
          stepSeconds: stepSeconds,
          minSeconds: minSeconds,
        ),
      );
}
