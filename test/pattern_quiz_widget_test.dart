import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xedu/features/pattern_quiz/celebration.dart';
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
      await tester
          .pumpWidget(const MaterialApp(home: PatternAgeSelectScreen()));

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
      expect(find.text('第 1 / ${PatternQuizScreen.sessionSize} 题'),
          findsOneWidget);
      expect(find.text('请选择'), findsOneWidget);

      // 四个备选（A–D）
      for (final l in ['A', 'B', 'C', 'D']) {
        expect(find.text(l), findsOneWidget);
      }
    });

    testWidgets('多选年龄时合并题库一起出题，每局仍是固定题量', (tester) async {
      useTabletView(tester);
      await tester
          .pumpWidget(const MaterialApp(home: PatternAgeSelectScreen()));

      // 默认 3–4 岁，再勾上 5–6 岁 → 两档合并
      await tester.tap(find.text('5–6 岁'));
      await tester.pump();
      expect(find.text('已选 2 个年龄段'), findsOneWidget);

      final merged = patternBankForAges(
          {PatternAgeGroup.toddler, PatternAgeGroup.preschool});
      expect(
          find.text(
              '每局随机 ${PatternQuizScreen.sessionSize} 题 · 题库共 ${merged.length} 题'),
          findsOneWidget);

      await tester.tap(find.text('开始闯关'));
      await tester.pumpAndSettle();

      expect(find.text('第 1 / ${PatternQuizScreen.sessionSize} 题'),
          findsOneWidget);
    });

    testWidgets('每个年龄档位的题库都够抽满一局', (tester) async {
      for (final g in PatternAgeGroup.values) {
        expect(patternBankFor(g).length,
            greaterThanOrEqualTo(PatternQuizScreen.sessionSize),
            reason: g.ageText);
      }
    });

    testWidgets('一个都不选时不能开始', (tester) async {
      useTabletView(tester);
      await tester
          .pumpWidget(const MaterialApp(home: PatternAgeSelectScreen()));

      await tester.tap(find.text('3–4 岁')); // 取消默认选择
      await tester.pump();

      expect(find.text('还没有选择年龄段'), findsOneWidget);
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('每题都能答题（点第一个选项不抛异常）', (tester) async {
      for (final g in PatternAgeGroup.values) {
        await tester
            .pumpWidget(MaterialApp(home: PatternQuizScreen(ages: {g})));
        await tester.pump();
        expect(find.text('请选择'), findsOneWidget, reason: g.ageText);
        await tester.tap(find.text('A'));
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull, reason: g.ageText);
      }
    });
  });

  group('答题流程', () {
    void useTabletView(WidgetTester tester) {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    /// 轮流点 A/B/C/D，直到把当前这题答对（答错会重排，所以循环几次）。
    Future<void> answerUntilRight(WidgetTester tester) async {
      const letters = ['A', 'B', 'C', 'D'];
      for (var i = 0; i < 40; i++) {
        if (find.textContaining('马上').evaluate().isNotEmpty) return;
        await tester.tap(find.text(letters[i % letters.length]));
        await tester.pump(const Duration(milliseconds: 700));
      }
      fail('连续 40 次都没答对，题目或重排逻辑有问题');
    }

    testWidgets('答对后不用点按钮，自动进入下一题', (tester) async {
      useTabletView(tester);
      await tester.pumpWidget(MaterialApp(
          home: PatternQuizScreen(ages: {PatternAgeGroup.preschool})));
      await tester.pump();

      expect(find.text('第 1 / ${PatternQuizScreen.sessionSize} 题'),
          findsOneWidget);

      await answerUntilRight(tester);
      // 答对瞬间有鼓励条 + 炫光爆发
      expect(find.textContaining('马上'), findsOneWidget);
      expect(find.byType(SparkleBurst), findsOneWidget);

      // 停留一小会儿后自动翻到下一题
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('第 2 / ${PatternQuizScreen.sessionSize} 题'),
          findsOneWidget);
      expect(find.text('请选择'), findsOneWidget);
    });

    testWidgets('答完全部题目进入结果页，带撒花与星级', (tester) async {
      useTabletView(tester);
      await tester.pumpWidget(MaterialApp(
          home: PatternQuizScreen(ages: {PatternAgeGroup.lowerGrade})));
      await tester.pump();

      for (var i = 0; i < PatternQuizScreen.sessionSize; i++) {
        await answerUntilRight(tester);
        await tester.pump(const Duration(seconds: 2));
      }

      expect(find.text('再玩一局'), findsOneWidget);
      expect(find.byType(ConfettiRain), findsOneWidget);
      // 结果页恒定三颗星：亮起的 + 没亮的一起算
      final stars = find.byIcon(Icons.star_rounded).evaluate().length +
          find.byIcon(Icons.star_outline_rounded).evaluate().length;
      expect(stars, 3);
      expect(tester.takeException(), isNull);
    });

    testWidgets('重新开始会重新抽 10 题', (tester) async {
      useTabletView(tester);
      await tester.pumpWidget(MaterialApp(
          home: PatternQuizScreen(ages: {PatternAgeGroup.upperGrade})));
      await tester.pump();

      await answerUntilRight(tester);
      await tester.pump(const Duration(seconds: 2));
      await tester.tap(find.byIcon(Icons.refresh_rounded));
      await tester.pump();

      expect(find.text('第 1 / ${PatternQuizScreen.sessionSize} 题'),
          findsOneWidget);
    });
  });
}
