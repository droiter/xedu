import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils.dart';
import '../../data/models.dart';
import '../../shared/progress_utils.dart';
import '../../shared/widgets/content_viewer.dart';
import '../../state/providers.dart';
import '../quiz/quiz_screen.dart';
import 'video_lesson_view.dart';

/// 课时学习页：视频 / 讲义 / 随堂测验 / 完成标记。
class LessonScreen extends ConsumerStatefulWidget {
  const LessonScreen({super.key, required this.course, required this.lessonId});

  final Course course;
  final String lessonId;

  @override
  ConsumerState<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends ConsumerState<LessonScreen> {
  Lesson get _lesson {
    for (final l in widget.course.lessons) {
      if (l.id == widget.lessonId) return l;
    }
    return widget.course.lessons.first;
  }

  @override
  Widget build(BuildContext context) {
    final course = widget.course;
    final lesson = _lesson;
    final study = ref.watch(studyControllerProvider);
    final cs = study.courses[course.id];
    final done = cs?.done.contains(lesson.id) ?? false;
    final best = cs?.quizBest[lesson.id];
    final next = lessonAfter(course, lesson.id);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('第 ${lessonOrdinal(course, lesson.id)} 节 · 共 ${course.totalLessons} 节'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  Text(lesson.title,
                      style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _tag(scheme, Icons.schedule_rounded, shortMinutes(lesson.durationMin)),
                      if (lesson.hasVideo)
                        _tag(scheme, Icons.ondemand_video_rounded, '含视频'),
                      if (lesson.hasQuiz) _tag(scheme, Icons.quiz_rounded, '随堂测验'),
                      if (done) _tag(scheme, Icons.check_circle_rounded, '已学完', done: true),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (lesson.hasVideo) ...[
                    VideoLessonView(
                      videoUrl: lesson.videoUrl!,
                      caption: lesson.hasQuiz ? '观看后完成下方随堂测验' : null,
                    ),
                    const SizedBox(height: 20),
                  ],
                  ContentViewer(blocks: lesson.blocks),
                  if (lesson.blocks.isEmpty && !lesson.hasVideo)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: Text('本课暂无讲义，可查看测验挑战')),
                    ),
                  if (best != null)
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.stars_rounded, color: scheme.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '随堂测验最好成绩：$best 分。答得不理想可以随时重做。',
                              style: TextStyle(color: scheme.onPrimaryContainer, fontSize: 13.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            _bottomBar(scheme, lesson, done, next),
          ],
        ),
      ),
    );
  }

  Widget _tag(ColorScheme scheme, IconData icon, String text, {bool done = false}) {
    final color = done ? Colors.green : scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: (done ? Colors.green : scheme.primary).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }

  Widget _bottomBar(ColorScheme scheme, Lesson lesson, bool done, Lesson? next) {
    final course = widget.course;
    return Material(
      elevation: 10,
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (lesson.hasQuiz || next != null)
              Row(
                children: [
                  if (lesson.hasQuiz) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => QuizScreen(course: course, lesson: lesson),
                        )),
                        icon: const Icon(Icons.quiz_rounded, size: 18),
                        label: Text(done ? '重做测验' : '随堂测验'),
                      ),
                    ),
                    if (next != null) const SizedBox(width: 10),
                  ],
                  if (next != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _goToLesson(context, next.id),
                        icon: const Icon(Icons.skip_next_rounded, size: 18),
                        label: const Text('下一节'),
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: () => _onPrimary(context, lesson, done, next),
                icon: Icon(done ? Icons.emoji_events_rounded : Icons.check_circle_rounded),
                label: Text(
                  !done
                      ? '完成本课'
                      : next != null
                          ? '已完成本课 · 继续学习'
                          : '学完全部课程，返回',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onPrimary(BuildContext context, Lesson lesson, bool done, Lesson? next) {
    if (!done) {
      ref.read(studyControllerProvider.notifier).completeLesson(widget.course, lesson);
    }
    if (next != null) {
      _goToLesson(context, next.id);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('恭喜！你已经完成了这门课的全部课时')));
      Navigator.of(context).pop();
    }
  }

  void _goToLesson(BuildContext context, String lessonId) {
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => LessonScreen(course: widget.course, lessonId: lessonId),
    ));
  }
}
