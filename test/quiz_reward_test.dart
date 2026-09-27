import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xedu/core/constants.dart';
import 'package:xedu/features/pattern_quiz/quiz_reward.dart';
import 'package:xedu/state/providers.dart';

typedef _Host = (ProviderContainer, SharedPreferences);

Future<_Host> _host([Map<String, Object> seed = const {}]) async {
  SharedPreferences.setMockInitialValues(seed);
  final prefs = await SharedPreferences.getInstance();
  return (_container(prefs), prefs);
}

ProviderContainer _container(SharedPreferences prefs) => ProviderContainer(
      overrides: [prefsProvider.overrideWithValue(prefs)],
    );

/// 直接读存储里那一份，验证的才是「真的落盘了」。
Map<String, dynamic> _onDisk(SharedPreferences prefs) =>
    jsonDecode(prefs.getString(kQuizRewardKey)!) as Map<String, dynamic>;

void main() {
  group('缺省配置', () {
    test('X=3 / Y=5 / A=30 / B=30，计数从 0 开始', () async {
      final (c, _) = await _host();
      addTearDown(c.dispose);
      final s = c.read(quizRewardProvider);
      expect(s.firstBlackoutSeconds, 3);
      expect(s.maxBlackoutSeconds, 5);
      expect(s.rewardStepSeconds, 30);
      expect(s.rewardMinSeconds, 30);
      expect(s.wrongTotal, 0);
      expect(s.blackoutCount, 0);
      expect(s.rewardCount, 0);
    });
  });

  group('答错计数', () {
    test('前两次不罚，第三次起每次答错都返回该黑几秒', () async {
      final (c, prefs) = await _host();
      addTearDown(c.dispose);
      final n = c.read(quizRewardProvider.notifier);

      expect(await n.registerWrong(), isNull);
      expect(await n.registerWrong(), isNull);
      expect(await n.registerWrong(), 3); // 第一次黑屏：X
      expect(await n.registerWrong(), 4);
      expect(await n.registerWrong(), 5); // 到 Y 封顶
      expect(await n.registerWrong(), 5);

      final s = c.read(quizRewardProvider);
      expect(s.wrongTotal, 6);
      // 黑屏过 4 次：第 3 / 4 / 5 / 6 次答错各一次
      expect(s.blackoutCount, 4);
      expect(_onDisk(prefs)['w'], 6);
    });

    test('计数落盘：换个容器（＝重启 App）接着累计，档位也接得上', () async {
      final (a, prefs) = await _host();
      final na = a.read(quizRewardProvider.notifier);
      await na.registerWrong();
      await na.registerWrong();
      await na.registerWrong();
      a.dispose();

      // 同一个存储上重开一个容器，相当于把 App 重启一遍。
      final b = _container(prefs);
      addTearDown(b.dispose);
      expect(b.read(quizRewardProvider).wrongTotal, 3);
      // 上一轮已经黑过一次，这次答错该给第二档 4 秒。
      expect(await b.read(quizRewardProvider.notifier).registerWrong(), 4);
    });
  });

  group('奖励计数', () {
    test('每奖励一次记一笔，返回的是第几次（1 起，播放页拿它算时长）', () async {
      final (c, prefs) = await _host();
      addTearDown(c.dispose);
      final n = c.read(quizRewardProvider.notifier);
      expect(await n.registerReward(), 1);
      expect(await n.registerReward(), 2);
      expect(c.read(quizRewardProvider).rewardCount, 2);
      expect(_onDisk(prefs)['rc'], 2);
    });
  });

  group('配置', () {
    test('改完存下来，越界的数夹回范围', () async {
      final (c, prefs) = await _host();
      addTearDown(c.dispose);
      await c.read(quizRewardProvider.notifier).setConfig(
            firstBlackoutSeconds: 8,
            maxBlackoutSeconds: 0,
            rewardStepSeconds: 9999,
            rewardMinSeconds: -5,
          );
      final s = c.read(quizRewardProvider);
      expect(s.firstBlackoutSeconds, 8);
      expect(s.maxBlackoutSeconds, kMinBlackoutSeconds);
      expect(s.rewardStepSeconds, kMaxRewardStepSecondsLimit);
      expect(s.rewardMinSeconds, kMinRewardMinSeconds);
      expect(_onDisk(prefs)['x'], 8);
    });

    test('清零只清计数，配置留着', () async {
      final (c, _) = await _host();
      addTearDown(c.dispose);
      final n = c.read(quizRewardProvider.notifier);
      await n.setConfig(
        firstBlackoutSeconds: 4,
        maxBlackoutSeconds: 9,
        rewardStepSeconds: 15,
        rewardMinSeconds: 20,
      );
      await n.registerWrong();
      await n.registerWrong();
      await n.registerWrong();
      await n.registerReward();

      await n.resetCounters();
      final s = c.read(quizRewardProvider);
      expect(s.wrongTotal, 0);
      expect(s.blackoutCount, 0);
      expect(s.rewardCount, 0);
      expect(s.firstBlackoutSeconds, 4);
      expect(s.maxBlackoutSeconds, 9);
      expect(s.rewardStepSeconds, 15);
      expect(s.rewardMinSeconds, 20);
    });

    test('存储里是坏数据时退回缺省，不炸', () async {
      final (c, _) = await _host({kQuizRewardKey: '这不是 json'});
      addTearDown(c.dispose);
      expect(c.read(quizRewardProvider).firstBlackoutSeconds, 3);
    });
  });
}
