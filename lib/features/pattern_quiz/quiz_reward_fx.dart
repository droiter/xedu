import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../state/video_library.dart';

/// 奖惩的播报语音（答错「打错了，黑屏」/ 答对「答对了，奖励看视频」）。
///
/// 音频由 `scripts/gen_reward_voice.py` 合成，音色与「看图问答」的朗读一致。
/// 任何环节出错（设备静音、解码失败等）都直接静音降级 —— 播不出来也照样
/// 黑屏 / 奖励，绝不把答题带崩。
class RewardVoice {
  RewardVoice._();

  static final RewardVoice instance = RewardVoice._();

  static const _punish = 'audio/punish_black.mp3';
  static const _reward = 'audio/reward_video.mp3';

  /// 起播的上限。设备放不出声时播放器**根本不会回调**，没有这个上限就会一直
  /// 卡在 await 上 —— 惩罚的播报是答错流程里串着等的，卡住等于答题页死在那儿。
  static const _startTimeout = Duration(seconds: 2);

  /// 等一句播完的上限，同理：不能把孩子晾在这儿。
  static const _clipTimeout = Duration(seconds: 5);

  final Map<String, AudioPlayer> _players = {};
  bool _dead = false;

  /// 第一次用到哪个片段才解码哪个：两句都短，起播那点延迟落在答错的红闪里，
  /// 不用在进答题页时就预热（那会平白多两个计时器，测试里还等不到收尾）。
  Future<AudioPlayer?> _player(String asset) async {
    if (_dead) return null;
    final existing = _players[asset];
    if (existing != null) return existing;
    try {
      final p = AudioPlayer(playerId: 'xedu_reward_$asset')
        ..setReleaseMode(ReleaseMode.stop);
      await p.setSource(AssetSource(asset)).timeout(_startTimeout);
      _players[asset] = p;
      return p;
    } catch (e) {
      debugPrint('RewardVoice: 语音不可用（$asset）：$e');
      return null;
    }
  }

  /// 播报「打错了，黑屏」，**播完才返回**（播不出来就立刻返回）。
  Future<void> sayPunish() => _say(_punish);

  /// 播报「答对了，奖励看视频」，同样等播完。
  Future<void> sayReward() => _say(_reward);

  Future<void> _say(String asset) async {
    if (_dead) return;
    try {
      final p = await _player(asset);
      if (p == null) return;
      await p.stop();
      await p.resume();
      await p.onPlayerComplete.first.timeout(_clipTimeout, onTimeout: () {});
    } catch (e) {
      debugPrint('RewardVoice: 播报失败，后续静音：$e');
      _dead = true;
    }
  }

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

/// 答错超限后的黑屏：整屏纯黑、吃住所有点击，孩子只能等着。
///
/// 盖在整个 [Scaffold] 之上（连标题栏一起），所以黑屏期间连返回键都摸不到。
class BlackoutLayer extends StatelessWidget {
  const BlackoutLayer({super.key});

  @override
  Widget build(BuildContext context) => const ModalBarrier(
        dismissible: false,
        color: Colors.black,
        semanticsLabel: '答错了，屏幕黑一会儿',
      );
}

/// 「我的视频」里的全部视频（不分分类，奖励是随机抽一个）。
List<VideoItem> rewardVideosOf(VideoLibrary library) => [
      for (final c in library.categories) ...c.videos,
    ];
