import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../core/utils.dart';
import '../data/models.dart';
import 'auth.dart';
import 'prefs.dart';

/// 单门课程的学习记录。
@immutable
class CourseStudy {
  const CourseStudy({
    required this.courseId,
    this.done = const {},
    this.quizBest = const {},
  });

  factory CourseStudy.fromJson(Map<String, dynamic> json) => CourseStudy(
        courseId: json['courseId'] as String,
        done: (json['done'] as List? ?? const []).map((e) => e as String).toSet(),
        quizBest: (json['quiz'] as Map? ?? const {})
            .map((k, v) => MapEntry(k as String, (v as num).toInt())),
      );

  final String courseId;
  final Set<String> done;
  final Map<String, int> quizBest; // lessonId -> 最好得分（百分比）
}

/// 用户学习总状态（按用户持久化）。
@immutable
class StudyState {
  const StudyState({
    this.courses = const {},
    this.dayMinutes = const {},
    this.streak = 0,
    this.lastStudyYmd,
  });

  factory StudyState.fromJson(Map<String, dynamic> json) => StudyState(
        courses: (json['courses'] as Map? ?? const {})
            .map((k, v) => MapEntry(
                  k as String,
                  CourseStudy.fromJson(Map<String, dynamic>.from(v as Map)),
                )),
        dayMinutes: (json['days'] as Map? ?? const {})
            .map((k, v) => MapEntry(k as String, (v as num).toInt())),
        streak: (json['streak'] as num?)?.toInt() ?? 0,
        lastStudyYmd: json['last'] as String?,
      );

  final Map<String, CourseStudy> courses;
  final Map<String, int> dayMinutes; // yyyy-MM-dd -> 学习分钟数
  final int streak;
  final String? lastStudyYmd;

  int get totalDone => courses.values.fold(0, (sum, c) => sum + c.done.length);

  int get totalMinutes => dayMinutes.values.fold(0, (a, b) => a + b);

  int minutesOn(String ymdKey) => dayMinutes[ymdKey] ?? 0;

  Map<String, dynamic> toJson() => {
        'courses': courses.map(
          (k, c) => MapEntry(k, {
            'courseId': c.courseId,
            'done': c.done.toList(),
            'quiz': c.quizBest,
          }),
        ),
        'days': dayMinutes,
        'streak': streak,
        'last': lastStudyYmd,
      };
}

/// 学习进度控制器。切换登录用户时自动加载 / 清空；没登录就记在游客档里。
class StudyController extends Notifier<StudyState> {
  @override
  StudyState build() {
    final uid = ref.watch(authControllerProvider.select((s) => s.user?.id)) ??
        kGuestUid;
    final raw = ref.watch(prefsProvider).getString(studyKeyFor(uid));
    if (raw == null || raw.isEmpty) return const StudyState();
    try {
      return StudyState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const StudyState();
    }
  }

  String get _uid => ref.read(authControllerProvider).user?.id ?? kGuestUid;

  // ---- 派生查询 ----
  bool isEnrolled(String courseId) => state.courses.containsKey(courseId);

  bool isLessonDone(String courseId, String lessonId) =>
      state.courses[courseId]?.done.contains(lessonId) ?? false;

  int? quizBestOf(String courseId, String lessonId) =>
      state.courses[courseId]?.quizBest[lessonId];

  int doneCount(String courseId) =>
      state.courses[courseId]?.done.length ?? 0;

  double progressOf(Course course) {
    if (course.totalLessons == 0) return 0;
    return doneCount(course.id) / course.totalLessons;
  }

  // ---- 变更操作 ----
  void enroll(String courseId) {
    final uid = _uid;
    if (state.courses.containsKey(courseId)) return;
    _mutate(uid, (s) => StudyState(
          courses: {...s.courses, courseId: CourseStudy(courseId: courseId)},
          dayMinutes: s.dayMinutes,
          streak: s.streak,
          lastStudyYmd: s.lastStudyYmd,
        ));
  }

  void completeLesson(Course course, Lesson lesson) {
    final uid = _uid;
    _mutate(uid, (s) {
      final already = s.courses[course.id]?.done.contains(lesson.id) ?? false;
      if (already) return s; // 幂等：已完成的课时不再重复累计学习时长
      final prev = s.courses[course.id] ?? CourseStudy(courseId: course.id);
      final done = prev.done.contains(lesson.id)
          ? prev.done
          : {...prev.done, lesson.id};
      final nextCourse =
          CourseStudy(courseId: course.id, done: done, quizBest: prev.quizBest);

      final today = todayYmd();
      final days = {...s.dayMinutes};
      days[today] = (days[today] ?? 0) + lesson.durationMin;

      var streak = s.streak;
      var last = s.lastStudyYmd;
      if (last != today) {
        final yesterday = ymd(DateTime.now().subtract(const Duration(days: 1)));
        streak = last == yesterday ? s.streak + 1 : 1;
        last = today;
      }
      return StudyState(
        courses: {...s.courses, course.id: nextCourse},
        dayMinutes: days,
        streak: streak,
        lastStudyYmd: last,
      );
    });
  }

  void recordQuizBest(String courseId, String lessonId, int percent) {
    final uid = _uid;
    _mutate(uid, (s) {
      final prev = s.courses[courseId] ?? CourseStudy(courseId: courseId);
      final old = prev.quizBest[lessonId];
      if (old != null && old >= percent) return s;
      final quizBest = {...prev.quizBest, lessonId: percent};
      return StudyState(
        courses: {
          ...s.courses,
          courseId: CourseStudy(courseId: courseId, done: prev.done, quizBest: quizBest),
        },
        dayMinutes: s.dayMinutes,
        streak: s.streak,
        lastStudyYmd: s.lastStudyYmd,
      );
    });
  }

  void _mutate(String uid, StudyState Function(StudyState) apply) {
    final next = apply(state);
    ref.read(prefsProvider).setString(studyKeyFor(uid), jsonEncode(next.toJson()));
    state = next;
  }
}

final studyControllerProvider =
    NotifierProvider<StudyController, StudyState>(StudyController.new);
