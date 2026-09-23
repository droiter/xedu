import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xedu/features/qa_quiz/qa_models.dart';
import 'package:xedu/features/qa_quiz/qa_speech.dart';

/// 「六个」这一段（QA.L.DESC.COUNT.triangle-count 的答案）。
const _clip = QaVoiceClip(
  asset: 'audio/qa/QA_L_DESC_COUNT_triangle-count.o2.mp3',
  duration: 1.872,
  spans: [QaSpan(0, 1, 0.1, 0.3875), QaSpan(1, 2, 0.3875, 0.6875)],
);

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
          ? Directory.systemTemp.createTempSync('xedu_qa').path
          : null,
    );
  });

  tearDown(() => QaSpeech.instance.stop());

  /// 送进播放器的语速，按发送顺序。
  List<Object?> sentRates() => [
        for (final c in calls)
          if (c.method == 'setPlaybackRate')
            (c.arguments as Map)['playbackRate'],
      ];

  test('每一段起播前就把语速送进播放器，1.0 也要送', () async {
    // Android / iOS 都只是把语速**存下来**（播放中才立刻生效），再按它起播。要 1.0
    // 时干脆不送，播放器里就留着上一档的 0.6：声音慢着读，计时表却按 1.0 推 ——
    // 高亮被一次次往回拨，光标就在相邻两个字之间来回跳。
    QaSpeech.instance.rate = 1.0;
    // 起播会等播放器发回「已准备好」的事件，测试里没有播放器，等不到 —— 所以不等它，
    // 只看语速有没有送出去（它排在起播之前，所以这时候就该到了）。
    unawaited(QaSpeech.instance.speak('k', _clip));
    await pumpEventQueue();

    expect(sentRates(), contains(1.0), reason: '1.0 没送进播放器：$calls');
  });

  test('慢速那一档也送', () async {
    QaSpeech.instance.rate = 0.6;
    unawaited(QaSpeech.instance.speak('k', _clip));
    await pumpEventQueue();

    expect(sentRates(), contains(0.6), reason: '0.6 没送进播放器：$calls');
  });
}
