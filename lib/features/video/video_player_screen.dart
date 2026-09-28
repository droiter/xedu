import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../state/providers.dart';
import '../../state/video_library.dart';
import '../../state/video_progress.dart';
import 'reward_playlist.dart';

/// 视频播放页。
///
/// 这里**不做任何返回拦截**：按返回键随时退回到上一页，
/// 不弹家长验证，也不受播放进度影响。放完则自动退回视频列表。
///
/// 带 [reward] 时是「答对奖励」的播放：[RewardPlayback.videos] 里的片子一片接
/// 一片地放，每片都从上次停下的地方续播（见 [VideoProgress]）；这一局的额度按
/// [RewardWatchLimit] 算（第一次整片、之后每次少 A 秒、不低于 B 秒），额度到点
/// 或者片子全放完就回去接着做题。计时按**真实时间**走，拖进度条也拖不出更多时间。
class VideoPlayerScreen extends ConsumerStatefulWidget {
  const VideoPlayerScreen({super.key, required this.video, this.reward});

  /// 普通播放放的就是它；奖励播放时应当等于 `reward.videos.first`。
  final VideoItem video;

  /// 奖励模式；null 就是普通的整片播放。
  final RewardPlayback? reward;

  @override
  ConsumerState<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen> {
  VideoPlayerController? _controller;
  String? _error;

  /// 已经因为播完退回去过了，别再退第二次。
  bool _leftAfterEnd = false;

  /// 这一局要放的片子（普通播放就一个）和当前放到第几个。
  late List<VideoItem> _queue;
  int _cursor = 0;

  /// 当前这片是不是已经放完了（放完就不必再记「停在哪」）。
  bool _currentEnded = false;

  /// 奖励这一局的总额度和剩余秒数：一个计时器管到底，中途换片子不重置。
  Timer? _limitTimer;
  Timer? _tickTimer;
  int _leftSeconds = 0;
  bool _budgetStarted = false;

  /// 上一秒存过的位置，位置真的动了才写盘。
  int _savedSeconds = -1;

  final Random _rng = Random();

  VideoItem get _current => _queue[_cursor];

  bool get _isReward => widget.reward != null;

  /// 剩这么点额度就别再开下一片了（开起来也来不及放）。
  static const int _chainTailSeconds = 1;

  @override
  void initState() {
    super.initState();
    final reward = widget.reward;
    _queue = reward == null || reward.videos.isEmpty
        ? [widget.video]
        : List.of(reward.videos);
    _init();
  }

  @override
  void dispose() {
    _limitTimer?.cancel();
    _tickTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final item = _current;
    final controller = item.isLocal
        ? VideoPlayerController.file(File(item.source))
        : VideoPlayerController.networkUrl(Uri.parse(item.source));
    _controller = controller;
    _currentEnded = false;
    try {
      await controller.initialize();
      if (!mounted || _leftAfterEnd) return;
      await _resumeFrom(controller);
      if (!mounted || _leftAfterEnd) return;
      setState(() {});
      if (!_budgetStarted) {
        _budgetStarted = true;
        _startRewardClock(controller.value.duration);
      }
      // 挂在播放器上而不是写在 build 里：build 期间动导航栈会直接断言失败。
      controller.addListener(_onPlaybackChanged);
      await controller.play();
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = item.isLocal
          ? '这个视频文件打不开了\n可能已被删除，请重新添加'
          : '视频暂时无法播放\n请检查网络后重试');
    }
  }

  /// 奖励模式：接着上次停的地方放。只剩个尾巴（[kResumeTailSeconds] 以内）
  /// 就当没看过，从头放 —— 免得一进来就闪一下「放完」。
  Future<void> _resumeFrom(VideoPlayerController c) async {
    if (!_isReward) return;
    final saved = ref.read(videoProgressProvider).resumeSeconds(_current.id);
    if (saved <= 0) return;
    final full = c.value.duration.inSeconds;
    if (full > 0 && saved >= full - kResumeTailSeconds) return;
    await c.seekTo(Duration(seconds: saved));
  }

