import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:xedu/core/constants.dart';
import 'package:xedu/features/pattern_quiz/quiz_reward_fx.dart';
import 'package:xedu/features/pattern_quiz/quiz_reward_settings.dart';
import 'package:xedu/features/qa_quiz/qa_bank.dart';
import 'package:xedu/features/qa_quiz/qa_models.dart';
import 'package:xedu/features/qa_quiz/qa_quiz_screen.dart';
import 'package:xedu/features/video/reward_playlist.dart';
import 'package:xedu/features/video/video_player_screen.dart';
import 'package:xedu/state/providers.dart';
import 'package:xedu/state/video_progress.dart';

import 'fixtures.dart';

/// 全量题库（直接读磁盘，绕开 rootBundle）。
final QaBank _full = QaBank.parse(
  File('assets/data/qa_questions.json').readAsStringSync(),
  File('assets/data/qa_voice.json').readAsStringSync(),
);

QaQuestion _q(String age, String id) => _full.questions.firstWhere(
      (q) => q.id == id && q.age.name == age,
      orElse: () => throw StateError('题库里找不到 $age/$id'),
    );

/// 只装一道题的题库：出题随机，只留一题才能稳定地测某一道题的流程。
QaBank _single(QaQuestion q) => QaBank(questions: [q], clips: _full.clips);

const Size _tablet = Size(800, 1280);

/// 「我的视频」里放一个片子，奖励才有得抽。
String _libraryJson() => jsonEncode({
      'categories': [
        {
          'id': 'vc1',
          'name': '动画片',
          'videos': [_videoJson('v1', '小猪佩奇 第 1 集')],
        },
      ],
    });

/// 两个片子的视频库（接着放下一片 / 轮完一轮的用例要）。
String _libraryJson2() => jsonEncode({
      'categories': [
        {
          'id': 'vc1',
          'name': '动画片',
          'videos': [
            _videoJson('v1', '小猪佩奇 第 1 集'),
            _videoJson('v2', '小猪佩奇 第 2 集'),
          ],
        },
      ],
    });

Map<String, dynamic> _videoJson(String id, String title) => {
      'id': id,
      'title': title,
      'source': 'https://example.com/$id.mp4',
      'kind': 'link',
    };

typedef _Host = (Widget, SharedPreferences);


const VideoItem _v1 = VideoItem(
  id: 'v1',
  title: '小猪佩奇 第 1 集',
  source: 'https://example.com/p1.mp4',
  kind: VideoKind.link,
);

const VideoItem _v2 = VideoItem(
  id: 'v2',
  title: '小猪佩奇 第 2 集',
  source: 'https://example.com/p2.mp4',
  kind: VideoKind.link,
);

RewardPlayback _playback(List<VideoItem> videos,
        {int index = 1, int stepSeconds = 30, int minSeconds = 30}) =>
    RewardPlayback(
      videos: videos,
      index: index,
      stepSeconds: stepSeconds,
      minSeconds: minSeconds,
    );

Future<_Host> _qaHost(QaQuestion q,
    {Map<String, Object> prefs = const {}, Size size = _tablet}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final store = await SharedPreferences.getInstance();
  final widget = ProviderScope(
    overrides: [prefsProvider.overrideWithValue(store)],
    child: MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: QaQuizScreen(ages: {q.age}, bank: _single(q)),
      ),
    ),
  );
  return (widget, store);
}

Map<String, dynamic> _onDisk(SharedPreferences prefs) =>
    jsonDecode(prefs.getString(kQuizRewardKey)!) as Map<String, dynamic>;

/// 等到黑屏浮出来（红闪 650ms + 记一笔答错之后才轮到黑屏）。
Future<bool> _waitBlackout(WidgetTester tester) async {
  for (var i = 0; i < 8 && find.byType(BlackoutLayer).evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 700));
  }
  return find.byType(BlackoutLayer).evaluate().isNotEmpty;
}

/// 点一下选项（[tapText] 给的是屏幕上的文字）。
Future<void> _tap(WidgetTester tester, String text, {bool missed = false}) async {
  await tester.tap(find.text(text), warnIfMissed: !missed);
  await tester.pump(const Duration(milliseconds: 700));
}

