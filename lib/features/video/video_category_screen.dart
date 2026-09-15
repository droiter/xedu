import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/content_viewer.dart';
import '../../shared/widgets/course_card.dart' show coverGradient;
import '../../state/providers.dart';
import 'video_player_screen.dart';

/// 某个分类下的视频列表，点一个就播。
class VideoCategoryScreen extends ConsumerWidget {
  const VideoCategoryScreen({
    super.key,
    required this.categoryId,
    this.onOpenManage,
  });

  final String categoryId;

  /// 分类里还没视频时，退回「我的」去添加。
  final VoidCallback? onOpenManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category =
        ref.watch(videoLibraryProvider.select((lib) => lib.byId(categoryId)));
    final scheme = Theme.of(context).colorScheme;

    if (category == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('视频')),
        body: const EmptyHint(
          icon: Icons.delete_outline_rounded,
          text: '这个分类已经不在了',
          detail: '可能刚在「我的」里被删掉了',
        ),
      );
    }

    final videos = category.videos;
    return Scaffold(
      appBar: AppBar(title: Text(category.name)),
      body: videos.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const EmptyHint(
                    icon: Icons.movie_creation_outlined,
                    text: '这个分类里还没有视频',
                    detail: '去「我的 → 我的视频」给它添几个视频吧',
                  ),
                  if (onOpenManage != null)
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        onOpenManage!();
                      },
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('去添加视频'),
                    ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
              itemCount: videos.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final v = videos[i];
                return _VideoTile(
                  index: i + 1,
                  title: v.title,
                  gradient: coverGradient(v.id),
                  isLocal: v.isLocal,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => VideoPlayerScreen(video: v),
                    ),
                  ),
                );
              },
            ),
      bottomNavigationBar: videos.isEmpty
          ? null
          : Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
              child: Text(
                '共 ${videos.length} 个视频 · 点一下就能播放，随时按返回键退出',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ),
    );
  }
}

class _VideoTile extends StatelessWidget {
  const _VideoTile({
    required this.index,
    required this.title,
    required this.gradient,
    required this.isLocal,
    required this.onTap,
  });

  final int index;
  final String title;
  final List<Color> gradient;
  final bool isLocal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(16),
      color: scheme.surfaceContainerHigh,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Container(
                width: 88,
                height: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradient,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.play_arrow_rounded,
                    color: Colors.white, size: 30),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Text('第 $index 个',
                            style: TextStyle(
                                fontSize: 12, color: scheme.onSurfaceVariant)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isLocal ? '本机' : '网络',
                            style: TextStyle(
                                fontSize: 11, color: scheme.onPrimaryContainer),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}
