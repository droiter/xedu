import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xedu/features/pattern_quiz/pattern_quiz_bank.dart';
import 'package:xedu/features/pattern_quiz/pattern_quiz_models.dart';
import 'package:xedu/features/pattern_quiz/pattern_quiz_screen.dart';
import 'package:xedu/features/pattern_quiz/pic_view.dart';
import 'package:xedu/state/providers.dart';

/// 找规律页里每张图能画画的那个方框边长 —— 跟 PicView 里算的一致：格子的 min(宽, 高)。
List<double> _picBoxes(WidgetTester tester) {
  final boxes = <double>[];
  final pics = find.byType(PicView);
  for (var i = 0; i < pics.evaluate().length; i++) {
    final s = tester.getSize(pics.at(i));
    boxes.add(s.width < s.height ? s.width : s.height);
  }
  return boxes;
}

Future<void> _pumpQuiz(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(ProviderScope(
    overrides: [prefsProvider.overrideWithValue(prefs)],
    child: const MaterialApp(
      home: PatternQuizScreen(ages: {PatternAgeGroup.preschool}),
    ),
  ));
  await tester.pump();
}

void main() {
  testWidgets('题面四格与选项四格用同一个绘制方框', (tester) async {
    // 手机竖屏 / 手机横屏 / 平板竖屏 / 平板横屏
    const sizes = [
      Size(360, 640),
      Size(640, 360),
      Size(800, 1280),
      Size(1280, 800),
    ];

    for (final size in sizes) {
      await _pumpQuiz(tester, size);
      final boxes = _picBoxes(tester);
      // 题面四格里有一格是「?」，所以是 3 张题面图 + 4 张选项图。
      expect(boxes.length, 7, reason: '$size 应该正好 7 张图');
      final slot = boxes.first.toDouble();
      for (var i = 1; i < boxes.length; i++) {
        // 长短 / 厚薄这类题要拿题面当尺子量选项，方框差一点就是两个基准。
        expect(boxes[i], moreOrLessEquals(slot, epsilon: 0.5),
            reason: '$size：第 $i 张图的方框是 ${boxes[i]}，题面是 $slot');
      }
    }
  });

  test('每道题都是四格，选项也是四个 —— 两行格子数一样才可能共用一个方框', () {
    for (final q in kPatternQuestions) {
      expect(q.items.length, 4, reason: q.id);
    }
  });
}
