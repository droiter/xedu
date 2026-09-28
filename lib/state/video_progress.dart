import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import 'prefs.dart';

/// 「奖励看视频」看到哪儿了：每个视频停在第几秒 + 哪些已经整片看完过。全机一份。
///
/// 只有奖励播放会读写它（普通播放照旧从头整片放）：奖励是按秒给的额度，一次看不完
/// 一段片子，下次奖励就接着上次停的地方续播，直到整片放完；放完的进 [finished]，
/// 挑片子时优先挑没看完的。全都看完过一轮了，调用方清空整张表从头轮。
@immutable
class VideoProgress {
  const VideoProgress({this.seconds = const {}, this.finished = const {}});

  factory VideoProgress.fromJson(Map<String, dynamic> json) => VideoProgress(
        seconds: {
          for (final e in (json['pos'] as Map? ?? const {}).entries)
            if (e.value is num && (e.value as num) > 0)
              '${e.key}': (e.value as num).toInt(),
        },
        finished: {
          for (final id in (json['done'] as List? ?? const [])) '$id',
        },
      );

  /// 视频 id → 上次停在第几秒（> 0 才有记录）。
  final Map<String, int> seconds;

  /// 已经整片看完过的视频 id。
  final Set<String> finished;

  /// 这个视频该从第几秒接着放；没记录就是 0（从头放）。
  int resumeSeconds(String videoId) => seconds[videoId] ?? 0;

  /// 这个视频已经整片看过一遍了？
  bool watchedToEnd(String videoId) => finished.contains(videoId);

  Map<String, dynamic> toJson() => {
        'pos': {...seconds},
        'done': [...finished],
      };
}

/// 进度表的读写，落盘到 SharedPreferences。
class VideoProgressController extends Notifier<VideoProgress> {
  @override
  VideoProgress build() => _load();

  VideoProgress _load() {
    try {
      final raw = ref.read(prefsProvider).getString(kVideoProgressKey);
      if (raw == null || raw.isEmpty) return const VideoProgress();
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const VideoProgress();
      return VideoProgress.fromJson(decoded.cast<String, dynamic>());
    } catch (_) {
      return const VideoProgress();
    }
  }

  Future<void> _save(VideoProgress next) async {
    state = next;
    await ref
        .read(prefsProvider)
        .setString(kVideoProgressKey, jsonEncode(next.toJson()));
  }

  /// 记下这个视频停在第几秒；<= 0 等于没看过，把记录删掉。
  Future<void> save(String videoId, int seconds) async {
    final next = {...state.seconds};
    if (seconds <= 0) {
      if (!next.containsKey(videoId)) return;
      next.remove(videoId);
    } else {
      if (next[videoId] == seconds) return;
      next[videoId] = seconds;
    }
    await _save(VideoProgress(seconds: next, finished: state.finished));
  }

  /// 整片放完了：删掉「停在哪」，记进「已看完」。
  Future<void> markFinished(String videoId) async {
    if (state.watchedToEnd(videoId) && !state.seconds.containsKey(videoId)) {
      return;
    }
    await _save(VideoProgress(
      seconds: {...state.seconds}..remove(videoId),
      finished: {...state.finished, videoId},
    ));
  }

  /// 视频被删了，记录一并扔掉。
  Future<void> forget(String videoId) async {
    if (!state.seconds.containsKey(videoId) &&
        !state.finished.contains(videoId)) {
      return;
    }
    await _save(VideoProgress(
      seconds: {...state.seconds}..remove(videoId),
      finished: {...state.finished}..remove(videoId),
    ));
  }

  /// 「我的视频」全都看完过一遍了 → 清空整张表，从头再轮一轮。
  Future<void> clearAll() async {
    if (state.seconds.isEmpty && state.finished.isEmpty) return;
    await _save(const VideoProgress());
  }
}

final videoProgressProvider =
    NotifierProvider<VideoProgressController, VideoProgress>(
        VideoProgressController.new);
