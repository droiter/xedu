import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xedu/app.dart';
import 'package:xedu/core/constants.dart';
import 'package:xedu/state/providers.dart';

Future<Widget> _app({Map<String, Object> seed = const {}}) async {
  SharedPreferences.setMockInitialValues(seed);
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [prefsProvider.overrideWithValue(prefs)],
    child: const XeduApp(),
  );
}

void main() {
  testWidgets('首次启动进入引导页，可跳过并到达登录页', (tester) async {
    await tester.pumpWidget(await _app());

    expect(find.text('手机和平板都能学'), findsOneWidget);
    expect(find.text('跳过'), findsOneWidget);

    await tester.tap(find.text('跳过'));
    await tester.pumpAndSettle();

    expect(find.text('登录'), findsWidgets);
    expect(find.text('还没有账号？立即注册'), findsOneWidget);
  });

  testWidgets('已看过引导页时直接显示登录页', (tester) async {
    await tester.pumpWidget(await _app(seed: {kSeenOnboardingKey: true}));

    expect(find.text('邮箱'), findsOneWidget);
  });

  testWidgets('注册新账号后进入主界面', (tester) async {
    await tester.pumpWidget(await _app(seed: {kSeenOnboardingKey: true}));

    await tester.tap(find.text('还没有账号？立即注册'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), '小明');
    await tester.enterText(find.byType(TextField).at(1), 'demo@xedu.app');
    await tester.enterText(find.byType(TextField).at(2), '1234');

    await tester.tap(find.text('注册并登录'));
    // 底部选项卡的流光一直在转，pumpAndSettle 永远等不到静止。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 底部导航出现代表已进入主界面
    expect(find.text('看图找规律'), findsWidgets); // 选项卡 + 首页入口卡
    expect(find.text('课程'), findsOneWidget);
    expect(find.text('进度'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);
  });
}
