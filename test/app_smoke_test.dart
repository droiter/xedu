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

/// 「我的」那张列表比默认测试窗口高，竖着拉长一点，省得列表项还没建出来。
void _tallWindow(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// 首页有入场动画、入口卡还有常驻的流光，pumpAndSettle 等不到静止，只能显式推帧。
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

/// 外壳当前停在哪一格（IndexedStack 会把没选中的子页也建出来，不能靠「在不在」判）。
int _tab(WidgetTester tester) =>
    tester.widget<IndexedStack>(find.byType(IndexedStack).first).index!;

/// 点某一格选项卡。按图标点会跟页面里的同名图标撞车，所以按格子的 key 点。
Future<void> _openTab(WidgetTester tester, int index) async {
  await tester.tap(find.byKey(ValueKey('tab-$index')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// 等一次页面推入 / 退回的转场走完。
Future<void> _route(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  testWidgets('首次启动进引导页，跳过之后直接进主界面（不用登录）', (tester) async {
    await tester.pumpWidget(await _app());

    expect(find.text('手机和平板都能学'), findsOneWidget);
    expect(find.text('跳过'), findsOneWidget);

    await tester.tap(find.text('跳过'));
    await _settle(tester);

    // 底部导航出现就代表进了主界面，中间不再拦一道登录页。
    expect(find.text('看图找规律'), findsWidgets);
    expect(find.text('我的'), findsWidgets);
    expect(find.text('还没有账号？立即注册'), findsNothing);
    expect(find.text('邮箱'), findsNothing);
  });

  testWidgets('已看过引导页时直接进主界面，底部没有「看视频」', (tester) async {
    await tester.pumpWidget(await _app(seed: {kSeenOnboardingKey: true}));
    await _settle(tester);

    for (final label in ['看图找规律', '看图问答', '课程', '进度', '我的']) {
      expect(find.text(label), findsWidgets, reason: '少了「$label」这格');
    }
    expect(find.text('看视频'), findsNothing);
    expect(find.byIcon(Icons.ondemand_video_rounded), findsNothing);
  });

  testWidgets('没登录时「我的」上是未登录卡片，按叉能退出登录页', (tester) async {
    _tallWindow(tester);
    await tester.pumpWidget(await _app(seed: {kSeenOnboardingKey: true}));
    await _settle(tester);

    await _openTab(tester, kProfileTab);
    expect(find.text('未登录'), findsOneWidget);
    // 没登录时不显示退出登录。
    expect(find.text('退出登录'), findsNothing);

    await tester.tap(find.text('未登录'));
    await _route(tester);
    expect(find.text('还没有账号？立即注册'), findsOneWidget);

    // 不注册也能退回去接着用。
    await tester.tap(find.byIcon(Icons.close_rounded));
    await _route(tester);
    expect(find.text('还没有账号？立即注册'), findsNothing);
    expect(find.text('未登录'), findsOneWidget);
  });

  testWidgets('没登录也能做题；注册完回到「我的」，账号卡片替掉未登录卡片', (tester) async {
    _tallWindow(tester);
    await tester.pumpWidget(await _app(seed: {kSeenOnboardingKey: true}));
    await _settle(tester);

    await _openTab(tester, kProfileTab);
    await tester.tap(find.text('未登录'));
    await _route(tester);
    await tester.tap(find.text('还没有账号？立即注册'));
    await tester.pump();

    await tester.enterText(find.byType(TextField).at(0), '小明');
    await tester.enterText(find.byType(TextField).at(1), 'demo@xedu.app');
    await tester.enterText(find.byType(TextField).at(2), '1234');
    await tester.tap(find.text('注册并登录'));
    await _route(tester);

    // 登录页自己退回「我的」，上面换成账号卡片。
    expect(find.byType(TextField), findsNothing, reason: '登录页已经退掉了');
    expect(find.text('未登录'), findsNothing);
    expect(find.text('小明'), findsOneWidget);
    expect(find.text('demo@xedu.app'), findsOneWidget);
    expect(find.text('退出登录'), findsOneWidget);
  });
}
