import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xedu/core/constants.dart';
import 'package:xedu/features/profile/profile_screen.dart';
import 'package:xedu/features/qa_quiz/qa_speech.dart';
import 'package:xedu/state/providers.dart';

Future<ProviderContainer> _host(
  WidgetTester tester, {
  double? savedRate,
  Size size = const Size(800, 1280),
}) async {
  SharedPreferences.setMockInitialValues(
    savedRate == null ? {} : {kQaSpeechRateKey: savedRate},
  );
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [prefsProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);

  tester.view.physicalSize = size;
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
  testWidgets('「我的 → 偏好设置」里有朗读语速，默认正常', (tester) async {
    final container = await _host(tester);

    expect(find.text('偏好设置'), findsOneWidget);
    expect(find.text('朗读语速'), findsOneWidget);
    expect(find.textContaining('当前：正常'), findsOneWidget);
    // 四档都能选
    for (final label in kQaRateLabels) {
      expect(find.text(label), findsOneWidget, reason: '缺「$label」档');
    }
    expect(container.read(qaSpeechRateProvider), 1.0);
  });

  testWidgets('选一档立刻生效并记进本地', (tester) async {
    final container = await _host(tester);

    await tester.ensureVisible(find.text('很慢'));
    await tester.tap(find.text('很慢'));
    await tester.pump();

    expect(container.read(qaSpeechRateProvider), 0.6);
    expect(find.textContaining('当前：很慢'), findsOneWidget);
    final prefs = container.read(prefsProvider);
    expect(prefs.getDouble(kQaSpeechRateKey), 0.6);
  });

  testWidgets('手机窄屏上四档也不挤（溢出让测试失败）', (tester) async {
    await _host(tester, size: const Size(360, 640));

    await tester.ensureVisible(find.text('朗读语速'));
    await tester.pump();

    expect(find.text('朗读语速'), findsOneWidget);
    for (final label in kQaRateLabels) {
      expect(find.text(label), findsOneWidget, reason: '窄屏上缺「$label」档');
    }
  });

  testWidgets('上次选过的档位下次打开还是它', (tester) async {
    final container = await _host(tester, savedRate: 1.3);

    expect(container.read(qaSpeechRateProvider), 1.3);
    expect(find.textContaining('当前：快'), findsOneWidget);
  });
}
