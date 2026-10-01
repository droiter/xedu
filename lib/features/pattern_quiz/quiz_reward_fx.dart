import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

/// 奖惩的播报语音（答错超限「答错了，黑屏」/ 一次答对「一次答对，奖励看视频」）。
///
/// 音频由 `scripts/gen_reward_voice.py` 合成，音色与「看图问答」的朗读一致，
/// 播法也照抄那条**已经在真机上出声**的路子：一个常驻播放器 + `play(AssetSource)`。
/// 早先那版是每句现造一个播放器、`setSource` 只给 2 秒（`audioplayers` 自己允许
/// 30 秒），真机起播一慢就被判超时、于是永远没声音 —— 别再走那条路。
///
/// 任何环节出错（设备静音、解码失败等）都只当这一句没念，下一次照样再试；
/// 播不出来也照样黑屏 / 奖励，绝不把答题带崩。
///
/// 语速**烤在音频里**（生成脚本按 +40% 合成，就是朗读语速最快的那一档），
/// 播的时候不碰 `setPlaybackRate`：这两句是催促性的短提醒，家长把朗读语速调到
/// 最慢也不该拖着它一起慢下来，而且老设备上运行时变速本来就不生效。
class RewardVoice {
  RewardVoice._();

  static final RewardVoice instance = RewardVoice._();

  static const punishAsset = 'audio/punish_black.mp3';
  static const rewardAsset = 'audio/reward_video.mp3';

  /// 两句各自的时长（生成脚本产出，用来定「等它念完」的上限）。
  ///
  /// 摆在外面是给测试跟真音频对表用的：换了音频而这里没跟着改，上限就不准了
  /// （短了会把话掐掉，长了就白等）。
  static const punishLength = Duration(milliseconds: 2090);
  static const rewardLength = Duration(milliseconds: 2120);

  static const _punish = _Clip(punishAsset, punishLength);
  static const _reward = _Clip(rewardAsset, rewardLength);

  /// 等一句念完时额外给的时间：真机起播要花几百毫秒，别卡着片长掐。
  static const _slack = Duration(seconds: 4);

  /// 起播最多等这么久：真机起播慢也要等，但设备整个哑了不能把孩子晾在这儿。
  ///
  /// 测试里没有音频平台通道 —— `audioplayers` 的 `setReleaseMode` / `stop` 一类
  /// 调用会一直挂着不回调（`play` 反倒立刻抛异常），照 8 秒等就是白等 8 秒虚拟
  /// 时间，还留下一个 pending timer。`test/flutter_test_config.dart` 把它调短。
  @visibleForTesting
  static Duration startCap = const Duration(seconds: 8);

  AudioPlayer? _player;
  bool _saying = false;

  /// 正在跑的上限计时器；离开页面时一并 cancel 掉，不留 pending timer。
  final List<Timer> _caps = [];

  /// 测试用：这一句开始播报了（真机到底出没出声没法在测试里验）。
  @visibleForTesting
  static void Function(String asset)? debugOnAnnounce;

  /// 预热：把两句都解码好放进播放器，第一次用到时就不用现等。
  ///
  /// 只 `setSource` 不出声 —— 和 `QuizSfx.preload` 一个套路。
  Future<void> preload() async {
    for (final clip in [_punish, _reward]) {
      await _prepare(clip.asset);
    }
  }

  /// 播报「一次答对，奖励看视频」，**念完（或超时）才返回**。
  Future<void> sayReward() => _say(_reward, wait: true);

  /// 播报「答错了，黑屏」。不等它念完 —— 黑屏该立刻盖上，语音跟着黑屏一起走正好。
  Future<void> sayPunish() => _say(_punish, wait: false);

  Future<void> _prepare(String asset) async {
    try {
      final p = await _ensurePlayer();
      await p.setSource(AssetSource(asset));
    } catch (e) {
      debugPrint('RewardVoice: 语音不可用（$asset）：$e');
    }
  }

  Future<AudioPlayer> _ensurePlayer() async {
    final existing = _player;
    if (existing != null) return existing;
    final p = AudioPlayer(playerId: 'xedu_reward_voice');
    _player = p;
    await p.setReleaseMode(ReleaseMode.stop);
    return p;
  }

  Future<void> _say(_Clip clip, {required bool wait}) async {
    try {
      debugOnAnnounce?.call(clip.asset);
      final p = await _withCap(_ensurePlayer(), startCap);
      if (p == null) return;
      // 上一句还没念完就别叠着念（一句才两三秒，等它走完）。
      if (_saying) await _withCap(_stopQuietly(p), startCap);
      _saying = true;
      final started = await _withCap(_start(p, clip), startCap);
      if (started != true) return;
      if (wait) await _waitDone(p, clip);
    } catch (e) {
      // 只当这一句没念，不清空状态、也不永久静音：下一题还会再试一次。
      debugPrint('RewardVoice: 播报失败（${clip.asset}）：$e');
    } finally {
      _saying = false;
    }
  }

