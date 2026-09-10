import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils.dart';
import '../../data/models.dart';
import '../../shared/progress_utils.dart';
import '../../shared/widgets/course_card.dart' show coverGradient;
import '../../state/providers.dart';
import '../lesson/lesson_screen.dart';

/// 课程详情页：报名、大纲、学习进度。
class CourseDetailScreen extends ConsumerWidget {
  const CourseDetailScreen({super.key, required this.course});

  final Course course;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final study = ref.watch(studyControllerProvider);
    final enrolled = study.courses.containsKey(course.id);
    final progress =
        enrolled ? study.courses[course.id]!.done.length / course.totalLessons : 0.0;

    final wide = MediaQuery.of(context).size.width >= 860;

    final panel = _panel(context, ref, enrolled, progress);
    final overview = _overview(context, ref, study, enrolled);

    return Scaffold(
      appBar: AppBar(
        title: const Text('课程详情'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              tooltip: '分享课程',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('分享功能将在接入后端后开放')));
              },
              icon: const Icon(Icons.share_outlined),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        child: wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: overview),
                  const SizedBox(width: 24),
                  SizedBox(width: 380, child: panel),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  panel,
                  const SizedBox(height: 24),
                  overview,
                ],
              ),
      ),
    );
  }

  // ---------- 卡片（顶部 / 右栏）----------
  Widget _panel(BuildContext context, WidgetRef ref, bool enrolled, double progress) {
    final colors = coverGradient(course.id);
    final percent = (progress * 100).round();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(course.title,
              style: const TextStyle(
                  color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(course.subtitle,
              style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13.5)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metaChip(Colors.white, Icons.folder_copy, '${course.chapterCount} 章'),
              _metaChip(Colors.white, Icons.play_circle_outline, '${course.totalLessons} 节'),
              _metaChip(Colors.white, Icons.schedule_rounded, formatDuration(course.totalMinutes)),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.white.withOpacity(0.25),
                child: Text(course.teacher.isNotEmpty ? course.teacher[0] : '师',
                    style: const TextStyle(color: Colors.white, fontSize: 14)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(course.teacher,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.95), fontSize: 14)),
                    Text(course.level,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.7), fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: colors.first,
              ),
              onPressed: () => _onPrimaryAction(context, ref),
              child: Text(
                !enrolled
                    ? '报名学习'
                    : progress >= 1
                        ? '完成度 100% · 再来一遍'
                        : '继续学习（$percent%）',
              ),
            ),
          ),
          if (enrolled && progress < 1) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 7,
                backgroundColor: Colors.white.withOpacity(0.3),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _metaChip(Color textColor, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.22),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: textColor, size: 15),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: textColor, fontSize: 12.5)),
        ],
      ),
    );
  }

  // ---------- 操作 ----------
  void _onPrimaryAction(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(studyControllerProvider.notifier);
    if (!notifier.isEnrolled(course.id)) {
      notifier.enroll(course.id);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('报名成功，快去完成第一章吧')));
    }
    _openFirstUndone(context, ref);
  }

  void _openFirstUndone(BuildContext context, WidgetRef ref) {
    final study = ref.read(studyControllerProvider);
    bool isDone(String id) => study.courses[course.id]?.done.contains(id) ?? false;
    final target = firstUndoneLesson(course, isDone);
    _openLesson(context, target?.id ?? course.lessons.first.id);
  }

  void _openLesson(BuildContext context, String lessonId) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => LessonScreen(course: course, lessonId: lessonId),
    ));
  }

  // ---------- 大纲 ----------
  Widget _overview(BuildContext context, WidgetRef ref, StudyState study, bool enrolled) {
    final wide = MediaQuery.of(context).size.width >= 860;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (wide) ...[
          _sectionTitle('课程介绍'),
          const SizedBox(height: 10),
          _desc(context),
          const SizedBox(height: 26),
          _sectionTitle('课程大纲'),
          const SizedBox(height: 8),
        ] else ...[
          _sectionTitle('课程介绍'),
          const SizedBox(height: 10),
          _desc(context),
          const SizedBox(height: 24),
          _sectionTitle('课程大纲'),
          const SizedBox(height: 8),
        ],
        for (var ci = 0; ci < course.chapters.length; ci++)
          _chapter(context, course.chapters[ci], ci, study, enrolled),
      ],
    );
  }

  Widget _sectionTitle(String text) => Text(text,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800));

  Widget _desc(BuildContext context) {
    return Text(
      course.description,
      style: TextStyle(
        fontSize: 14.5,
        height: 1.8,
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.85),
      ),
    );
  }

  Widget _chapter(BuildContext context, CourseChapter chapter, int index, StudyState study,
      bool enrolled) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: index == 0,
          shape: const Border(),
          collapsedShape: const Border(),
          title:
              Text(chapter.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          children: [
            for (final lesson in chapter.lessons)
              _lessonTile(context, lesson, study, enrolled),
          ],
        ),
      ),
    );
  }

  Widget _lessonTile(BuildContext context, Lesson lesson, StudyState study, bool enrolled) {
    final done = study.courses[course.id]?.done.contains(lesson.id) ?? false;
    final best = study.courses[course.id]?.quizBest[lesson.id];
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        if (!enrolled) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('先报名本课程，即可解锁全部课时')));
          return;
        }
        _openLesson(context, lesson.id);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Row(
          children: [
            done
                ? const Icon(Icons.check_circle_rounded, color: Colors.green, size: 22)
                : Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scheme.surfaceContainerHighest,
                    ),
                    child: Text(
                      '${lessonOrdinal(course, lesson.id)}',
                      style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                    ),
                  ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                lesson.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14.5,
                  color: done ? scheme.onSurfaceVariant : scheme.onSurface,
                  decoration: done ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            if (lesson.hasVideo) Icon(Icons.ondemand_video_rounded, size: 16, color: scheme.outline),
            if (lesson.hasQuiz)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Icon(Icons.quiz_outlined, size: 16, color: scheme.outline),
              ),
            if (best != null)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Text('$best 分', style: TextStyle(fontSize: 11, color: scheme.primary)),
              ),
            const SizedBox(width: 8),
            Text(shortMinutes(lesson.durationMin),
                style: TextStyle(fontSize: 12, color: scheme.outline)),
          ],
        ),
      ),
    );
  }
}
