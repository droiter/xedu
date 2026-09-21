import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xedu/core/constants.dart';
import 'package:xedu/features/profile/profile_screen.dart';
import 'package:xedu/features/qa_quiz/qa_speech.dart';
import 'package:xedu/state/providers.dart';

/// 「我的 → 偏好设置」里的朗读开关：缺省读出来，关掉之后落盘。
Future<ProviderContainer> _host(WidgetTester tester,
    {bool? savedReadAloud}) async {
  SharedPreferences.setMockInitialValues(
    savedReadAloud == null ? {} : {kQaReadAloudKey: savedReadAloud},
  );
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [prefsProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);

  tester.view.physicalSize = const Size(800, 1280);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(home: Scaffold(body: ProfileScreen())),
  ));
  await tester.pump();
  return container;
}

void main() {
  testWidgets('偏好设置里有朗读开关，缺省是开着的', (tester) async {
    final container = await _host(tester);

    expect(find.text('偏好设置'), findsOneWidget);
    expect(find.text('朗读题目和答案'), findsOneWidget);
    expect(container.read(qaReadAloudProvider), isTrue);

    final sw = tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, '朗读题目和答案'),
    );
    expect(sw.value, isTrue);
  });

  testWidgets('关掉之后落盘，下次打开还是关的', (tester) async {
    final container = await _host(tester);

    await tester.tap(find.text('朗读题目和答案'));
    await tester.pump();

    expect(container.read(qaReadAloudProvider), isFalse);
    expect(container.read(prefsProvider).getBool(kQaReadAloudKey), isFalse);

    // 重开一个容器（相当于重启 App）
    final again = ProviderContainer(
      overrides: [prefsProvider.overrideWithValue(container.read(prefsProvider))],
    );
    addTearDown(again.dispose);
    expect(again.read(qaReadAloudProvider), isFalse);
  });

  testWidgets('上次关过的话，进来就是关的', (tester) async {
    final container = await _host(tester, savedReadAloud: false);

    expect(container.read(qaReadAloudProvider), isFalse);
    final sw = tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, '朗读题目和答案'),
    );
    expect(sw.value, isFalse);
  });

  testWidgets('语速那几档还在，跟朗读开关各管各的', (tester) async {
    await _host(tester, savedReadAloud: false);

    expect(find.text('朗读语速'), findsOneWidget);
    for (final label in kQaRateLabels) {
      expect(find.text(label), findsOneWidget, reason: '缺「$label」档');
    }
  });
}
