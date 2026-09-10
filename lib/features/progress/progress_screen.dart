import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils.dart';
import '../../shared/widgets/content_viewer.dart';
import '../../shared/widgets/course_card.dart';
import '../../state/providers.dart';
import '../course/course_detail_screen.dart';

/// 学习进度页：数据看板 + 在学课程。
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key, required this.onExplore});

  /// 跳转到课程分类页。
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final study = ref.watch(studyControllerProvider);
    final catalogAsync = ref.watch(catalogProvider);
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      bottom: false,
      child: catalogAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('数据加载失败：$e')),
        data: (catalog) {
          final today = study.minutesOn(todayYmd());
          final actives = study.dayMinutes.keys.length;
          final totalLessons = study.totalDone;

          final enrolled = catalog.courses
              .where((c) => study.courses.containsKey(c.id))
              .toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
            children: [
              const Text('学习进度',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _statCard(context, scheme, Icons.local_fire_department, '${study.streak}', '连续天数', scheme.primary)),
                  const SizedBox(width: 10),
                  Expanded(child: _statCard(context, scheme, Icons.timelapse_rounded, '$today', '今日分钟', Colors.orange)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _statCard(context, scheme, Icons.schedule_rounded, formatDuration(study.totalMinutes), '累计时长', Colors.teal)),
                  const SizedBox(width: 10),
                  Expanded(child: _statCard(context, scheme, Icons.menu_book_rounded, '$totalLessons', '完成课时', Colors.deepPurple)),
                ],
              ),
              const SizedBox(height: 8),
              Text('已坚持学习 $actives 天 · 连续 ${study.streak} 天，继续保持！',
                  style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
              const SizedBox(height: 16),
              SectionHeader(title: '在学课程', actionText: '发现更多', onAction: onExplore),
              if (enrolled.isEmpty)
                EmptyHint(
                  icon: Icons.school_outlined,
                  text: '还没有报名的课程',
                  detail: '去逛逛课程广场，挑一门喜欢的开始吧',
                )
              else
                for (final c in enrolled) ...[
                  CourseCard(
                    course: c,
                    progress: study.courses[c.id]!.done.length / c.totalLessons,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => CourseDetailScreen(course: c),
                    )),
                  ),
                  const SizedBox(height: 12),
                ],
            ],
          );
        },
      ),
    );
  }

  Widget _statCard(BuildContext context, ColorScheme scheme, IconData icon, String value,
      String label, Color color) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
