import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xedu/features/pattern_quiz/pattern_age_select_screen.dart';
import 'package:xedu/features/pattern_quiz/pattern_quiz_bank.dart';
import 'package:xedu/features/pattern_quiz/pattern_quiz_models.dart';
import 'package:xedu/features/pattern_quiz/pattern_quiz_screen.dart';
import 'package:xedu/features/pattern_quiz/pic_view.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('规律题渲染', () {
    testWidgets('题库里每一种元素都能正常绘制', (tester) async {
      // 收集题库中出现过的所有不同 Pic，逐个渲染，确保没有绘制异常。
      final pics = <String, Pic>{};
      void add(Pic p) => pics[p.id] = p;
      for (final q in kPatternQuestions) {
        q.items.forEach(add);
        q.distractors.forEach(add);
      }

      await tester.pumpWidget(_host(
        SingleChildScrollView(
          child: Wrap(
            children: [
              for (final p in pics.values)
                SizedBox(width: 90, height: 90, child: PicView(pic: p)),
            ],
          ),
        ),
      ));

      expect(tester.takeException(), isNull);
      expect(pics.length, greaterThan(20));
    });
  });

  group('年龄选择流程', () {
    /// 用平板尺寸的视口，让 5 张年龄卡一次全部可见。
    void useTabletView(WidgetTester tester) {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    testWidgets('每个年龄档位都能单选进入答题', (tester) async {
      useTabletView(tester);
      await tester.pumpWidget(const MaterialApp(home: PatternAgeSelectScreen()));

      // 五个年龄档位都在（含新增的 2–3 岁）
      for (final g in PatternAgeGroup.values) {
        expect(find.text(g.ageText), findsOneWidget);
      }

      // 默认勾选 3–4 岁，先取消，再只选 5–6 岁
      await tester.tap(find.text('3–4 岁'));
      await tester.pump();
      await tester.tap(find.text('5–6 岁'));
      await tester.pump();
      expect(find.text('已选 1 个年龄段'), findsOneWidget);

      await tester.tap(find.text('开始闯关'));
      await tester.pumpAndSettle();

      expect(find.byType(PatternQuizScreen), findsOneWidget);
      expect(
          find.text('第 1 / ${patternBankFor(PatternAgeGroup.preschool).length} 题'),
          findsOneWidget);
      expect(find.text('请选择'), findsOneWidget);

      // 四个备选（A–D）
      for (final l in ['A', 'B', 'C', 'D']) {
        expect(find.text(l), findsOneWidget);
      }
    });

    testWidgets('多选年龄时合并题库一起出题', (tester) async {
      useTabletView(tester);
      await tester.pumpWidget(const MaterialApp(home: PatternAgeSelectScreen()));

      // 默认 3–4 岁，再勾上 5–6 岁 → 两档合并
      await tester.tap(find.text('5–6 岁'));
      await tester.pump();
      expect(find.text('已选 2 个年龄段'), findsOneWidget);

      await tester.tap(find.text('开始闯关'));
      await tester.pumpAndSettle();

      final total = patternBankForAges(
              {PatternAgeGroup.toddler, PatternAgeGroup.preschool})
          .length;
      expect(find.text('第 1 / $total 题'), findsOneWidget);
    });

    testWidgets('一个都不选时不能开始', (tester) async {
      useTabletView(tester);
      await tester.pumpWidget(const MaterialApp(home: PatternAgeSelectScreen()));

      await tester.tap(find.text('3–4 岁')); // 取消默认选择
      await tester.pump();

      expect(find.text('还没有选择年龄段'), findsOneWidget);
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('每题都能答题（点第一个选项不抛异常）', (tester) async {
      for (final g in PatternAgeGroup.values) {
        await tester.pumpWidget(MaterialApp(home: PatternQuizScreen(ages: {g})));
        await tester.pump();
        expect(find.text('请选择'), findsOneWidget, reason: g.ageText);
        await tester.tap(find.text('A'));
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull, reason: g.ageText);
      }
    });
  });
}
