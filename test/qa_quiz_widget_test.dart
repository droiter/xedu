import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xedu/features/pattern_quiz/pattern_quiz_models.dart';
import 'package:xedu/features/qa_quiz/qa_age_select_screen.dart';
import 'package:xedu/features/qa_quiz/qa_bank.dart';
import 'package:xedu/features/qa_quiz/qa_models.dart';
import 'package:xedu/features/qa_quiz/qa_quiz_screen.dart';
import 'package:xedu/features/qa_quiz/qa_speech.dart';
import 'package:xedu/state/providers.dart';

/// 全量题库（直接读磁盘，绕开 rootBundle）。
final QaBank _full = QaBank.parse(
  File('assets/data/qa_questions.json').readAsStringSync(),
  File('assets/data/qa_voice.json').readAsStringSync(),
);

QaQuestion _q(String age, String id) => _full.questions.firstWhere(
      (q) => q.id == id && q.age.name == age,
      orElse: () => throw StateError('题库里找不到 $age/$id'),
    );

/// 只装一道题的题库：出题随机，只留一题才能稳定地测某一种版式。
QaBank _single(QaQuestion q) =>
    QaBank(questions: [q], clips: _full.clips);

Future<Widget> _host(Widget child, {required Size size}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [prefsProvider.overrideWithValue(prefs)],
    child: MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: child,
      ),
    ),
  );
}

/// 一种版式一行：手机窄屏最容易溢出，平板顺带一起看。
const Size _phone = Size(360, 640);
const Size _tablet = Size(800, 1280);

void main() {
  /// 覆盖每一种版式：题面图 0 / 1 / 2 / 5 张，选项纯文字 / 纯图 / 图文，
  /// 选项 2 个 / 4 个，朗读题 / 阅读题。
  final layouts = <String, QaQuestion>{
    '单图 + 纯文字选项': _q('baby', 'dog'),
    '五张题面图 + 图文选项': _q('baby', 'one-plus-one-obj'),
    '两张题面图 + 两个选项': _q('baby', 'two-dogs'),
    '无题面图 + 纯图选项': _q('baby', 'tallest-tree'),
    '阅读选图（不朗读）': _q('toddler', 'read-apple'),
    '找不一样的（重复选项）': _q('baby', 'find-diff-fruit'),
    '排队图（前后）': _q('lowerGrade', 'front-animal'),
    '快慢图': _q('preschool', 'fastest-car'),
    '深浅图': _q('preschool', 'deepest-well'),
    '纯文字长选项': _q('upperGrade', 'nine-plus-eight'),
  };

  group('问答页面版式', () {
    for (final entry in layouts.entries) {
      testWidgets('${entry.key}：手机与平板都不溢出', (tester) async {
        final q = entry.value;
        for (final size in [_phone, _tablet]) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(await _host(
            QaQuizScreen(ages: {q.age}, bank: _single(q)),
            size: size,
          ));
          await tester.pump();

          // 溢出会以 FlutterError 形式让测试失败，能跑到这里说明版式站得住。
          expect(find.textContaining('第 1 / 1 题'), findsOneWidget,
              reason: '${entry.key} @ $size');
          expect(find.text(q.prompt, findRichText: true), findsOneWidget,
              reason: '${entry.key} 题面没显示出来');
          expect(find.text(q.qid), findsOneWidget,
              reason: '${entry.key} 没显示结构化题号');

          // 收拾干净，免得语音计时器跨用例串味
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        }
      });
    }
  });

  group('答题流程', () {
    testWidgets('阅读选图不朗读，也不显示重播按钮', (tester) async {
      final q = _q('toddler', 'read-apple');
      expect(q.readPrompt, isFalse);
      await tester.pumpWidget(await _host(
        QaQuizScreen(ages: {q.age}, bank: _single(q)),
        size: _tablet,
      ));
      await tester.pump();

      expect(find.text('读一读题目，选出对应的图片'), findsOneWidget);
      // 题面在，但没有「再读一遍」那个按钮
      expect(find.byTooltip('再读一遍'), findsNothing);
      expect(find.text('语速'), findsNothing);
    });

    testWidgets('朗读题只有重播按钮，语速档位不在这里', (tester) async {
      final q = _q('baby', 'dog');
      expect(q.readPrompt, isTrue);
      await tester.pumpWidget(await _host(
        QaQuizScreen(ages: {q.age}, bank: _single(q)),
        size: _tablet,
      ));
      await tester.pump();

      expect(find.byTooltip('再读一遍'), findsOneWidget);
      // 语速已经挪到「我的 → 偏好设置」，答题页上不该再出现任何一档
      expect(find.text('语速'), findsNothing);
      for (final label in kQaRateLabels) {
        expect(find.text(label), findsNothing, reason: '答题页不该有「$label」档');
      }
    });

    testWidgets('答错标红留在原地，答对后自动进成绩页', (tester) async {
      final q = _q('baby', 'dog');
      await tester.pumpWidget(await _host(
        QaQuizScreen(ages: {q.age}, bank: _single(q)),
        size: _tablet,
      ));
      await tester.pump();

      final wrong = String.fromCharCode(65 + (q.answer == 0 ? 1 : 0));
      await tester.tap(find.text(wrong));
      await tester.pump(const Duration(milliseconds: 300));
      // 还在这道题上，没有跳到成绩页
      expect(find.textContaining('第 1 / 1 题'), findsOneWidget);
      expect(find.text('再玩一局'), findsNothing);

      final right = String.fromCharCode(65 + q.answer);
      await tester.tap(find.text(right));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('马上看成绩'), findsOneWidget);

      // 停留一会儿后进成绩页；因为答错过一次，是 0 分
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('再玩一局'), findsOneWidget);
      expect(find.textContaining('一次答对 0 / 1 题'), findsOneWidget);
    });

    testWidgets('一次答对得满分', (tester) async {
      final q = _q('baby', 'dog');
      await tester.pumpWidget(await _host(
        QaQuizScreen(ages: {q.age}, bank: _single(q)),
        size: _tablet,
      ));
      await tester.pump();

      await tester.tap(find.text(String.fromCharCode(65 + q.answer)));
      await tester.pump(const Duration(seconds: 2));
      expect(find.textContaining('一次答对 1 / 1 题'), findsOneWidget);
    });
  });

  group('年龄选择页', () {
    testWidgets('五个年龄段都在，点开始能进入答题', (tester) async {
      tester.view.physicalSize = _tablet;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(ProviderScope(
        overrides: [prefsProvider.overrideWithValue(prefs)],
        child: MaterialApp(home: const QaAgeSelectScreen()),
      ));
      // 题库是异步加载的，要多泵几帧
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      for (final g in [
        PatternAgeGroup.baby,
        PatternAgeGroup.toddler,
        PatternAgeGroup.preschool,
        PatternAgeGroup.lowerGrade,
        PatternAgeGroup.upperGrade,
      ]) {
        expect(find.text(g.ageText), findsOneWidget);
      }
      expect(find.textContaining('题库 ${_full.forAge(PatternAgeGroup.baby).length} 题'),
          findsOneWidget);

      // 默认勾 3–4 岁，直接开始
      await tester.tap(find.text('开始答题'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('第 1 / ${QaQuizScreen.sessionSize} 题'),
          findsOneWidget);
    });
  });
}
