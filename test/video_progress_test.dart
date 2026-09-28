import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xedu/core/constants.dart';
import 'package:xedu/features/video/reward_playlist.dart';
import 'package:xedu/state/providers.dart';
import 'package:xedu/state/video_library.dart';
import 'package:xedu/state/video_progress.dart';

VideoItem _v(String id) => VideoItem(
      id: id,
      title: '片子 $id',
      source: 'https://example.com/$id.mp4',
      kind: VideoKind.link,
    );

VideoLibrary _lib(List<String> ids) => VideoLibrary(categories: [
      VideoCategory(id: 'c1', name: '动画片', videos: [for (final i in ids) _v(i)]),
    ]);

Future<SharedPreferences> _store([Map<String, Object> prefs = const {}]) async {
  SharedPreferences.setMockInitialValues(prefs);
  return SharedPreferences.getInstance();
}

ProviderContainer _host(SharedPreferences store) {
  final c = ProviderContainer(
    overrides: [prefsProvider.overrideWithValue(store)],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('续播进度表', () {
    test('记下停在第几秒，重启后还在', () async {
      final store = await _store();
      final c = _host(store);
      await c.read(videoProgressProvider.notifier).save('v1', 42);

      expect(c.read(videoProgressProvider).resumeSeconds('v1'), 42);
      // 落盘了：重新解析盘上那段 JSON 也拿得到
      final onDisk = jsonDecode(store.getString(kVideoProgressKey)!);
      expect(VideoProgress.fromJson(onDisk).resumeSeconds('v1'), 42);
    });

    test('没看过的片子从 0 开始', () async {
      final c = _host(await _store());
      expect(c.read(videoProgressProvider).resumeSeconds('vx'), 0);
      expect(c.read(videoProgressProvider).watchedToEnd('vx'), isFalse);
    });

    test('整片看完：删掉「停在哪」，记进「已看完」', () async {
      final c = _host(await _store());
      final n = c.read(videoProgressProvider.notifier);
      await n.save('v1', 90);
      await n.markFinished('v1');

      final p = c.read(videoProgressProvider);
      expect(p.resumeSeconds('v1'), 0, reason: '看完了就该从头放');
      expect(p.watchedToEnd('v1'), isTrue);
    });

    test('秒数归零就当没看过', () async {
      final c = _host(await _store());
      final n = c.read(videoProgressProvider.notifier);
      await n.save('v1', 30);
      await n.save('v1', 0);
      expect(c.read(videoProgressProvider).resumeSeconds('v1'), 0);
    });

    test('清空整张表：停在哪和已看完一起清掉', () async {
      final c = _host(await _store());
      final n = c.read(videoProgressProvider.notifier);
      await n.save('v1', 30);
      await n.markFinished('v2');
      await n.clearAll();

      final p = c.read(videoProgressProvider);
      expect(p.seconds, isEmpty);
      expect(p.finished, isEmpty);
    });
  });

  group('奖励排片', () {
    test('先排没看完的，看完了的不再排', () async {
      final c = _host(await _store());
      await c.read(videoProgressProvider.notifier).markFinished('v1');

      final plan = planRewardPlaylist(
        library: _lib(['v1', 'v2', 'v3']),
        progress: c.read(videoProgressProvider),
        rng: Random(7),
      );
      expect(plan.restarted, isFalse);
      expect({for (final v in plan.videos) v.id}, {'v2', 'v3'});
    });

    test('全都看完过一轮：让调用方清空记录，顺序仍取全部片子', () async {
      final c = _host(await _store());
      final n = c.read(videoProgressProvider.notifier);
      for (final id in ['v1', 'v2']) {
        await n.markFinished(id);
      }

      final plan = planRewardPlaylist(
        library: _lib(['v1', 'v2']),
        progress: c.read(videoProgressProvider),
        rng: Random(3),
      );
      expect(plan.restarted, isTrue);
      expect({for (final v in plan.videos) v.id}, {'v1', 'v2'});
    });

    test('刚放完那一个不排在最前面（还有别的可选时）', () async {
      for (var seed = 0; seed < 20; seed++) {
        final c = _host(await _store());
        final plan = planRewardPlaylist(
          library: _lib(['v1', 'v2', 'v3']),
          progress: c.read(videoProgressProvider),
          avoid: 'v2',
          rng: Random(seed),
        );
        expect(plan.videos.first.id, isNot('v2'), reason: 'seed=$seed');
      }
    });

    test('只有一个片子时躲不开，还是它', () async {
      final c = _host(await _store());
      final plan = planRewardPlaylist(
        library: _lib(['v1']),
        progress: c.read(videoProgressProvider),
        avoid: 'v1',
        rng: Random(1),
      );
      expect(plan.videos.single.id, 'v1');
    });

    test('「我的视频」空着就没有片子可排', () async {
      final c = _host(await _store());
      final plan = planRewardPlaylist(
        library: const VideoLibrary(),
        progress: c.read(videoProgressProvider),
      );
      expect(plan.videos, isEmpty);
      expect(plan.restarted, isFalse);
    });
  });
}