  /// 奖励模式的时钟：整局只起一次（第一次 [isFull] 就是「整片」，额度即片长）。
  void _startRewardClock(Duration full) {
    final reward = widget.reward;
    if (reward == null) return;
    final limit = reward.limit.limitFor(full);
    if (limit.inSeconds <= 0) return;
    _leftSeconds = limit.inSeconds;
    _limitTimer = Timer(limit, _leaveByRewardLimit);
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_leftSeconds > 0) setState(() => _leftSeconds--);
      _saveProgress();
    });
  }

  /// 奖励时间到，收走画面回到答题页。
  void _leaveByRewardLimit() {
    if (!mounted || _leftAfterEnd) return;
    _leftAfterEnd = true;
    _saveProgress();
    _controller?.pause();
    Navigator.of(context).maybePop();
  }

  /// 记下当前这片放到第几秒了（奖励模式才有意义）。
  ///
  /// 普通播放不看这张表，放完的片子也已经从表里删掉了，所以这两种情况都不写。
  /// 每秒跟着倒计时存一次：孩子随时按返回都能接着上次的地方看，
  /// 掉电 / 强杀最多也就丢一秒。
  void _saveProgress() {
    if (!_isReward || _currentEnded) return;
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final at = c.value.position.inSeconds;
    if (at <= 0 || at == _savedSeconds) return;
    _savedSeconds = at;
    final id = _current.id;
    unawaited(ref.read(videoProgressProvider.notifier).save(id, at));
  }

  /// 重试前先把失败的播放器丢掉，避免两份实例同时占着解码器。
  Future<void> _retry() async {
    final old = _controller;
    setState(() {
      _controller = null;
      _error = null;
    });
    await old?.dispose();
    await _init();
  }

  /// 这一片放完了：奖励模式接着放下一个，普通播放直接退回列表。
  void _onPlaybackChanged() {
    final c = _controller;
    if (c == null || !mounted || _leftAfterEnd || _currentEnded) return;
    if (!c.value.isCompleted) return;
    _currentEnded = true;
    // 先按住声音再走，不然退出去的瞬间还响着。
    c.pause();
    if (!_isReward) {
      _leftAfterEnd = true;
      Navigator.of(context).maybePop();
      return;
    }
    unawaited(_onRewardClipFinished());
  }

  /// 奖励模式：这一片整片看完了 —— 记一笔，还有额度就接着放下一个。
  Future<void> _onRewardClipFinished() async {
    final finished = _current.id;
    await ref.read(videoProgressProvider.notifier).markFinished(finished);
    if (!mounted || _leftAfterEnd) return;
    if (_leftSeconds <= _chainTailSeconds) {
      _leftAfterEnd = true;
      Navigator.of(context).maybePop();
      return;
    }
    await _playNext(finished);
  }

  /// 换下一片：队列走到头了就重新排一局（全都看完过一轮则清空记录重头轮）。
  Future<void> _playNext(String justFinished) async {
    final old = _controller;
    _controller = null;
    _cursor++;
    if (_cursor >= _queue.length) {
      final plan = planRewardPlaylist(
        library: ref.read(videoLibraryProvider),
        progress: ref.read(videoProgressProvider),
        avoid: justFinished,
        rng: _rng,
      );
      if (!mounted || _leftAfterEnd) return;
      if (plan.restarted) {
        await ref.read(videoProgressProvider.notifier).clearAll();
        if (!mounted || _leftAfterEnd) return;
      }
      if (plan.videos.isEmpty) {
        _leftAfterEnd = true;
        Navigator.of(context).maybePop();
        return;
      }
      setState(() {
        _queue = plan.videos;
        _cursor = 0;
      });
    }
    await old?.dispose();
    if (!mounted || _leftAfterEnd) return;
    setState(() => _error = null);
    _savedSeconds = -1;
    await _init();
  }

  /// 点画面只用来「接着播」。
  ///
  /// 播放中碰到画面**不暂停**：小孩看视频手总在屏幕上摸，一按画面就断了；
  /// 要暂停请用下面的控制条。
  void _resumeByTouch() {
    final c = _controller;
    if (c == null || !c.value.isInitialized || c.value.isPlaying) return;
    if (c.value.isCompleted) c.seekTo(Duration.zero);
    c.play();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _current.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: _error != null
            ? Center(child: _errorView())
            : (c == null || !c.value.isInitialized)
                ? const Center(child: CircularProgressIndicator())
                : _playerView(c),
      ),
    );
  }

  Widget _errorView() {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.videocam_off_rounded, color: Colors.white54, size: 56),
          const SizedBox(height: 14),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _retry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }

  Widget _playerView(VideoPlayerController c) {
    return PlayerStage(
      aspectRatio: c.value.aspectRatio,
      video: Stack(
        fit: StackFit.expand,
        children: [
          VideoPlayer(c),
          // 点画面任意位置接着播（播放中点它不做任何事）。
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _resumeByTouch,
          ),
          ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: c,
            builder: (context, value, _) => value.isPlaying
                ? const SizedBox.shrink()
                // 正中那个圆钮是「指示」，不是按钮：不吃点击，
                // 点它和点画面别处一样，都交给下面那层 GestureDetector。
                : IgnorePointer(
                    child: Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.45),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          value.isCompleted
                              ? Icons.replay_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 44,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
      controls: ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: c,
        builder: (context, value, _) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: _togglePlay,
                  icon: Icon(
                    value.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: Colors.white,
                  ),
                  tooltip: value.isPlaying ? '暂停' : '播放',
                ),
                Text(
                  '${_fmt(value.position)} / ${_fmt(value.duration)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Text(
                    _cornerLabel,
                    style: TextStyle(
                        color: _isReward ? Colors.amberAccent : Colors.white38,
                        fontSize: 12,
                        fontWeight: _isReward
                            ? FontWeight.w700
                            : FontWeight.w400),
                  ),
                ),
              ],
            ),
            Slider(
              value: _sliderValue(value),
              onChanged: (v) => c.seekTo(
                  Duration(milliseconds: (v * value.duration.inMilliseconds).round())),
              activeColor: Colors.white,
              inactiveColor: Colors.white24,
            ),
          ],
        ),
      ),
    );
  }

  /// 控制条右上角那句话：奖励模式报「还剩几秒」，普通播放报来源。
  String get _cornerLabel {
    if (!_isReward) return widget.video.isLocal ? '本机视频' : '网络视频';
    // 第一次奖励、还在放第一片：这一局就是「整片看完」。
    if (widget.reward!.index <= 1 && _cursor == 0) return '奖励 · 整片看完';
    return '奖励 · 还剩 $_leftSeconds 秒';
  }

  double _sliderValue(VideoPlayerValue v) {
    final total = v.duration.inMilliseconds;
    if (total <= 0) return 0;
    return (v.position.inMilliseconds / total).clamp(0.0, 1.0);
  }

  void _togglePlay() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (c.value.isCompleted) {
      c.seekTo(Duration.zero);
      c.play();
      return;
    }
    c.value.isPlaying ? c.pause() : c.play();
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
  }
}

/// 播放画面 + 控制条。
///
/// 画面只吃剩下的高度：竖屏（或平板上的）视频比屏幕还高，早先按宽度撑高的写法
/// 会把控制条顶到 SafeArea 外面去，正好被系统导航条盖住。
class PlayerStage extends StatelessWidget {
  const PlayerStage({
    super.key,
    required this.aspectRatio,
    required this.video,
    required this.controls,
  });

  /// 视频宽高比；拿不到时按 16:9 算。
  final double aspectRatio;
  final Widget video;
  final Widget controls;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: aspectRatio <= 0 ? 16 / 9 : aspectRatio,
              child: video,
            ),
          ),
        ),
        controls,
      ],
    );
  }
}
