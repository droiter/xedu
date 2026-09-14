import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xedu/features/pattern_quiz/exit_gate.dart';
import 'package:xedu/features/pattern_quiz/pattern_quiz_models.dart';
import 'package:xedu/features/pattern_quiz/pattern_quiz_screen.dart';
import 'package:xedu/state/providers.dart';

/// 首页放一个入口按钮，答题页从它 push 上来，这样才能验证「返回」真的回到了首页。
class _Launcher extends StatelessWidget {
  const _Launcher({required this.ages});

  final Set<PatternAgeGroup> ages;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Builder(
          builder: (context) => FilledButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => PatternQuizScreen(ages: ages)),
            ),
            child: const Text('开始'),
          ),
        ),
      ),
    );
  }
}

Future<Widget> _host(Set<PatternAgeGroup> ages) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [prefsProvider.overrideWithValue(prefs)],
    child: MaterialApp(home: _Launcher(ages: ages)),
  );
}

void useTabletView(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// 进入答题页（做完之前一直停在做题界面）。
Future<void> _enterQuiz(WidgetTester tester,
    {PatternAgeGroup age = PatternAgeGroup.preschool}) async {
  useTabletView(tester);
  await tester.pumpWidget(await _host({age}));
  await tester.tap(find.text('开始'));
  await tester.pumpAndSettle();
  expect(find.byType(PatternQuizScreen), findsOneWidget);
}

/// 按系统返回键那样尝试退出（AppBar 返回箭头走的就是这条路）。
Future<void> _pressBack(WidgetTester tester, {bool settle = false}) async {
  await tester.tap(find.byType(BackButton));
  await tester.pump();
  if (settle) {
    await tester.pump(const Duration(milliseconds: 400));
  }
}

/// 从验证框上把题目读出来并算出正确答案。
int _readAnswer(WidgetTester tester) {
  final text = tester
      .widget<Text>(find.byKey(const ValueKey('gate-question')))
      .data!;
  final m = RegExp(r'(\d+)\s*×\s*(\d+)').firstMatch(text)!;
  return int.parse(m.group(1)!) * int.parse(m.group(2)!);
}

Future<void> _submit(WidgetTester tester, String value) async {
  await tester.enterText(find.byType(TextField), value);
  await tester.tap(find.text('确定'));
  await tester.pump();
}

/// 轮流点 A/B/C/D，直到把当前这题答对。用来把一局做完。
Future<void> _answerUntilRight(WidgetTester tester) async {
  const letters = ['A', 'B', 'C', 'D'];
  for (var i = 0; i < 40; i++) {
    if (find.textContaining('马上').evaluate().isNotEmpty) return;
    await tester.tap(find.text(letters[i % letters.length]));
    await tester.pump(const Duration(milliseconds: 700));
  }
  fail('连续 40 次都没答对，题目或重排逻辑有问题');
}

void main() {
  group('做题中返回要过家长验证', () {
    testWidgets('题目没做完时按返回键：弹出乘法验证框，页面没退出去', (tester) async {
      await _enterQuiz(tester);
      await _pressBack(tester, settle: true);

      expect(find.text('家长验证'), findsOneWidget);
      expect(find.byKey(const ValueKey('gate-question')), findsOneWidget);
      expect(find.textContaining('剩余'), findsOneWidget);
      // 人还在答题页
      expect(find.byType(PatternQuizScreen), findsOneWidget);
      expect(find.text('开始'), findsNothing);

      // 收尾：等它自然超时关闭，别留下跑着的计时器
      await tester.pump(const Duration(seconds: 11));
      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('验证框里再按返回键也不放行', (tester) async {
      await _enterQuiz(tester);
      await _pressBack(tester, settle: true);

      await tester.tap(find.byType(BackButton), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('家长验证'), findsOneWidget);
      expect(find.byType(PatternQuizScreen), findsOneWidget);

      await tester.pump(const Duration(seconds: 11));
      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('答对乘法题就能返回', (tester) async {
      await _enterQuiz(tester);
      await _pressBack(tester, settle: true);

      final answer = _readAnswer(tester);
      await _submit(tester, '$answer');
      await tester.pumpAndSettle();

      expect(find.byType(PatternQuizScreen), findsNothing);
      expect(find.text('开始'), findsOneWidget);
    });

    testWidgets('答错乘法题不能返回，只给一句提示', (tester) async {
      await _enterQuiz(tester);
      await _pressBack(tester, settle: true);

      await _submit(tester, '${_readAnswer(tester) + 1}');
      expect(find.text('答案不对'), findsOneWidget); // 框里的红字

      // 闪一下自动关框，回到答题页
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('家长验证'), findsNothing);
      expect(find.byType(PatternQuizScreen), findsOneWidget);
      expect(find.textContaining('先把这一局做完吧'), findsOneWidget);

      await tester.pump(const Duration(seconds: 3)); // 等提示条自己消失
    });

    testWidgets('10 秒内没答出来就不能返回', (tester) async {
      await _enterQuiz(tester);
      await _pressBack(tester, settle: true);

      await tester.pump(const Duration(seconds: 11));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('家长验证'), findsNothing);
      expect(find.byType(PatternQuizScreen), findsOneWidget);
      expect(find.textContaining('超时了'), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('做完到成绩页就不再拦了', (tester) async {
      await _enterQuiz(tester, age: PatternAgeGroup.lowerGrade);

      for (var i = 0; i < PatternQuizScreen.sessionSize; i++) {
        await _answerUntilRight(tester);
        await tester.pump(const Duration(seconds: 2));
      }
      expect(find.text('再玩一局'), findsOneWidget);

      await _pressBack(tester);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('家长验证'), findsNothing);
      expect(find.byType(PatternQuizScreen), findsNothing);
      expect(find.text('开始'), findsOneWidget);
    });
  });

  group('乘法验证框本身', () {
    testWidgets('题目是一位数乘法，答对返回 passed', (tester) async {
      ExitGateResult? got;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Center(
            child: FilledButton(
              onPressed: () async =>
                  got = await showExitGate(context),
              child: const Text('验证'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('验证'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final text = tester
          .widget<Text>(find.byKey(const ValueKey('gate-question')))
          .data!;
      final m = RegExp(r'^(\d+) × (\d+) = \?$').firstMatch(text)!;
      for (final d in [m.group(1)!, m.group(2)!]) {
        expect(int.parse(d), inInclusiveRange(1, 9));
      }

      await _submit(tester, '${_readAnswer(tester)}');
      await tester.pumpAndSettle();
      expect(got, ExitGateResult.passed);
    });

    testWidgets('手机窄屏 + 数字键盘弹起时不溢出', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      // 模拟软键盘占掉下半屏
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);

      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Center(
            child: FilledButton(
              onPressed: () => showExitGate(context),
              child: const Text('验证'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('验证'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const ValueKey('gate-question')), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pump(const Duration(seconds: 11));
      await tester.pump(const Duration(milliseconds: 500));
    });
  });
}
