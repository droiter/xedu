import 'package:flutter_test/flutter_test.dart';
import 'package:xedu/data/models.dart';
import 'package:xedu/shared/progress_utils.dart';

import 'fixtures.dart';

void main() {
  group('课程目录解析', () {
    final catalog = CatalogData.fromJson(sampleCatalogJson());

    test('解析出分类与课程', () {
      expect(catalog.categories.length, 1);
      expect(catalog.categories.first.name, '编程开发');
      expect(catalog.courses.length, 1);
    });

    test('课时 / 时长汇总正确', () {
      final course = catalog.courses.first;
      expect(course.totalLessons, 2);
      expect(course.totalMinutes, 15);
      expect(course.chapterCount, 1);
    });

    test('课程所属分类可反查', () {
      final course = catalog.courses.first;
      expect(catalog.categoryOf(course)!.id, 'code');
    });

    test('内容块与测验解析', () {
      final lessons = catalog.courses.first.lessons;
      expect(lessons[0].blocks.length, 3);
      expect(lessons[0].blocks[2].kind, BlockKind.list);
      expect(lessons[0].blocks[2].items.length, 2);

      expect(lessons[1].hasQuiz, isTrue);
      expect(lessons[1].quiz.first.answer, 0);
      expect(lessons[1].quiz.first.options.length, 2);
      expect(lessons[1].hasVideo, isFalse);
    });
  });

  group('学习进度工具', () {
    test('firstUndoneLesson 找到第一个未完成课时', () {
      final course = sampleCourse();
      final undone = firstUndoneLesson(course, (id) => id == 'l1');
      expect(undone!.id, 'l2');
    });

    test('lessonAfter 返回下一课时', () {
      final course = sampleCourse();
      expect(lessonAfter(course, 'l1')!.id, 'l2');
      expect(lessonAfter(course, 'l2'), isNull);
    });
  });
}
