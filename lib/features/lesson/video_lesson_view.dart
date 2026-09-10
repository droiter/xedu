import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// 在线视频课视图。基于 video_player，播放失败时给出兜底占位。
class VideoLessonView extends StatefulWidget {
  const VideoLessonView({super.key, required this.videoUrl, this.caption});

  final String videoUrl;
  final String? caption;

  @override
  State<VideoLessonView> createState() => _VideoLessonViewState();
}

class _VideoLessonViewState extends State<VideoLessonView> {
  VideoPlayerController? _controller;
  bool _failed = false;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    controller.setLooping(true);
    _controller = controller;
    try {
      await controller.initialize();
      if (!mounted) return;
      setState(() => _ready = true);
      await controller.play();
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    final c = _controller;
    if (c == null) return;
    setState(() {
      c.value.isPlaying ? c.pause() : c.play();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = [Theme.of(context).colorScheme.primary, const Color(0xFF9A5CFF)];

    if (_failed) {
      return _placeholder(context, Icons.cloud_off_rounded, '视频暂时无法播放\n联网后返回即可重试');
    }
    if (!_ready || _controller == null) {
      return _placeholder(context, null, null, loading: true);
    }
    final c = _controller!;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: c.value.aspectRatio <= 0 ? 16 / 9 : c.value.aspectRatio,
            child: Stack(
              fit: StackFit.expand,
              children: [
                GestureDetector(onTap: _togglePlay, child: VideoPlayer(c)),
                if (!c.value.isPlaying)
                  Center(
                    child: GestureDetector(
                      onTap: _togglePlay,
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.45),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36),
                      ),
                    ),
                  ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: VideoProgressIndicator(
                    c,
                    allowScrubbing: true,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    colors: const VideoProgressColors(
                      playedColor: Colors.white,
                      bufferedColor: Colors.white38,
                      backgroundColor: Colors.black26,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (widget.caption != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [colors[0], colors[1]]),
              ),
              child: Text(
                ' ▶ ${widget.caption}',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }

  Widget _placeholder(BuildContext context, IconData? icon, String? text,
      {bool loading = false}) {
    return Container(
      width: double.infinity,
      height: 190,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Theme.of(context).colorScheme.primary.withOpacity(0.25),
                    Colors.deepPurple.withOpacity(0.15)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              const SizedBox(
                width: 28, height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.6),
              )
            else
              Icon(icon, color: Colors.white, size: 44),
            if (text != null) ...[
              const SizedBox(height: 12),
              Text(text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ],
        ),
      ),
    );
  }
}
