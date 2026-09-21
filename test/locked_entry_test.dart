import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xedu/app.dart';
import 'package:xedu/core/constants.dart';
import 'package:xedu/data/models.dart';
import 'package:xedu/features/course/course_detail_screen.dart';
import 'package:xedu/features/home/home_screen.dart';
import 'package:xedu/features/pattern_quiz/pattern_age_select_screen.dart';
import 'package:xedu/shared/widgets/course_card.dart';
import 'package:xedu/shared/widgets/glow_border.dart';
import 'package:xedu/state/catalog.dart';
import 'package:xedu/state/providers.dart';

import 'fixtures.dart';

/// 直接以已登录状态进入主界面。
Future<void> _pumpShell(WidgetTester tester,
    {Size size = const Size(900, 1500)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  SharedPreferences.setMockInitialValues({
    kSeenOnboardingKey: true,
    kSessionKey:
        jsonEncode({'id': 'u1', 'name': '小明', 'email': 'demo@xedu.app'}),
  });
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      prefsProvider.overrideWithValue(prefs),
      catalogProvider.overrideWith(
          (ref) async => CatalogData.fromJson(sampleCatalogJson())),
    ],
    child: const XeduApp(),
  ));
  // 首页有入场动画，统一用显式 pump 推进（别用 pumpAndSettle）。
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

/// IndexedStack 会把没选中的子页也建出来（不用 Offstage），所以「有没有切过去」
/// 不能看元素在不在，得直接读外壳当前的下标。
int? _currentTab(WidgetTester tester) =>
    tester.widget<IndexedStack>(find.byType(IndexedStack).first).index;

/// 某一格选项卡里的光辉（刚切过去的那一下才有）。
Finder _tabGlow(int i) => find.descendant(
      of: find.byKey(ValueKey('tab-$i')),
      matching: find.byType(GlowBorder),
    );

/// 某一格选项卡的图标颜色：当前那格是主色，别的不是。
Color _tabColor(WidgetTester tester, int i) => tester
    .widget<Icon>(find
        .descendant(of: find.byKey(ValueKey('tab-$i')), matching: find.byType(Icon))
        .first)
    .color!;

void main() {
  testWidgets('课程 / 进度选项卡仍然点不进去', (tester) async {
    await _pumpShell(tester);
    expect(find.byType(HomeScreen), findsOneWidget);

    // 底部五个选项卡都在，课程和进度看得见但点不动。
    expect(find.text('看图找规律'), findsWidgets);
    expect(find.text('看视频'), findsWidgets);
    expect(find.text('课程'), findsOneWidget);
    expect(find.text('进度'), findsOneWidget);
    expect(find.text('我的'), findsWidgets);

    // 点置灰的课程卡片不进入课程详情。
    final title = tester.widget<CourseCard>(find.byType(CourseCard).first);
    await tester.tap(find.text(title.course.title).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(CourseDetailScreen), findsNothing);

    // 点「课程」选项卡也不换页，首页还在。
    expect(_currentTab(tester), kQuizTab);
    await tester.tap(find.byIcon(Icons.grid_view_outlined), warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(_currentTab(tester), kQuizTab);
    expect(find.text('搜索想学的课程'), findsOneWidget);
  });

  testWidgets('「看视频」和「我的」选项卡可以进入', (tester) async {
    await _pumpShell(tester);
    expect(_currentTab(tester), kQuizTab);

    await tester.tap(find.byIcon(Icons.ondemand_video_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(_currentTab(tester), kVideoTab);

    await tester.tap(find.byIcon(Icons.person_outline_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(_currentTab(tester), kProfileTab);

    // 「我的」里挂着视频管理的入口。
    expect(find.text('我的视频'), findsOneWidget);
  });

  testWidgets('手机窄屏下五个选项卡排得下（文字不被截断）', (tester) async {
    await _pumpShell(tester, size: const Size(360, 640));

    expect(tester.takeException(), isNull);
    for (final label in ['看图找规律', '看视频', '课程', '进度', '我的']) {
      expect(find.text(label), findsWidgets, reason: '少了「$label」这格');
    }
    // 最长的那个标签（首页入口卡 + 选项卡各一个）都不能被压成省略号。
    for (final e in find.text('看图找规律').evaluate()) {
      final p = e.renderObject! as RenderParagraph;
      expect(p.didExceedMaxLines, isFalse);
    }
  });

  testWidgets('「看图找规律」入口有光辉且可以进入', (tester) async {
    await _pumpShell(tester);

    // 就首页那张入口卡一圈光辉 —— 底部选项卡不再常驻转光（见下一条）。
    expect(find.byType(GlowBorder), findsOneWidget);

    // 首页那张入口卡（底部选项卡那格点了不跳转）。
    // Ink 只负责画渐变、不参与命中测试，真正接手势的是它外面的 InkWell。
    await tester.tap(find.widgetWithText(Ink, '看图找规律'), warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(PatternAgeSelectScreen), findsOneWidget);
  });

  testWidgets('选项卡用高亮表示当前分类，光辉只在切过去时闪一下', (tester) async {
    await _pumpShell(tester);

    // 一上来没有任何一格在转光辉。
    for (var i = 0; i < 6; i++) {
      expect(_tabGlow(i), findsNothing, reason: '第 $i 格不该常驻光辉');
    }

    // 当前（看图找规律）那格是主色，别的格子不是。
    final selectedColor = _tabColor(tester, kQuizTab);
    final otherColor = _tabColor(tester, kVideoTab);
    expect(selectedColor, isNot(otherColor));

    await tester.tap(find.byIcon(Icons.ondemand_video_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // 高亮跟着走到「看视频」；刚进去的那一下这一格亮起光辉。
    expect(_tabColor(tester, kVideoTab), selectedColor);
    expect(_tabColor(tester, kQuizTab), otherColor);
    expect(_tabGlow(kVideoTab), findsOneWidget);

    // 闪完就收，不一直转。
    await tester.pump(const Duration(milliseconds: 1400));
    expect(_tabGlow(kVideoTab), findsNothing);
    expect(_tabColor(tester, kVideoTab), selectedColor);
  });
}
