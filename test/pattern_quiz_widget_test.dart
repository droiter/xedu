import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xedu/features/pattern_quiz/celebration.dart';
import 'package:xedu/features/pattern_quiz/pattern_age_select_screen.dart';
import 'package:xedu/features/pattern_quiz/pattern_quiz_bank.dart';
import 'package:xedu/features/pattern_quiz/pattern_quiz_models.dart';
import 'package:xedu/features/pattern_quiz/pattern_quiz_screen.dart';
import 'package:xedu/features/pattern_quiz/pic_view.dart';
import 'package:xedu/state/providers.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

/// 答题页会读写 Riverpod（记录做题统计），所以要套一层 ProviderScope 并注入
/// 内存版 SharedPreferences。
Future<Widget> _quizHost(Widget child) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [prefsProvider.overrideWithValue(prefs)],
    child: MaterialApp(home: child),
  );
}

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
      await tester.pumpWidget(await _quizHost(const PatternAgeSelectScreen()));

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
      await tester.pumpWidget(await _quizHost(const PatternAgeSelectScreen()));

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
      await tester.pumpWidget(await _quizHost(const PatternAgeSelectScreen()));

      await tester.tap(find.text('3–4 岁')); // 取消默认选择
      await tester.pump();

      expect(find.text('还没有选择年龄段'), findsOneWidget);
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('每题都能答题（点第一个选项不抛异常）', (tester) async {
      for (final g in PatternAgeGroup.values) {
        await tester
            .pumpWidget(await _quizHost(PatternQuizScreen(ages: {g})));
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
      await tester.pumpWidget(await _quizHost(
          PatternQuizScreen(ages: {PatternAgeGroup.preschool})));
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
      await tester.pumpWidget(await _quizHost(
          PatternQuizScreen(ages: {PatternAgeGroup.lowerGrade})));
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

    testWidgets('答题时会同时展示题目的多级分类 id', (tester) async {
      useTabletView(tester);
      await tester.pumpWidget(await _quizHost(
          PatternQuizScreen(ages: {PatternAgeGroup.preschool})));
      await tester.pump();

      // 徽标形如「PT.P.ATTR.LEN.asc-1 · 属性·长短」
      expect(find.textContaining('PT.'), findsOneWidget);
    });

    testWidgets('手机 + 系统导航条：题号/id/难度星一行放得下，选项不被遮挡', (tester) async {
      // 360x640 是最挤的一档手机，再压 48 给系统导航条
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      tester.view.padding = const FakeViewPadding(bottom: 48);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);

      for (final g in PatternAgeGroup.values) {
        await tester.pumpWidget(await _quizHost(PatternQuizScreen(ages: {g})));
        await tester.pump();

        final pos = tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position;
        expect(pos.maxScrollExtent, 0, reason: '$g：手机上要滚动才看得到选项');

        // 题号、id 徽标、难度星（亮 + 暗共 3 颗）挤在同一行：纵向中心对齐
        expect(find.textContaining('第 1 / '), findsOneWidget);
        expect(find.textContaining('PT.'), findsOneWidget);
        final stars = find.byIcon(Icons.star_rounded).evaluate().length +
            find.byIcon(Icons.star_outline_rounded).evaluate().length;
        expect(stars, 3);
        final rowCenter = tester.getRect(find.textContaining('第 1 / ')).center.dy;
        for (final f in [
          find.textContaining('PT.'),
          find.byIcon(Icons.star_rounded).first,
        ]) {
          expect((tester.getRect(f).center.dy - rowCenter).abs(), lessThan(4),
              reason: '$g：题号、id、难度星没在同一行');
        }

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
    });

    testWidgets('平板：四格图和选项跟着屏幕放大，而且一屏放得下', (tester) async {
      final ages = {PatternAgeGroup.lowerGrade};

      Future<(double, double, double)> probe(WidgetTester tester, Size size) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
            await _quizHost(PatternQuizScreen(ages: ages)));
        await tester.pump();

        final pos = tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position;
        // 四格里的第一格（题面图）和第一个备选答案
        final slot = tester.getRect(find.byType(PicView).first).height;
        final option = tester.getRect(find.byType(PicView).last).height;

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        return (slot, option, pos.maxScrollExtent);
      }

      final phone = await probe(tester, const Size(360, 640));
      final tablet = await probe(tester, const Size(800, 1280));

      // 手机版式不动：题面四格、选项格都是 118 高（里面还各去掉 1.6 的描边）
      // —— 两行格子一样大，长短 / 厚薄题才有同一把尺子。
      expect(phone.$1, closeTo(118, 4));
      expect(phone.$2, closeTo(118, 4));
      expect(phone.$3, 0, reason: '手机上要滚动才看得到选项');

      expect(tablet.$1, greaterThan(phone.$1 * 1.5), reason: '平板上四格图没变大');
      expect(tablet.$2, greaterThan(phone.$2 * 1.5), reason: '平板上选项没变大');
      expect(tablet.$3, 0, reason: '平板上还要滚动才看得到选项');
    });

    testWidgets('规律提示先隐藏，答错一次后才出现', (tester) async {
      useTabletView(tester);
      await tester.pumpWidget(await _quizHost(
          PatternQuizScreen(ages: {PatternAgeGroup.preschool})));
      await tester.pump();

      // 刚进题时提示不可见
      expect(find.byIcon(Icons.lightbulb_outline_rounded), findsNothing);

      // 依次点 A/B/C/D 逼出一次答错（答对的题自动跳到下一题后继续）
      var sawWrong = false;
      const letters = ['A', 'B', 'C', 'D'];
      for (var i = 0; i < 40 && !sawWrong; i++) {
        await tester.tap(find.text(letters[i % letters.length]));
        await tester.pump(const Duration(milliseconds: 300));
        sawWrong =
            find.byIcon(Icons.lightbulb_outline_rounded).evaluate().isNotEmpty;
        if (!sawWrong && find.textContaining('马上').evaluate().isNotEmpty) {
          // 这题一次答对：进入下一题后提示应重新隐藏
          await tester.pump(const Duration(seconds: 2));
          expect(find.byIcon(Icons.lightbulb_outline_rounded), findsNothing);
        }
      }
      expect(sawWrong, isTrue, reason: '连续 40 次都没答错，测不出提示逻辑');

      // 答错后提示亮出，且答对前不会收起
      expect(find.byIcon(Icons.lightbulb_outline_rounded), findsOneWidget);

      // 冲掉答错后的重排计时器
      await tester.pump(const Duration(milliseconds: 800));
    });

    testWidgets('题号旁的复制图标把 id 拷进剪贴板', (tester) async {
      useTabletView(tester);
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));

      await tester.pumpWidget(await _quizHost(
          PatternQuizScreen(ages: {PatternAgeGroup.preschool})));
      await tester.pump();

      expect(find.byTooltip('复制题号'), findsOneWidget);
      await tester.tap(find.byTooltip('复制题号'));
      await tester.pump();

      expect(copied, isNotEmpty);
      expect(copied.last, startsWith('PT.'));

      // 冲掉复制提示条与退出动画
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('重新开始会重新抽 10 题', (tester) async {
      useTabletView(tester);
      await tester.pumpWidget(await _quizHost(
          PatternQuizScreen(ages: {PatternAgeGroup.upperGrade})));
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
