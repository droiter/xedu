import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xedu/app.dart';
import 'package:xedu/core/constants.dart';
import 'package:xedu/data/models.dart';
import 'package:xedu/features/home/home_screen.dart';
import 'package:xedu/features/pattern_quiz/pattern_age_select_screen.dart';
import 'package:xedu/features/pattern_quiz/pattern_quiz_screen.dart';
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
  // 统一用显式 pump 推进（别用 pumpAndSettle）。
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

/// IndexedStack 会把没选中的子页也建出来（不用 Offstage），所以「有没有切过去」
/// 不能看元素在不在，得直接读外壳当前的下标。
int? _currentTab(WidgetTester tester) =>
    tester.widget<IndexedStack>(find.byType(IndexedStack).first).index;

/// 某一格选项卡里的光辉 —— 一格都不该有（底部选项卡从来就不转光辉）。
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
  testWidgets('一进 App 就停在「看图找规律」，原来那页首页不再出现', (tester) async {
    await _pumpShell(tester);

    // 首页（问候语 / 搜索栏 / 精选 / 继续学习 / 为你推荐）整个不再建出来。
    expect(find.byType(HomeScreen), findsNothing);
    expect(find.text('搜索想学的课程'), findsNothing);

    // 直接就是「看图找规律」的年龄选择页，「看图找规律」那格是选中状态。
    expect(_currentTab(tester), kQuizTab);
    expect(find.byType(PatternAgeSelectScreen), findsOneWidget);
    expect(find.text('选择宝贝的年龄'), findsOneWidget);
    expect(find.text('开始闯关'), findsOneWidget);
  });

  testWidgets('课程 / 进度选项卡仍然点不进去', (tester) async {
    await _pumpShell(tester);

    // 底部五格都在，课程和进度看得见但点不动；「看视频」那格已经撤掉。
    expect(find.text('看图找规律'), findsWidgets);
    expect(find.text('看图问答'), findsWidgets);
    expect(find.text('看视频'), findsNothing);
    expect(find.text('课程'), findsOneWidget);
    expect(find.text('进度'), findsOneWidget);
    expect(find.text('我的'), findsWidgets);

    // 点「课程」选项卡不换页，还停在年龄选择页。
    expect(_currentTab(tester), kQuizTab);
    await tester.tap(find.byIcon(Icons.grid_view_outlined), warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(_currentTab(tester), kQuizTab);
    expect(find.text('选择宝贝的年龄'), findsOneWidget);
  });

  testWidgets('「看图问答」和「我的」选项卡可以进入', (tester) async {
    await _pumpShell(tester);
    expect(_currentTab(tester), kQuizTab);

    await tester.tap(find.byIcon(Icons.question_answer_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(_currentTab(tester), kQaTab);

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
    for (final label in ['看图找规律', '看图问答', '课程', '进度', '我的']) {
      expect(find.text(label), findsWidgets, reason: '少了「$label」这格');
    }
    // 最长的那个标签不能被压成省略号。
    for (final e in find.text('看图找规律').evaluate()) {
      final p = e.renderObject! as RenderParagraph;
      expect(p.didExceedMaxLines, isFalse);
    }
  });

  testWidgets('停在「看图找规律」这一页就能直接开一局', (tester) async {
    await _pumpShell(tester);

    // 默认那格（看图找规律）是高亮的主色，另一格不是。
    expect(_tabColor(tester, kQuizTab), isNot(_tabColor(tester, kQaTab)));

    // 不用先路过任何首页，年龄选择页上直接就能开始闯关。
    await tester.tap(find.text('开始闯关'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(PatternQuizScreen), findsOneWidget);
  });

  testWidgets('选项卡只靠高亮表示当前分类，一格都不转光辉', (tester) async {
    await _pumpShell(tester);

    // 一上来没有任何一格有光辉。
    for (var i = 0; i < 5; i++) {
      expect(_tabGlow(i), findsNothing, reason: '第 $i 格不该有光辉');
    }

    // 当前（看图找规律）那格是主色，别的格子不是。
    final selectedColor = _tabColor(tester, kQuizTab);
    final otherColor = _tabColor(tester, kQaTab);
    expect(selectedColor, isNot(otherColor));

    await tester.tap(find.byIcon(Icons.question_answer_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // 高亮跟着走到「看图问答」，切过去那一下也不闪光。
    expect(_tabColor(tester, kQaTab), selectedColor);
    expect(_tabColor(tester, kQuizTab), otherColor);
    for (var i = 0; i < 5; i++) {
      expect(_tabGlow(i), findsNothing, reason: '切到第 $i 格时闪光了');
    }

    // 过一会儿也没有「迟到的」光辉。
    await tester.pump(const Duration(milliseconds: 1400));
    for (var i = 0; i < 5; i++) {
      expect(_tabGlow(i), findsNothing, reason: '第 $i 格冒出了光辉');
    }
    expect(_tabColor(tester, kQaTab), selectedColor);
  });
}
