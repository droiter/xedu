import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// 答题音效（答对 / 答错 / 通关）。
///
/// 音频文件由 `scripts/gen_quiz_sounds.py` 合成，不需要外部素材。
/// 任何一个环节出错（设备静音、解码失败等）都直接静音降级，绝不打断答题。
class QuizSfx {
  QuizSfx._();

  static final QuizSfx instance = QuizSfx._();

  static const _right = 'audio/quiz_right.wav';
  static const _wrong = 'audio/quiz_wrong.wav';
  static const _win = 'audio/quiz_win.wav';

  final Map<String, AudioPlayer> _players = {};
  bool _dead = false;

  /// 预热：提前把解码好的音频放进播放器，第一次答题就不会有延迟。
  Future<void> preload() async {
    for (final asset in [_right, _wrong, _win]) {
      await _player(asset);
    }
  }

  Future<AudioPlayer?> _player(String asset) async {
    if (_dead) return null;
    final existing = _players[asset];
    if (existing != null) return existing;
    try {
      final p = AudioPlayer(playerId: asset)..setReleaseMode(ReleaseMode.stop);
      await p.setSource(AssetSource(asset));
      _players[asset] = p;
      return p;
    } catch (e) {
      debugPrint('QuizSfx: 音效不可用（$asset）：$e');
      return null;
    }
  }

  Future<void> _play(String asset, double volume) async {
    if (_dead) return;
    try {
      final p = await _player(asset);
      if (p == null) return;
      await p.stop();
      await p.setVolume(volume);
      await p.resume();
    } catch (e) {
      debugPrint('QuizSfx: 播放失败，后续静音：$e');
      _dead = true;
    }
  }

  Future<void> playRight() => _play(_right, 1.0);

  Future<void> playWrong() => _play(_wrong, 0.7);

  Future<void> playWin() => _play(_win, 0.9);

  /// 退出答题页时释放播放器。
  Future<void> dispose() async {
    for (final p in _players.values) {
      try {
        await p.dispose();
      } catch (_) {/* 释放失败无所谓 */}
    }
    _players.clear();
  }
}
