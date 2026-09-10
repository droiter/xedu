import '../../data/models.dart';

/// 找到课程中第一个「未完成」的课时；全部完成时返回 null。
Lesson? firstUndoneLesson(Course course, bool Function(String lessonId) isDone) {
  for (final lesson in course.lessons) {
    if (!isDone(lesson.id)) return lesson;
  }
  return null;
}

/// 返回指定课时之后的那一课（跨章），若已是最后一课返回 null。
Lesson? lessonAfter(Course course, String lessonId) {
  final lessons = course.lessons;
  for (var i = 0; i < lessons.length; i++) {
    if (lessons[i].id == lessonId) {
      return i + 1 < lessons.length ? lessons[i + 1] : null;
    }
  }
  return null;
}

/// 课时在一门课中的整体序号（从 1 开始）。
int lessonOrdinal(Course course, String lessonId) {
  final lessons = course.lessons;
  for (var i = 0; i < lessons.length; i++) {
    if (lessons[i].id == lessonId) return i + 1;
  }
  return 0;
}