  /// 起播：停住上一句，再放下这一句。
  Future<bool> _start(AudioPlayer p, _Clip clip) async {
    await p.stop();
    await p.play(AssetSource(clip.asset));
    return true;
  }

  /// 给 [future] 套一个上限：到点返回 null，不抛异常。计时器自己拿着，
  /// 离开页面时能 cancel（`Future.timeout` 拿不到那个计时器）。
  Future<T?> _withCap<T>(Future<T> future, Duration cap) async {
    final done = Completer<T?>();
    final timer = Timer(cap, () {
      if (!done.isCompleted) done.complete(null);
    });
    _caps.add(timer);
    unawaited(future.then(
      (value) {
        if (!done.isCompleted) done.complete(value);
      },
      onError: (Object e) {
        debugPrint('RewardVoice: 语音这一步没走通：$e');
        if (!done.isCompleted) done.complete(null);
      },
    ));
    try {
      return await done.future;
    } finally {
      timer.cancel();
      _caps.remove(timer);
    }
  }

  /// 等这一句念完。用自己起的计时器兜底（不是 `Future.timeout`），
  /// 这样离开页面时能 cancel 干净，不留 pending timer。
  Future<void> _waitDone(AudioPlayer p, _Clip clip) async {
    final done = Completer<void>();
    final sub = p.onPlayerComplete.listen(
      (_) {
        if (!done.isCompleted) done.complete();
      },
      onError: (_) {
        if (!done.isCompleted) done.complete();
      },
    );
    final cap = Timer(clip.length + _slack, () {
      if (!done.isCompleted) done.complete();
    });
    _caps.add(cap);
    try {
      await done.future;
    } finally {
      cap.cancel();
      _caps.remove(cap);
      await sub.cancel();
    }
  }

  Future<void> _stopQuietly(AudioPlayer p) async {
    try {
      await p.stop();
    } catch (_) {/* 停不下来也无所谓，下面还会再 stop 一次 */}
  }

  /// 退出答题页时释放播放器。
  Future<void> dispose() async {
    for (final t in _caps) {
      t.cancel();
    }
    _caps.clear();
    _saying = false;
    final p = _player;
    _player = null;
    if (p == null) return;
    try {
      await p.dispose();
    } catch (_) {/* 释放失败无所谓 */}
  }
}

class _Clip {
  const _Clip(this.asset, this.length);

  final String asset;
  final Duration length;
}

/// 答错超限后的黑屏：整屏纯黑、吃住所有点击，中间一个圈连着秒数一起倒着走 ——
/// 孩子看得见还差几秒，不至于以为死机了（家长也好判断这次罚了多久）。
///
/// 盖在整个 [Scaffold] 之上（连标题栏一起），所以黑屏期间连返回键都摸不到。
class BlackoutLayer extends StatefulWidget {
  const BlackoutLayer({super.key, required this.seconds});

  /// 这一次黑几秒，倒计时就从它开始。
  final int seconds;

  @override
  State<BlackoutLayer> createState() => _BlackoutLayerState();
}

class _BlackoutLayerState extends State<BlackoutLayer>
    with SingleTickerProviderStateMixin {
  /// 倒计时的钟。黑屏多长由答题页那头的计时器说了算，这里只管把这段时间画出来。
  late final AnimationController _clock;

  @override
  void initState() {
    super.initState();
    _clock = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.seconds),
    )..forward();
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  /// 还剩几秒。往上取整：刚盖上时是满秒，走完那一瞬间也不会露出 0。
  int get _left => (widget.seconds * (1 - _clock.value))
      .ceil()
      .clamp(1, widget.seconds);

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          const ModalBarrier(
            dismissible: false,
            color: Colors.black,
            semanticsLabel: '答错了，屏幕黑一会儿',
          ),
          Center(
            child: AnimatedBuilder(
              animation: _clock,
              builder: (context, _) => Stack(
                alignment: Alignment.center,
                children: [
                  // 圈按剩余比例缩：不识数的孩子看圈也知道快到头了。
                  SizedBox(
                    width: 136,
                    height: 136,
                    child: CircularProgressIndicator(
                      value: 1 - _clock.value,
                      strokeWidth: 6,
                      strokeCap: StrokeCap.round,
                      color: Colors.white70,
                      backgroundColor: Colors.white12,
                    ),
                  ),
                  Text(
                    '$_left',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 64,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
}
