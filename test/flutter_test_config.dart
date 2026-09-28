import 'dart:async';

import 'package:xedu/features/pattern_quiz/quiz_reward_fx.dart';

/// 所有测试跑起来之前的统一设置。
///
/// 测试环境里没有音频平台通道：`audioplayers` 的 `setReleaseMode` / `stop` /
/// `dispose` 这类调用会一直挂着不回调（`play` 反倒立刻抛异常）。奖惩播报真机上
/// 愿意等 8 秒起播，测试里等这 8 秒纯属白等（还留下 pending timer），调短。
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  RewardVoice.startCap = const Duration(milliseconds: 20);
  await testMain();
}
