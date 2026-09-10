import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xedu/core/utils.dart';
import 'package:xedu/state/providers.dart';

import 'fixtures.dart';

void main() {
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [prefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
  });

  group('注册 / 登录', () {
    test('注册后自动登录，重复注册被拒绝', () async {
      final err = await container.read(authControllerProvider.notifier)
          .register('小明', 'x@x.com', '1234');
      expect(err, isNull);
      expect(container.read(authControllerProvider).isLoggedIn, isTrue);
      expect(container.read(authControllerProvider).user!.name, '小明');

      final dup = await container.read(authControllerProvider.notifier)
          .register('小红', 'X@X.COM', '5678');
      expect(dup, contains('已注册'));
    });

    test('错误密码无法登录', () async {
      await container.read(authControllerProvider.notifier)
          .register('小明', 'x@x.com', '1234');
      await container.read(authControllerProvider.notifier).logout();
      expect(container.read(authControllerProvider).isLoggedIn, isFalse);

      final bad = await container.read(authControllerProvider.notifier)
          .login('x@x.com', 'wrong');
      expect(bad, isNotNull);
      final ok = await container.read(authControllerProvider.notifier)
          .login('x@x.com', '1234');
      expect(ok, isNull);
    });
  });

  group('学习进度持久化', () {
    test('报名、完成课时会累计时长并更新进度', () async {
      await container.read(authControllerProvider.notifier)
          .register('小明', 'x@x.com', '1234');
      final course = sampleCourse();
      final study = container.read(studyControllerProvider.notifier);

      study.enroll(course.id);
      expect(study.isEnrolled(course.id), isTrue);

      study.completeLesson(course, course.lessons[0]);
      expect(study.progressOf(course), 0.5);
      expect(study.doneCount(course.id), 1);

      study.completeLesson(course, course.lessons[1]);
      expect(study.progressOf(course), 1.0);

      final state = container.read(studyControllerProvider);
      expect(state.minutesOn(todayYmd()), 15); // 5 + 10
      expect(state.streak, 1);
    });

    test('测验记录最好成绩', () async {
      await container.read(authControllerProvider.notifier)
          .register('小明', 'x@x.com', '1234');
      final course = sampleCourse();
      final lesson = course.lessons[1];
      final study = container.read(studyControllerProvider.notifier);

      study.enroll(course.id);
      study.recordQuizBest(course.id, lesson.id, 33);
      expect(study.quizBestOf(course.id, lesson.id), 33);

      study.recordQuizBest(course.id, lesson.id, 100);
      expect(study.quizBestOf(course.id, lesson.id), 100);

      // 更低的分数不会覆盖最好成绩
      study.recordQuizBest(course.id, lesson.id, 50);
      expect(study.quizBestOf(course.id, lesson.id), 100);
    });

    test('退出登录后学习状态被清空', () async {
      await container.read(authControllerProvider.notifier)
          .register('小明', 'x@x.com', '1234');
      final course = sampleCourse();
      final study = container.read(studyControllerProvider.notifier);
      study.enroll(course.id);
      expect(container.read(studyControllerProvider).courses, isNotEmpty);

      await container.read(authControllerProvider.notifier).logout();
      expect(container.read(studyControllerProvider).courses, isEmpty);
    });
  });
}
