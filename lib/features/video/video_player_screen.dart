import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../state/providers.dart';

/// 视频播放页。
///
/// 这里**不做任何返回拦截**：按返回键随时退回到上一页，
/// 不弹家长验证，也不受播放进度影响。
class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({super.key, required this.video});

  final VideoItem video;

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final item = widget.video;
    final controller = item.isLocal
        ? VideoPlayerController.file(File(item.source))
        : VideoPlayerController.networkUrl(Uri.parse(item.source));
    _controller = controller;
    try {
      await controller.initialize();
      if (!mounted) return;
      setState(() {});
      await controller.play();
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = item.isLocal
          ? '这个视频文件打不开了\n可能已被删除，请重新添加'
          : '视频暂时无法播放\n请检查网络后重试');
    }
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

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
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
          widget.video.title,
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
          // 点画面任意位置播放 / 暂停。
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _togglePlay,
          ),
          ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: c,
            builder: (context, value, _) => value.isPlaying
                ? const SizedBox.shrink()
                : Center(
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
                    widget.video.isLocal ? '本机视频' : '网络视频',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
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
