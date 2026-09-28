import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xedu/core/constants.dart';
import 'package:xedu/features/pattern_quiz/anti_guess.dart';
import 'package:xedu/features/profile/profile_screen.dart';
import 'package:xedu/state/prefs.dart';

void main() {
  group('把正确答案放进指定的格子', () {
    test('第一格 / 中间 / 最后一格', () {
      expect(withAnswerAt([1, 2, 3], 9, 0), [9, 1, 2, 3]);
      expect(withAnswerAt([1, 2, 3], 9, 2), [1, 2, 9, 3]);
      expect(withAnswerAt([1, 2, 3], 9, 3), [1, 2, 3, 9]);
    });

    test('干扰项不够、下标越界也不丢东西', () {
      // 干扰项池太小时格子会少于四个，越界一律退到最后一格。
      expect(withAnswerAt([1], 9, 3), [1, 9]);
      expect(withAnswerAt([], 9, 0), [9]);
      expect(withAnswerAt([1, 2], 9, -5), [9, 1, 2]);
    });
  });

  group('防猜答案开关', () {
    Future<ProviderContainer> host() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(
        overrides: [prefsProvider.overrideWithValue(prefs)],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('缺省开着', () async {
      final c = await host();
      expect(c.read(quizAntiGuessProvider), isTrue);
    });

    test('关掉之后记进本地，重启还是关着', () async {
      final c = await host();
      final prefs = c.read(prefsProvider);

      c.read(quizAntiGuessProvider.notifier).set(false);
      expect(c.read(quizAntiGuessProvider), isFalse);
      expect(prefs.getBool(kQuizAntiGuessKey), isFalse);

      // 换一份容器读同一份 prefs ＝ 重启一次 App
      final again = ProviderContainer(
        overrides: [prefsProvider.overrideWithValue(prefs)],
      );
      addTearDown(again.dispose);
      expect(again.read(quizAntiGuessProvider), isFalse);
    });
  });

  testWidgets('「我的 → 偏好设置」里能开关防猜答案', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [prefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(c.dispose);

    tester.view.physicalSize = const Size(800, 1280);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: const MaterialApp(home: Scaffold(body: ProfileScreen())),
    ));
    await tester.pump();

    expect(find.text('偏好设置'), findsOneWidget);
    expect(find.text('防猜答案'), findsOneWidget);
    expect(find.text('答错后答案挪到刚点的那个格子'), findsOneWidget);

    await tester.ensureVisible(find.text('防猜答案'));
    await tester.pump();
    await tester.tap(find.text('防猜答案'));
    await tester.pump();

    expect(c.read(quizAntiGuessProvider), isFalse);
    expect(prefs.getBool(kQuizAntiGuessKey), isFalse);
  });
}
