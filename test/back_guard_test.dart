import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xedu/features/pattern_quiz/pattern_quiz_models.dart';
import 'package:xedu/features/pattern_quiz/pattern_quiz_screen.dart';
import 'package:xedu/features/qa_quiz/qa_bank.dart';
import 'package:xedu/features/qa_quiz/qa_quiz_screen.dart';
import 'package:xedu/state/providers.dart';

/// 合上平板再打开时，系统偶尔会把「唤醒」当成一次返回键发过来（Android 侧返回
/// 回调的老毛病）。两个答题页收到就会自己弹出家长验证框 —— 这两条用例守住
/// 「这种返回不算孩子按的」，同时确认孩子自己按返回照样拦。
///
/// 全量题库直接读磁盘，绕开 rootBundle（见 qa_quiz_widget_test 的说明）。
final QaBank _bank = QaBank.parse(
  File('assets/data/qa_questions.json').readAsStringSync(),
  File('assets/data/qa_voice.json').readAsStringSync(),
);

/// 首页放一个入口，答题页从它 push 上来，这样才能按到返回箭头。
class _Launcher extends StatelessWidget {
  const _Launcher({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Builder(
          builder: (context) => FilledButton(
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => child)),
            child: const Text('开始'),
          ),
        ),
      ),
    );
  }
}

Future<void> _enter(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(ProviderScope(
    overrides: [prefsProvider.overrideWithValue(prefs)],
    child: MaterialApp(home: _Launcher(child: screen)),
  ));
  await tester.tap(find.text('开始'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

/// 按返回键（AppBar 返回箭头走的就是系统返回那条路）。
Future<void> _pressBack(WidgetTester tester) async {
  await tester.tap(find.byType(BackButton));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// 像系统那样发一条生命周期消息：合上平板 / 再打开。
Future<void> _lifecycle(WidgetTester tester, String state) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/lifecycle',
    const StringCodec().encodeMessage(state),
    (ByteData? _) {},
  );
  await tester.pump();
}

/// 合上平板 → 系统补一个返回 → 再打开 → 又补一个返回，这一段里都不该弹验证框；
/// 等回过神来孩子自己按，才照常拦。
Future<void> _expectIgnoresWakeUpBack(WidgetTester tester) async {
  await _lifecycle(tester, 'AppLifecycleState.paused');
  await _pressBack(tester);
  expect(find.text('家长验证'), findsNothing, reason: '后台里收到的返回不该弹验证框');
  expect(find.byType(BackButton), findsOneWidget);

  await _lifecycle(tester, 'AppLifecycleState.resumed');
  await _pressBack(tester);
  expect(find.text('家长验证'), findsNothing, reason: '刚回到前台那一瞬间不算孩子按的');

  // 过了宽限期，孩子自己按的返回照常拦（顺便把这 2 秒的计时器走完）。
  await tester.pump(const Duration(seconds: 3));
  await _pressBack(tester);
  expect(find.text('家长验证'), findsOneWidget);

  // 收尾：等验证框自己超时关掉，别留下跑着的计时器。
  await tester.pump(const Duration(seconds: 11));
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  testWidgets('看图找规律：合上平板再打开不算按了返回键', (tester) async {
    await _enter(
        tester, const PatternQuizScreen(ages: {PatternAgeGroup.preschool}));
    expect(find.byType(PatternQuizScreen), findsOneWidget);

    await _expectIgnoresWakeUpBack(tester);

    // 验证框超时后还留在答题页。
    expect(find.byType(PatternQuizScreen), findsOneWidget);
  });

  testWidgets('看图问答：合上平板再打开不算按了返回键', (tester) async {
    final q = _bank.questions.firstWhere((q) => q.age == PatternAgeGroup.baby);
    await _enter(
      tester,
      QaQuizScreen(ages: const {PatternAgeGroup.baby}, bank: QaBank(
        questions: [q],
        clips: _bank.clips,
      )),
    );
    expect(find.byType(QaQuizScreen), findsOneWidget);

    await _expectIgnoresWakeUpBack(tester);

    expect(find.byType(QaQuizScreen), findsOneWidget);
  });
}