/// 一直泵到 [done] 成立为止（最多 [maxMs] 毫秒虚拟时间）。
Future<void> _pumpUntil(WidgetTester tester, bool Function() done,
    {int maxMs = 15000}) async {
  var elapsed = 0;
  while (elapsed < maxMs && !done()) {
    await tester.pump(const Duration(milliseconds: 200));
    elapsed += 200;
  }
}

/// 答对之后等「鼓励条 → 播报 → 推播放页」这一串走完。
///
/// 播报在测试环境里放不出声，得等它那几秒上限过去；这里泵到播放页浮出来
/// （没奖励的用例就是泵到成绩页）为止，再留一点路由转场的时间。
Future<void> _pumpReward(WidgetTester tester) async {
  await _pumpUntil(tester, () {
    return find.byType(VideoPlayerScreen).evaluate().isNotEmpty ||
        find.text('再玩一局').evaluate().isNotEmpty;
  });
  await tester.pump(const Duration(milliseconds: 400)); // 路由转场
}

void main() {
  group('答错超限黑屏', () {
    testWidgets('前两次答错只是普通反馈，第三次起才黑屏', (tester) async {
      final q = _q('baby', 'dog');
      final (widget, store) = await _qaHost(q);
      await tester.pumpWidget(widget);
      await tester.pump();

      final right = q.options[q.answer].text;
      final wrong = q.options.firstWhere((o) => o.text != right).text;

      await _tap(tester, wrong);
      expect(find.byType(BlackoutLayer), findsNothing, reason: '第一次答错就黑屏了');
      await _tap(tester, wrong);
      expect(find.byType(BlackoutLayer), findsNothing, reason: '第二次答错就黑屏了');
      expect(_onDisk(store)['w'], 2);

      await _tap(tester, wrong);
      expect(await _waitBlackout(tester), isTrue, reason: '第三次答错没黑屏');

      // 整屏盖住：连标题栏一起，点哪儿都点不动
      expect(
        tester.getSize(find.byType(BlackoutLayer)),
        tester.getSize(find.byType(Scaffold).first),
        reason: '黑屏没盖满整页',
      );
      await _tap(tester, wrong, missed: true);
      expect(_onDisk(store)['w'], 3, reason: '黑屏期间那一下还是算成了答错');

      // 黑完了接着做题，还能正常答对
      await settleBlackout(tester);
      expect(find.byType(BlackoutLayer), findsNothing);
      await _tap(tester, right);
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('再玩一局'), findsOneWidget);
    });
  });

  group('一次答对奖励看视频', () {
    testWidgets('随机抽「我的视频」里的片子，第一次整片看完', (tester) async {
      final fake = _installFakePlayer();
      final q = _q('baby', 'dog');
      final (widget, store) =
          await _qaHost(q, prefs: {kVideoLibraryKey: _libraryJson()});
      await tester.pumpWidget(widget);
      await tester.pump();

      await _tap(tester, q.options[q.answer].text);
      await _pumpReward(tester);

      expect(find.byType(VideoPlayerScreen), findsOneWidget);
      expect(find.text('小猪佩奇 第 1 集'), findsOneWidget);
      fake.ready();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('奖励 · 整片看完'), findsOneWidget,
          reason: '第一次奖励应该是不截断的整片');
      expect(_onDisk(store)['rc'], 1);

      await tester.pumpWidget(const SizedBox()); // 收摊，停掉播放器的定时器
    });

    testWidgets('先答错过一次就不算「一次答对」，不给奖励', (tester) async {
      final q = _q('baby', 'dog');
      final (widget, store) =
          await _qaHost(q, prefs: {kVideoLibraryKey: _libraryJson()});
      await tester.pumpWidget(widget);
      await tester.pump();

      final right = q.options[q.answer].text;
      final wrong = q.options.firstWhere((o) => o.text != right).text;
      await _tap(tester, wrong);
      await _tap(tester, right);
      await _pumpReward(tester);

      expect(find.byType(VideoPlayerScreen), findsNothing);
      expect(find.text('再玩一局'), findsOneWidget, reason: '该直接收尾进成绩页');
      // 答错本身会记一笔累计答错，但奖励的次数不能动
      expect(_onDisk(store)['rc'] ?? 0, 0, reason: '没给奖励却记了一笔');
    });

    testWidgets('「我的视频」空着就跳过奖励，直接收尾', (tester) async {
      final q = _q('baby', 'dog');
      final (widget, _) = await _qaHost(q);
      await tester.pumpWidget(widget);
      await tester.pump();

      await _tap(tester, q.options[q.answer].text);
      await _pumpReward(tester);

      expect(find.byType(VideoPlayerScreen), findsNothing);
      expect(find.text('再玩一局'), findsOneWidget);
    });
  });

  group('奖励播放页限时', () {
    testWidgets('按次数算出的额度到点自动退出，角标报剩余秒数', (tester) async {
      final fake = _installFakePlayer(total: const Duration(minutes: 2));
      await tester.pumpWidget((await _rewardHost(_playback(
        [_v1],
        index: 2,
        stepSeconds: 30,
        minSeconds: 30,
      )))
          .$1);
      await tester.pump();

      await tester.tap(find.text('开播'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      fake.ready();
      await tester.pump(const Duration(milliseconds: 400));

      // 两分钟的片子，第二次奖励少看 30 秒 = 90 秒
      expect(find.textContaining('奖励 · 还剩 90 秒'), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
      expect(find.textContaining('奖励 · 还剩 85 秒'), findsOneWidget);

      // 89 秒时还该在播（额度 90 秒）
      await tester.pump(const Duration(seconds: 84));
      expect(find.byType(VideoPlayerScreen), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      // 退场动画跑完路由才真正摘掉
      for (var i = 0; i < 8 && find.byType(VideoPlayerScreen).evaluate().isNotEmpty;
          i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(find.byType(VideoPlayerScreen), findsNothing, reason: '到点没退出');
      // 退出去之前先把画面停住，别让声音跟着退场继续响
      expect(fake.isPlaying, isFalse);

      await tester.pumpWidget(const SizedBox());
    });
  });

  group('续播与接着放', () {
    testWidgets('上次没放完：这次从上次停的地方接着放，位置随后落盘', (tester) async {
      final fake = _installFakePlayer(total: const Duration(minutes: 2));
      final (widget, store) = await _rewardHost(
        _playback([_v1, _v2]),
        prefs: {
          kVideoProgressKey: jsonEncode({
            'pos': {'v1': 40},
            'done': <String>[],
          }),
        },
      );
      await tester.pumpWidget(widget);
      await tester.tap(find.text('开播'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      fake.ready();
      await tester.pump(const Duration(milliseconds: 400));

      expect(fake.calls.contains('seek'), isTrue, reason: '没有接着上次的地方放');
      expect(fake.position, const Duration(seconds: 40));

      // 看一会儿，位置要跟着存下来（下次奖励接着这儿放）
      await tester.pump(const Duration(seconds: 3));
      final onDisk = jsonDecode(store.getString(kVideoProgressKey)!);
      expect(VideoProgress.fromJson(onDisk).resumeSeconds('v1'), greaterThan(0));

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('只剩个尾巴就从头上放，不接着那两秒', (tester) async {
      final fake = _installFakePlayer(total: const Duration(seconds: 60));
      await tester.pumpWidget((await _rewardHost(
        _playback([_v1, _v2]),
        prefs: {
          kVideoProgressKey: jsonEncode({
            'pos': {'v1': 59},
            'done': <String>[],
          }),
        },
      ))
          .$1);
      await tester.tap(find.text('开播'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      fake.ready();
      await tester.pump(const Duration(milliseconds: 400));

      expect(fake.calls.contains('seek'), isFalse, reason: '还剩一秒不该接着放');

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('一片放完还有额度：接着放下一片，放完的记成「已看完」', (tester) async {
      final fake = _installFakePlayer(total: const Duration(minutes: 2));
      final (widget, store) = await _rewardHost(_playback([_v1, _v2]));
      await tester.pumpWidget(widget);
      await tester.tap(find.text('开播'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      fake.ready();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('小猪佩奇 第 1 集'), findsOneWidget);

      fake.finish(); // 第 1 集放完了
      await _pumpUntil(tester,
          () => find.text('小猪佩奇 第 2 集').evaluate().isNotEmpty);
      fake.ready(); // 第 2 集的画面也准备好

      expect(find.text('小猪佩奇 第 2 集'), findsOneWidget, reason: '没接着放下一片');
      final onDisk = jsonDecode(store.getString(kVideoProgressKey)!);
      expect(VideoProgress.fromJson(onDisk).watchedToEnd('v1'), isTrue,
          reason: '放完的那片该记成「已看完」');

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('队列走到头（都看完过一轮）：清空记录重排，仍接着放', (tester) async {
      final fake = _installFakePlayer(total: const Duration(minutes: 2));
      // v2 已经看完过，所以这一局只排了 v1；v1 放完队列就走到头了
      final (widget, store) = await _rewardHost(
        _playback([_v1], index: 1),
        prefs: {
          kVideoLibraryKey: _libraryJson2(),
          kVideoProgressKey: jsonEncode({
            'pos': <String, int>{},
            'done': ['v2'],
          }),
        },
      );
      await tester.pumpWidget(widget);
      await tester.tap(find.text('开播'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      fake.ready();
      await tester.pump(const Duration(milliseconds: 400));

      fake.finish();
      await tester.pump(const Duration(milliseconds: 400));
      fake.ready();
      await tester.pump(const Duration(milliseconds: 400));

      final onDisk = jsonDecode(store.getString(kVideoProgressKey)!);
      expect(VideoProgress.fromJson(onDisk).watchedToEnd('v2'), isFalse,
          reason: '全都看完过一轮了，记录该清空重来');
      expect(find.byType(VideoPlayerScreen), findsOneWidget,
          reason: '清空重排之后该接着放，不是退出去');
      // 记录清空后 v1 / v2 又都回到候选里，重排出来是哪一个都行
      expect(find.textContaining('小猪佩奇'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });
  });

  group('奖惩播报', () {
    testWidgets('答错超限会播「答错了，黑屏」，前两次不播', (tester) async {
      final said = <String>[];
      RewardVoice.debugOnAnnounce = said.add;
      addTearDown(() => RewardVoice.debugOnAnnounce = null);

      final q = _q('baby', 'dog');
      final (widget, _) = await _qaHost(q);
      await tester.pumpWidget(widget);
      await tester.pump();

      final wrong =
          q.options.firstWhere((o) => o.text != q.options[q.answer].text).text;

      await _tap(tester, wrong);
      await _tap(tester, wrong);
      expect(said, isEmpty, reason: '还没到次数就播报了');

      // 第三次起：每次答错都播「答错了，黑屏」
      await _tap(tester, wrong);
      expect(await _waitBlackout(tester), isTrue);
      expect(said, [RewardVoice.punishAsset], reason: '答错超限没播报');
      await settleBlackout(tester);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('一次答对会播「一次答对，奖励看视频」', (tester) async {
      final said = <String>[];
      RewardVoice.debugOnAnnounce = said.add;
      addTearDown(() => RewardVoice.debugOnAnnounce = null);

      final q = _q('baby', 'dog');
      final (widget, _) =
          await _qaHost(q, prefs: {kVideoLibraryKey: _libraryJson()});
      await tester.pumpWidget(widget);
      await tester.pump();

      await _tap(tester, q.options[q.answer].text);
      await _pumpReward(tester);

      expect(said, [RewardVoice.rewardAsset], reason: '一次答对没播报');

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('「我的视频」空着也照样播报奖励（只是没片子放）', (tester) async {
      final said = <String>[];
      RewardVoice.debugOnAnnounce = said.add;
      addTearDown(() => RewardVoice.debugOnAnnounce = null);

      final q = _q('baby', 'dog');
      final (widget, store) = await _qaHost(q);
      await tester.pumpWidget(widget);
      await tester.pump();

      await _tap(tester, q.options[q.answer].text);
      await _pumpReward(tester);

      expect(find.byType(VideoPlayerScreen), findsNothing);
      expect(said, [RewardVoice.rewardAsset], reason: '没片子就不播报了');
      expect(store.getString(kQuizRewardKey), isNull,
          reason: '没看着片子不该记奖励次数');

      await tester.pumpWidget(const SizedBox());
    });
  });

  group('家长设置', () {
    testWidgets('改完四个数存下来', (tester) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final (widget, store) = await _settingsHost();
      await tester.pumpWidget(widget);
      await tester.tap(find.text('打开'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('做题奖惩'), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(0), '7'); // X
      await tester.enterText(find.byType(TextField).at(1), '9'); // Y
      await tester.enterText(find.byType(TextField).at(2), '10'); // A
      await tester.enterText(find.byType(TextField).at(3), '5'); // B
      await tester.tap(find.text('保存'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final saved = _onDisk(store);
      expect(saved['x'], 7);
      expect(saved['y'], 9);
      expect(saved['a'], 10);
      expect(saved['b'], 5);
      expect(find.text('做题奖惩'), findsNothing, reason: '保存完该关框');
    });

    testWidgets('计数清零：清掉累计，配置不动', (tester) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final (widget, store) = await _settingsHost(prefs: {
        kQuizRewardKey: jsonEncode({
          'x': 3,
          'y': 5,
          'a': 30,
          'b': 30,
          'w': 7,
          'bc': 4,
          'rc': 2,
        }),
      });
      await tester.pumpWidget(widget);
      await tester.tap(find.text('打开'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('计数清零'));
      await tester.pump();

      final saved = _onDisk(store);
      expect(saved['w'], 0);
      expect(saved['bc'], 0);
      expect(saved['rc'], 0);
      expect(saved['x'], 3, reason: '清零不该动配置');
      expect(saved['a'], 30);
    });
  });
}

// ---------- 假的播放器（做法同 video_player_screen_test.dart） ----------

class _FakePlayer extends VideoPlayerPlatform {
  _FakePlayer({this.total = const Duration(seconds: 30)});

  final Duration total;
  final List<String> calls = <String>[];
  StreamController<VideoEvent>? _events;
  bool isPlaying = false;
  Duration position = Duration.zero;

  @override
  Future<void> init() async {}

  @override
  Future<int?> create(DataSource dataSource) async => 1;

  @override
  Future<void> dispose(int playerId) async {}

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) {
    final events = StreamController<VideoEvent>();
    _events = events;
    return events.stream;
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Future<void> setPreventsDisplaySleepDuringVideoPlayback(
          int playerId, bool preventing) async {}

  @override
  Future<void> play(int playerId) async {
    isPlaying = true;
    calls.add('play');
  }

  @override
  Future<void> pause(int playerId) async {
    isPlaying = false;
    calls.add('pause');
  }

  @override
  Future<void> seekTo(int playerId, Duration pos) async {
    position = pos;
    calls.add('seek');
  }

  @override
  Future<Duration> getPosition(int playerId) async => position;

  @override
  Widget buildView(int playerId) => const SizedBox.expand();

  /// 第一帧就绪，对应真机上那个 `initialized` 事件。
  void ready() => _events!.add(VideoEvent(
        eventType: VideoEventType.initialized,
        duration: total,
        size: const Size(1280, 720),
      ));

  /// 整片放完，对应真机上那个 `completed` 事件。
  void finish() {
    position = total;
    _events!.add(VideoEvent(eventType: VideoEventType.completed));
  }
}

_FakePlayer _installFakePlayer({Duration total = const Duration(seconds: 30)}) {
  final previous = VideoPlayerPlatform.instance;
  final fake = _FakePlayer(total: total);
  VideoPlayerPlatform.instance = fake;
  addTearDown(() => VideoPlayerPlatform.instance = previous);
  return fake;
}

/// 一个按钮把奖励播放页推上来（奖励模式得从别的页面推，退回去才有地方退）。
///
/// 盘上的初值要连着 [prefs] 一起给进来 —— `setMockInitialValues` 会把实例换掉，
/// 在外面先造的那个 store 就不是同一份了。
Future<_Host> _rewardHost(RewardPlayback playback,
    {Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final store = await SharedPreferences.getInstance();
  final widget = ProviderScope(
    overrides: [prefsProvider.overrideWithValue(store)],
    child: MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => VideoPlayerScreen(
                  video: playback.videos.first,
                  reward: playback,
                ),
              )),
              child: const Text('开播'),
            ),
          ),
        ),
      ),
    ),
  );
  return (widget, store);
}

/// 一个按钮把「做题奖惩」设置框弹出来。
Future<_Host> _settingsHost({Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final store = await SharedPreferences.getInstance();
  final widget = ProviderScope(
    overrides: [prefsProvider.overrideWithValue(store)],
    child: MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showQuizRewardSettings(context),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    ),
  );
  return (widget, store);
}
