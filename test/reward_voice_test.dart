import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xedu/features/pattern_quiz/quiz_reward_fx.dart';
import 'package:xedu/features/qa_quiz/qa_speech.dart';

void main() {
  // 测试环境没有音频插件，把通道接管过来：既让播放器能建起来，也顺手记下都发了什么。
  TestWidgetsFlutterBinding.ensureInitialized();

  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final name in const [
      'xyz.luan/audioplayers',
      'xyz.luan/audioplayers.global',
    ]) {
      messenger.setMockMethodCallHandler(MethodChannel(name), (call) async {
        calls.add(call);
        return null;
      });
    }
    // 放资源音频时播放器要一个临时目录把 mp3 拷出去（音频插件自己不提供这个）。
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => call.method == 'getTemporaryDirectory'
          ? Directory.systemTemp.createTempSync('xedu_reward').path
          : null,
    );
  });

  tearDown(() => RewardVoice.instance.dispose());

  test('朗读语速调快调慢都跟奖惩播报无关：播这两句时不碰变速', () async {
    // 家长把朗读语速调到最慢，再调到最快 —— 奖惩播报的语速是烤在音频里的，
    // 这两下都不该让播放器收到变速指令（收到了就说明又被朗读语速带跑了）。
    for (final rate in const [QaSpeech.minRate, QaSpeech.maxRate]) {
      QaSpeech.instance.rate = rate;
      unawaited(RewardVoice.instance.sayPunish());
      unawaited(RewardVoice.instance.sayReward());
      await pumpEventQueue();
    }

    expect(
      [for (final c in calls) if (c.method == 'setPlaybackRate') c.arguments],
      isEmpty,
      reason: '奖惩播报跟着朗读语速变速了：$calls',
    );
    // 顺带确认这两句真的走到播放器跟前了 —— 否则上面那条「没变速」是空过的。
    final sources = [
      for (final c in calls)
        if (c.method == 'setSourceUrl') (c.arguments as Map)['url'] as String,
    ];
    expect(sources.where((u) => u.contains('punish_black.mp3')), isNotEmpty,
        reason: '「答错了，黑屏」没送到播放器：$sources');
    expect(sources.where((u) => u.contains('reward_video.mp3')), isNotEmpty,
        reason: '「一次答对，奖励看视频」没送到播放器：$sources');
  });

  test('奖惩播报念的就是这两句，且都是加过速的', () {
    // 时长直接从 mp3 上算：生成脚本按 +40% 合成（朗读语速最快的那一档），
    // 谁要是把 RATE 改回 +0%、或者忘了重新生成，这两句又会拖成 2.3 / 2.9 秒。
    for (final (asset, length) in const [
      (RewardVoice.punishAsset, RewardVoice.punishLength),
      (RewardVoice.rewardAsset, RewardVoice.rewardLength),
    ]) {
      final ms = _mp3Ms(
          File('assets/audio/${asset.split('/').last}').readAsBytesSync());
      expect(ms, lessThanOrEqualTo(2150),
          reason: '$asset 又变回原速了（${ms}ms）—— 看一眼生成脚本的 RATE');
      // 常量是「等它念完」的上限：不能比真音频短（念到一半就被掐），也别长太多（白等）。
      expect(ms, lessThanOrEqualTo(length.inMilliseconds),
          reason: '$asset 比写死的时长还长，念完的上限不够');
      expect(length.inMilliseconds - ms, lessThan(120),
          reason: '$asset 的时长常量比真音频长得太多，播完还要干等');
    }
  });
}

/// mp3 时长（毫秒）。
///
/// edge-tts 出的是 CBR 24kHz / 48kbps 单声道、不带 ID3 头，字节数 ÷ 码率就是时长。
/// 先把帧头认一遍：格式哪天变了（换成别的码率 / 立体声）就让这条直接红，
/// 而不是悄悄算出一个不对的秒数。
int _mp3Ms(Uint8List b) {
  expect(b[0], 0xFF);
  expect(b[1] & 0xE0, 0xE0, reason: '帧同步字不对，这不像 mp3');
  expect((b[1] >> 3) & 0x3, 2, reason: '不再是 MPEG2，48kbps 那张码率表就不适用了');
  expect((b[1] >> 1) & 0x3, 1, reason: '不再是 Layer III');
  expect((b[2] >> 4) & 0xF, 6, reason: '码率不再是 48kbps，字节数 ÷ 码率就不成立');
  expect((b[2] >> 2) & 0x3, 1, reason: '采样率不再是 24kHz');
  return (b.length * 8 / 48).round(); // 48000 bps = 每秒 6000 字节
}
