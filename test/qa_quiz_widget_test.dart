import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xedu/core/constants.dart';
import 'package:xedu/features/pattern_quiz/pattern_quiz_models.dart';
import 'package:xedu/features/pattern_quiz/pic_view.dart';
import 'package:xedu/features/qa_quiz/qa_age_select_screen.dart';
import 'package:xedu/features/qa_quiz/qa_bank.dart';
import 'package:xedu/features/qa_quiz/qa_models.dart';
import 'package:xedu/features/qa_quiz/qa_quiz_screen.dart';
import 'package:xedu/features/qa_quiz/qa_speech.dart';
import 'package:xedu/shared/widgets/glow_border.dart';
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

Future<Widget> _host(Widget child,
    {required Size size,
    double bottomInset = 0,
    Map<String, Object> initialPrefs = const {}}) async {
  SharedPreferences.setMockInitialValues(initialPrefs);
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [prefsProvider.overrideWithValue(prefs)],
    child: MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          padding: EdgeInsets.only(bottom: bottomInset),
          viewPadding: EdgeInsets.only(bottom: bottomInset),
        ),
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
    '阅读选图（选项全是图）': _q('toddler', 'read-apple'),
    '找不一样的（重复选项）': _q('baby', 'find-diff-fruit'),
    '排队图（前后）': _q('lowerGrade', 'front-animal'),
    '快慢图': _q('preschool', 'fastest-car'),
    '深浅图': _q('preschool', 'deepest-well'),
    '粗细图（蜡烛）': _q('toddler', 'thickest-candle'),
    '方位图（小球与箱子）': _q('preschool', 'where-ball'),
    '时钟图（整点）': _q('preschool', 'clock-three'),
    '时钟图（半点）': _q('lowerGrade', 'clock-half-ten'),
    '两个图选项（比多少）': _q('baby', 'more-apples'),
    '两个文字选项（早晚）': _q('baby', 'day-or-night'),
    '纯文字长选项': _q('upperGrade', 'nine-plus-eight'),
    '圆点图选项（一样多）': _q('upperGrade', 'find-same-dots'),
    '两个圆点选项（比多少）': _q('preschool', 'fewer-dots'),
    '数星星图选项（六个）': _q('toddler', 'read-four-stars'),
    '算一算（十个星星）': _q('upperGrade', 'five-plus-three-star'),
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

      testWidgets('${entry.key}：手机 + 系统导航条也一屏放得下（答案不被遮挡）',
          (tester) async {
        final q = entry.value;
        tester.view.physicalSize = _phone;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        // 480dp 高减去 48 的系统导航条，是最挤的一档；要滚才看得到答案就算失败。
        await tester.pumpWidget(await _host(
          QaQuizScreen(ages: {q.age}, bank: _single(q)),
          size: _phone,
          bottomInset: 48,
        ));
        await tester.pump();

        final pos = tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position;
        expect(pos.maxScrollExtent, 0,
            reason: '${entry.key}：手机上要滚动才看得到答案');
        final lastLetter = String.fromCharCode(64 + q.options.length);
        expect(tester.getRect(find.text(lastLetter)).bottom,
            lessThan(_phone.height - 48),
            reason: '${entry.key}：最后一个选项压到系统导航条底下了');

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      });
    }
  });

  group('答题流程', () {
    testWidgets('题面读完，四个选项的边框闪一下辉光，闪完就收（选项是图也闪）', (tester) async {
      // 图片选项没得读，这一闪就是「答案在这几个格子里」的全部提示，所以每道题都要闪。
      for (final q in [_q('baby', 'dog'), _q('toddler', 'read-apple')]) {
        await tester.pumpWidget(await _host(
          QaQuizScreen(ages: {q.age}, bank: _single(q)),
          size: _tablet,
        ));
        await tester.pump();

        // 测试环境里没有音频插件（audioplayers 的通道调用永远不返回），
        // 所以这里直接告诉页面「第一节读完了」—— 真机上这一下由题面语音读完触发。
        QaSpeech.instance.completed.value++;
        await tester.pump();

        expect(find.byType(GlowBorder), findsNWidgets(q.options.length),
            reason: '${q.qid} 没有闪辉光');
        // 淡蓝色，跟入口那种暖色流光区分开。
        expect(
            tester.widget<GlowBorder>(find.byType(GlowBorder).first).colors,
            kAnswerGlowColors);

        // 闪一下就走，而且只有 450ms（原来 900ms 的一半）。
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(GlowBorder), findsNWidgets(q.options.length),
            reason: '${q.qid} 的辉光亮得太短，不到半秒就收了');
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(GlowBorder), findsNothing,
            reason: '${q.qid} 的辉光没停下来');

        // 后面还有「答案有」「各个选项」好几节读完，不该再闪。
        QaSpeech.instance.completed.value++;
        await tester.pump();
        expect(find.byType(GlowBorder), findsNothing,
            reason: '${q.qid} 读完一节又闪了一次');

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
    });

    testWidgets('阅读选图也朗读题面，有重播键；选项是图所以没有小喇叭', (tester) async {
      final q = _q('toddler', 'read-apple');
      await tester.pumpWidget(await _host(
        QaQuizScreen(ages: {q.age}, bank: _single(q)),
        size: _tablet,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(_full.promptClip(q), isNotNull, reason: '阅读选图也该有题面语音');
      expect(find.byTooltip('再读一遍'), findsOneWidget);
      expect(find.byTooltip('读一读这个选项'), findsNothing);
      expect(find.text('读一读题目，自己选一选'), findsNothing);
    });

    testWidgets('读到哪个选项，哪个选项的文字才跟着亮', (tester) async {
      final q = _q('baby', 'dog');
      await tester.pumpWidget(await _host(
        QaQuizScreen(ages: {q.age}, bank: _single(q)),
        size: _tablet,
      ));
      await tester.pump();

      // 跟读高亮会把文字拆成一段段富文本；没在读的就是普通文字。
      List<String> richTexts() => tester
          .widgetList<Text>(find.byWidgetPredicate(
              (w) => w is Text && w.textSpan != null))
          .map((t) => t.textSpan!.toPlainText())
          .toList();

      expect(richTexts(), isEmpty, reason: '没在读的时候不该有跟读高亮');

      // 模拟读到第 2 个选项
      QaSpeech.instance.speaking.value = q.optionClipKey(1);
      QaSpeech.instance.activeSpan.value =
          QaSpan(0, q.options[1].text.length, 0.1, 0.5);
      await tester.pump();
      // 只有被读的那个选项亮（读选项时题面不该跟着亮）
      expect(richTexts(), [q.options[1].text]);

      // 读到下一个：高亮跟着换，不会两个一起亮
      QaSpeech.instance.speaking.value = q.optionClipKey(3);
      QaSpeech.instance.activeSpan.value =
          QaSpan(0, q.options[3].text.length, 0.1, 0.5);
      await tester.pump();
      expect(richTexts(), [q.options[3].text]);

      // 收尾：直接清通知器（测试环境里 stop() 会卡在播放器的通道调用上）
      QaSpeech.instance.speaking.value = null;
      QaSpeech.instance.activeSpan.value = null;
      await tester.pump();
      expect(richTexts(), isEmpty);
    });

    testWidgets('家长关掉朗读：不自动读、没有小喇叭，只提示自己读', (tester) async {
      final q = _q('baby', 'dog');
      await tester.pumpWidget(await _host(
        QaQuizScreen(ages: {q.age}, bank: _single(q)),
        size: _tablet,
        initialPrefs: const {kQaReadAloudKey: false},
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('读一读题目，自己选一选'), findsOneWidget);
      expect(find.byTooltip('再读一遍'), findsNothing);
      expect(find.byTooltip('读一读这个选项'), findsNothing);
      expect(QaSpeech.instance.speaking.value, isNull);
      // 没朗读就没有「题面读完」这回事，也就不会闪辉光
      QaSpeech.instance.completed.value++;
      await tester.pump();
      expect(find.byType(GlowBorder), findsNothing, reason: '没朗读就不该闪辉光');

      // 选项照样能点能答
      await tester.tap(find.text(q.options[q.answer].text));
      await tester.pump(const Duration(seconds: 2));
      expect(find.textContaining('一次答对 1 / 1 题'), findsOneWidget);
    });

    testWidgets('朗读题只有重播按钮，语速档位不在这里', (tester) async {
      final q = _q('baby', 'dog');
      await tester.pumpWidget(await _host(
        QaQuizScreen(ages: {q.age}, bank: _single(q)),
        size: _tablet,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byTooltip('再读一遍'), findsOneWidget);
      // 重播键就贴在题面文字右边，同一行
      final promptRect = tester.getRect(find.text(q.prompt, findRichText: true));
      final btnRect = tester.getRect(find.byTooltip('再读一遍'));
      expect(btnRect.left, greaterThanOrEqualTo(promptRect.right - 1),
          reason: '重播键跑到题面左边去了');
      expect((btnRect.center.dy - promptRect.center.dy).abs(), lessThan(8),
          reason: '重播键和题面不在同一行');
      // 语速已经挪到「我的 → 偏好设置」，答题页上不该再出现任何一档
      expect(find.text('语速'), findsNothing);
      for (final label in kQaRateLabels) {
        expect(find.text(label), findsNothing, reason: '答题页不该有「$label」档');
      }
    });

    testWidgets('答错红闪后重排，答错的那个还能再点，答对后自动进成绩页', (tester) async {
      final q = _q('baby', 'dog');
      await tester.pumpWidget(await _host(
        QaQuizScreen(ages: {q.age}, bank: _single(q)),
        size: _tablet,
      ));
      await tester.pump();

      final rightText = q.options[q.answer].text;
      final wrongText =
          q.options.firstWhere((o) => o.text != rightText).text;
      final rightAt = tester.getRect(find.text(rightText)).topLeft;

      await tester.tap(find.text(wrongText));
      await tester.pump(const Duration(milliseconds: 300));
      // 还在这道题上，没有跳到成绩页；红闪期间位置先不动
      expect(find.textContaining('第 1 / 1 题'), findsOneWidget);
      expect(find.text('再玩一局'), findsNothing);
      expect(tester.getRect(find.text(rightText)).topLeft, rightAt,
          reason: '红闪还没结束就重排了');

      // 红闪结束后：答错的选项没被删掉，四个都还在
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text(wrongText), findsOneWidget, reason: '答错的选项被删了');
      expect(find.text(rightText), findsOneWidget);

      // 同一个选项再点一次还是错 —— 说明答错后没有被禁用
      await tester.tap(find.text(wrongText));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.tap(find.text(rightText));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('马上看成绩'), findsOneWidget);

      // 停留一会儿后进成绩页；答错两次，一次答对 0 分
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('再玩一局'), findsOneWidget);
      expect(find.textContaining('一次答对 0 / 1 题'), findsOneWidget);
      expect(find.textContaining('累计答错 2 次'), findsOneWidget);
    });

    testWidgets('答错会把四个选项换个位置', (tester) async {
      final q = _q('baby', 'dog');
      await tester.pumpWidget(await _host(
        QaQuizScreen(ages: {q.age}, bank: _single(q)),
        size: _tablet,
      ));
      await tester.pump();

      final rightText = q.options[q.answer].text;
      final wrongText =
          q.options.firstWhere((o) => o.text != rightText).text;

      // 每次答错都重排一次：正确选项待过的格子不止一个，才叫「重排」。
      final spots = <Offset>{};
      for (var i = 0; i < 8; i++) {
        await tester.tap(find.text(wrongText));
        await tester.pump(const Duration(milliseconds: 700));
        spots.add(tester.getRect(find.text(rightText)).topLeft);
      }
      expect(spots.length, greaterThan(1), reason: '答错后选项没重排');
      expect(find.text(wrongText), findsOneWidget, reason: '答错的选项没了');
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

  group('按设备尺寸自适应', () {
    /// 在 [size] 上渲一道题，量出「题面能占多宽」「题面图多大」。
    Future<(double, double)> probe(
        WidgetTester tester, QaQuestion q, Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(await _host(
        QaQuizScreen(ages: {q.age}, bank: _single(q)),
        size: size,
      ));
      await tester.pump();

      final promptW =
          tester.getRect(find.text(q.prompt, findRichText: true)).width;
      final sceneH = q.scene.isEmpty
          ? 0.0
          : tester.getRect(find.byType(PicView).first).height;

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      return (promptW, sceneH);
    }

    testWidgets('平板：题面铺满宽度、题面图跟着变大', (tester) async {
      final q = _q('baby', 'dog');
      const wide = Size(1200, 1600);
      final phone = await probe(tester, q, _phone);
      final tablet = await probe(tester, q, wide);

      // 原来硬顶 maxWidth: 620，1200 宽的平板上题面只有 ~540 宽、两边空着。
      expect(tablet.$1, greaterThan(wide.width * 0.65),
          reason: '平板上题面还是窄窄一条，两边空着');
      expect(tablet.$1, greaterThan(phone.$1 * 1.6),
          reason: '平板上题面没比手机宽多少');
      expect(tablet.$2, greaterThan(phone.$2 * 1.6),
          reason: '平板上题面图没跟着屏幕变大');
    });

    testWidgets('平板：排队图（前后题）的小动物明显变大', (tester) async {
      final q = _q('lowerGrade', 'front-animal');

      Future<double> animal(WidgetTester tester, Size size) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(await _host(
          QaQuizScreen(ages: {q.age}, bank: _single(q)),
          size: size,
        ));
        await tester.pump();

        // 题面是排队图，第一张照片就是队尾那只；量的是屏幕上真实的方框
        // （外面套了 FittedBox，得用 getRect 才拿得到缩放后的尺寸）。
        final side = tester.getRect(find.byType(Image).first).width;

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        return side;
      }

      final phone = await animal(tester, _phone);
      final tablet = await animal(tester, const Size(1200, 1600));
      expect(phone, greaterThan(45), reason: '手机上排队图的小动物太小了');
      expect(tablet, greaterThan(phone * 1.8), reason: '平板上排队图没变大');

      // 平板横屏竖向紧，题面图那一行原来跟手机一样定死 104，整行缩在中间一小撮；
      // 现在按可用高度撑起来，图片要明显比手机大。
      final wide = await animal(tester, const Size(1280, 800));
      expect(wide, greaterThan(phone * 1.5), reason: '平板横屏上排队图还是缩在中间');
    });

    testWidgets('平板竖屏、平板横屏都能一屏放下四个选项', (tester) async {
      for (final q in [
        _q('baby', 'one-plus-one-obj'),
        _q('lowerGrade', 'front-animal'),
        _q('toddler', 'read-four-stars'),
        _q('upperGrade', 'nine-plus-eight'),
      ]) {
        for (final size in [const Size(800, 1280), const Size(1280, 800)]) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(await _host(
            QaQuizScreen(ages: {q.age}, bank: _single(q)),
            size: size,
          ));
          await tester.pump();

          final pos = tester
              .state<ScrollableState>(find.byType(Scrollable).first)
              .position;
          expect(pos.maxScrollExtent, 0,
              reason: '${q.qid} @ $size：大屏上还要滚动才看得到选项');

          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        }
      }
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
        overrides: [
          prefsProvider.overrideWithValue(prefs),
          // 题库直接喂给页面，不走 rootBundle：清单超过 50KB 后
          // `loadString` 会派给 isolate 解码，widget 测试的假时钟里等不到。
          qaBankProvider.overrideWith((ref) => _full),
        ],
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
        // 卡片上的题量得是该年龄段自己的数，不能几档都写同一个数
        expect(
          find.descendant(
            of: find
                .ancestor(of: find.text(g.ageText), matching: find.byType(Row))
                .last,
            matching: find.text('题库 ${_full.forAge(g).length} 题'),
          ),
          findsOneWidget,
          reason: '${g.ageText} 卡片上的题量不对',
        );
      }
      // 底部合计跟默认勾选（3–4 岁）走
      expect(
          find.textContaining(
              '题库共 ${_full.forAge(PatternAgeGroup.toddler).length} 题'),
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
