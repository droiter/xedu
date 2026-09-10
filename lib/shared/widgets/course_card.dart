import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../data/models.dart';

/// 根据课程 id 生成稳定的封面渐变色。
List<Color> coverGradient(String id) {
  final sum = id.codeUnits.fold<int>(0, (a, b) => a + b);
  return kCoverPalette[sum % kCoverPalette.length];
}

/// 分类图标名称 -> IconData。
IconData categoryIcon(String iconName) {
  switch (iconName) {
    case 'code':
      return Icons.code_rounded;
    case 'translate':
      return Icons.translate_rounded;
    case 'calculate':
      return Icons.calculate_rounded;
    case 'work':
      return Icons.work_rounded;
    case 'science':
      return Icons.science_rounded;
    case 'palette':
      return Icons.palette_rounded;
    default:
      return Icons.auto_stories_rounded;
  }
}

/// 格式化短时长：「45 分钟」「1.5 小时」。
String formatShort(int minutes) {
  if (minutes < 60) return '$minutes 分钟';
  if (minutes % 60 == 0) return '${minutes ~/ 60} 小时';
  return '${(minutes / 60).toStringAsFixed(1)} 小时';
}

/// 通用课程卡片。progress 传入则展示学习进度。
class CourseCard extends StatelessWidget {
  const CourseCard({super.key, required this.course, this.progress, this.onTap});

  final Course course;
  final double? progress;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = coverGradient(course.id);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 122,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _CoverTile(course: course, colors: colors),
                const SizedBox(width: 14),
                Expanded(child: _Info(course: course, progress: progress)),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CoverTile extends StatelessWidget {
  const _CoverTile({required this.course, required this.colors});

  final Course course;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      height: 96,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: Icon(
          categoryIcon(course.categoryId),
          color: Colors.white.withOpacity(0.95),
          size: 34,
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.course, required this.progress});

  final Course course;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final grey = Theme.of(context).colorScheme.onSurfaceVariant;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          course.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 5),
        Text(
          '${course.teacher} · ${course.level}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: grey),
        ),
        const SizedBox(height: 6),
        Text(
          '${course.totalLessons} 节课 · ${formatShort(course.totalMinutes)}',
          style: TextStyle(fontSize: 12, color: grey),
        ),
        if (progress != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${(progress!.clamp(0.0, 1.0) * 100).round()}%',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: colorScheme.primary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress!.clamp(0.0, 1.0),
                    minHeight: 5,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
