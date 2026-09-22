import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xedu/features/pattern_quiz/pattern_quiz_models.dart';
import 'package:xedu/features/qa_quiz/qa_bank.dart';
import 'package:xedu/features/qa_quiz/qa_models.dart';
import 'package:xedu/features/qa_quiz/qa_speech.dart';

/// 直接读磁盘上的题库文件，绕开 rootBundle，测试里就能全量校验。
QaBank _load() => QaBank.parse(
      File('assets/data/qa_questions.json').readAsStringSync(),
      File('assets/data/qa_voice.json').readAsStringSync(),
    );

/// 整点用的一到十二的中文写法（题面里不许出现阿拉伯数字）。
const List<String> _cnHours = [
  '一', '二', '三', '四', '五', '六', '七', '八', '九', '十', '十一', '十二',
];

String _cnHour(int hour) => _cnHours[(hour - 1) % 12];

void main() {
  final bank = _load();

  group('问答题库', () {
    test('五个年龄段都有题，每档至少四十道', () {
      expect(bank.questions.length, greaterThanOrEqualTo(200));
      for (final g in [
        PatternAgeGroup.baby,
        PatternAgeGroup.toddler,
        PatternAgeGroup.preschool,
        PatternAgeGroup.lowerGrade,
        PatternAgeGroup.upperGrade,
      ]) {
        expect(bank.forAge(g).length, greaterThanOrEqualTo(40),
            reason: '${g.ageText} 的题量偏少');
      }
    });

    test('每个年龄段里五种题型数量均衡（最多最少差不超过一题）', () {
      for (final g in [
        PatternAgeGroup.baby,
        PatternAgeGroup.toddler,
        PatternAgeGroup.preschool,
        PatternAgeGroup.lowerGrade,
        PatternAgeGroup.upperGrade,
      ]) {
        final counts = [
          for (final k in QaKind.values)
            bank.forAge(g).where((q) => q.kind == k).length,
        ];
        expect(counts.reduce((a, b) => a < b ? a : b), greaterThan(0),
            reason: '${g.ageText} 有题型一道题都没有');
        expect(counts.reduce((a, b) => a > b ? a : b) -
            counts.reduce((a, b) => a < b ? a : b), lessThanOrEqualTo(1),
            reason: '${g.ageText} 的题型分布不均衡：'
                '${[for (var i = 0; i < QaKind.values.length; i++) '${QaKind.values[i].label}=${counts[i]}'].join(' ')}');
      }
    });

    test('五种题型都覆盖到了', () {
      final kinds = {for (final q in bank.questions) q.kind};
      expect(kinds, QaKind.values.toSet());
    });

    test('合并题库按年龄顺序拼接，空选择返回空表', () {
      const two = {PatternAgeGroup.baby, PatternAgeGroup.toddler};
      expect(bank.forAges(two).length,
          bank.forAge(PatternAgeGroup.baby).length +
              bank.forAge(PatternAgeGroup.toddler).length);
      expect(bank.forAges(const {}), isEmpty);
    });

    test('题号唯一，且四段结构一眼能反解', () {
      final qids = [for (final q in bank.questions) q.qid];
      expect(qids.toSet().length, qids.length);
      for (final q in bank.questions) {
        expect(q.qid, startsWith('QA.'));
        expect(q.qid.split('.').length, greaterThanOrEqualTo(4));
        expect(q.qid.endsWith(q.id), isTrue);
      }
    });

    test('选项数不是 2 就是 4，答案下标不越界', () {
      for (final q in bank.questions) {
        expect([2, 4], contains(q.options.length), reason: q.qid);
        expect(q.answer, inInclusiveRange(0, q.options.length - 1),
            reason: q.qid);
        expect(q.stars, inInclusiveRange(1, 3), reason: q.qid);
      }
    });

    test('每个选项都有内容，同一题的选项彼此不重复', () {
      for (final q in bank.questions) {
        final keys = <String>[];
        for (final o in q.options) {
          expect(o.hasText || o.hasPic, isTrue, reason: q.qid);
          keys.add('${o.text}|${o.pic?.id ?? ''}');
        }
        // 「找出不一样的」故意让三个选项一样，其余题型不该有重复选项
        if (q.kind == QaKind.sameDiff && q.sub == 'DIFFPICK') continue;
        expect(keys.toSet().length, keys.length, reason: '${q.qid} 选项重复');
      }
    });

    test('题面不出现阿拉伯数字：语音引擎会把数字念成汉字，高亮就对不上了', () {
      for (final q in bank.questions) {
        expect(RegExp(r'[0-9A-Za-z]').hasMatch(q.prompt), isFalse,
            reason: '${q.qid} 题面含阿拉伯字符：${q.prompt}');
      }
    });

    test('算一算（物品）题的选项图和题面用同一种物品，孩子才能对着数', () {
      const ops = {'➕', '＝', '❓'};
      for (final q in bank.questions.where(
          (q) => q.kind == QaKind.add && q.sub == 'OBJ')) {
        final objects = [
          for (final s in q.scene)
            if (s.kind == PicKind.emojiCount || s.kind == PicKind.emojiSingle)
              if (!ops.contains(s.emoji)) s.emoji,
        ];
        expect(objects, isNotEmpty, reason: '${q.qid} 题面没有物品');
        expect(objects.toSet().length, 1, reason: '${q.qid} 题面物品不统一');
        for (final o in q.options) {
          expect(o.pic?.kind, PicKind.emojiCount, reason: '${q.qid} 选项不是物品图');
          expect(o.pic?.emoji, objects.first, reason: '${q.qid} 选项物品和题面不一致');
          expect(o.pic!.n, greaterThan(0), reason: q.qid);
        }
      }
    });

    test('几种属性图形都能构造出来', () {
      expect(Pic.speed(2).kind, PicKind.speed);
      expect(Pic.depth(3).kind, PicKind.depth);
      expect(Pic.queue(const ['🐼', '🐰']).kind, PicKind.queue);
      expect(Pic.queue(const ['🐼', '🐰']).emojis.length, 2);
      expect(Pic.candle(4).kind, PicKind.candle);
    });

    test('比粗细的题用蜡烛图标：光秃秃的竖条看不出是绳子还是蜡烛', () {
      final thick = [
        for (final q in bank.questions)
          if (q.kind == QaKind.compare && q.sub == 'THICK') q,
      ];
      expect(thick, isNotEmpty);
      for (final q in thick) {
        for (final o in q.options) {
          expect(o.pic?.kind, PicKind.candle, reason: '${q.qid} 选项不是蜡烛图');
        }
      }
    });

    test('快慢题的速度线只画在车上：蜗牛画速度线看不出谁快谁慢', () {
      final speed = [
        for (final q in bank.questions) ...[
          for (final s in q.scene)
            if (s.kind == PicKind.speed) s,
          for (final o in q.options)
            if (o.pic?.kind == PicKind.speed) o.pic!,
        ],
      ];
      expect(speed, isNotEmpty, reason: '快慢题一道都没有了？');
      for (final p in speed) {
        expect(const ['🚗', '🚕', '🚙'], contains(p.emoji),
            reason: '${p.id}：给「${p.emoji}」画速度线，孩子看不出快慢（原来那道蜗牛题就是这么废掉的）');
      }
    });

    test('方位 / 时钟 / 生活常识 / 分类 / 多少 / 早晚这些新题型都在库里', () {
      final subs = {for (final q in bank.questions) q.sub};
      expect(subs, containsAll(['POS', 'CLOCK', 'LIFE', 'ODD', 'MORE', 'DAY']));
    });

    test('方位题：题面说的方位就是答案那张图摆的位置', () {
      for (final q in bank.questions.where((q) => q.sub == 'POS')) {
        if (q.kind == QaKind.describe) {
          // 看图说话：图里小球摆在哪，答案文字就得是哪个方位词。
          expect(q.options[q.answer].text, kPlaceNames[q.scene.single.level],
              reason: q.qid);
        } else {
          // 阅读选图：题面里写的方位词，就是正确选项那张图。
          final want = kPlaceNames.indexWhere((n) => q.prompt.contains(n));
          expect(want, isNonNegative, reason: '${q.qid} 题面里没写方位');
          for (final o in q.options) {
            expect(o.pic?.kind, PicKind.place, reason: '${q.qid} 选项不是方位图');
          }
          expect(q.options[q.answer].pic?.level, want, reason: q.qid);
        }
      }
    });

    test('时钟题：指着的时刻就是答案文字，选项都是表盘', () {
      for (final q in bank.questions.where((q) => q.sub == 'CLOCK')) {
        if (q.kind == QaKind.describe) {
          final c = q.scene.single;
          final half = c.level != 0;
          expect(q.options[q.answer].text,
              '${_cnHour(c.n)}点${half ? '半' : ''}',
              reason: q.qid);
        } else {
          final want = [
            for (var h = 12; h >= 1; h--)
              if (q.prompt.contains('${_cnHour(h)}点')) h,
          ].first;
          for (final o in q.options) {
            expect(o.pic?.kind, PicKind.clock, reason: '${q.qid} 选项不是表盘');
          }
          expect(q.options[q.answer].pic?.n, want, reason: q.qid);
        }
      }
    });

    test('多少题：说「多」的答案数量最大，说「少」的答案数量最小', () {
      for (final q in bank.questions.where((q) => q.sub == 'MORE')) {
        final ns = [for (final o in q.options) o.pic!.n];
        final mine = ns[q.answer];
        for (var i = 0; i < ns.length; i++) {
          if (i == q.answer) continue;
          expect(q.prompt.contains('少') ? mine < ns[i] : mine > ns[i], isTrue,
              reason: '${q.qid} 答案数量不对');
        }
      }
    });
  });

  group('语音时间轴', () {
    test('每道题都有题面音频，有文字的选项才有选项音频', () {
      for (final q in bank.questions) {
        expect(bank.promptClip(q), isNotNull, reason: '${q.qid} 缺题面语音');
        for (var i = 0; i < q.options.length; i++) {
          final want = q.options[i].hasText;
          expect(bank.optionClip(q, i) != null, want,
              reason: '${q.qid} 选项 $i 的语音不该${want ? '缺' : '有'}');
        }
      }
    });

    test('连读顺序：题面 →「答案有」→ 各文字选项 →「你选择哪个」', () {
      final q = bank.questions
          .firstWhere((q) => q.kind == QaKind.describe && q.options.length == 4);
      expect(
          [for (final s in bank.readAlong(q)) s.key],
          [
            q.clipKey,
            kQaAnswerHeadKey,
            for (var i = 0; i < q.options.length; i++) q.optionClipKey(i),
            kQaAnswerTailKey,
          ]);

      // 顺序跟着屏幕格子走：答错重排之后再读，读的还是打乱后的顺序。
      final flipped = [for (var i = q.options.length - 1; i >= 0; i--) i];
      expect(
          [for (final s in bank.readAlong(q, flipped)) s.key],
          [
            q.clipKey,
            kQaAnswerHeadKey,
            for (final i in flipped) q.optionClipKey(i),
            kQaAnswerTailKey,
          ]);
    });

    test('选项全是图的题只读题面（图没得读，答案靠边框辉光提示）', () {
      final pics = [
        for (final q in bank.questions)
          if (!q.options.any((o) => o.hasText)) q,
      ];
      expect(pics, isNotEmpty);
      for (final q in pics) {
        expect(bank.hasSpokenAnswers(q), isFalse, reason: q.qid);
        expect([for (final s in bank.readAlong(q)) s.key], [q.clipKey],
            reason: q.qid);
      }
      // 有文字选项的题就得有「答案有 … 你选择哪个」这一套
      for (final q in bank.questions.where((q) => q.options.any((o) => o.hasText))) {
        expect(bank.hasSpokenAnswers(q), isTrue, reason: q.qid);
        expect(bank.readAlong(q).length, greaterThan(2), reason: q.qid);
      }
    });

    test('「答案有」「你选择哪个」两句共用一份音频', () {
      expect(bank.answerHeadClip, isNotNull);
      expect(bank.answerTailClip, isNotNull);
      expect(bank.answerHeadClip!.spans, isNotEmpty);
    });

    test('时间轴落在题面文字范围内，且随时间单调向前', () {
      for (final q in bank.questions) {
        final clip = bank.promptClip(q);
        if (clip == null) continue;
        expect(clip.spans, isNotEmpty, reason: q.qid);
        var lastEnd = -1;
        var lastTo = -1.0;
        for (final s in clip.spans) {
          expect(s.start, inInclusiveRange(0, q.prompt.length - 1),
              reason: q.qid);
          expect(s.end, inInclusiveRange(s.start + 1, q.prompt.length),
              reason: q.qid);
          expect(s.start, greaterThanOrEqualTo(lastEnd), reason: q.qid);
          expect(s.to, greaterThan(s.from), reason: q.qid);
          expect(s.from, greaterThanOrEqualTo(lastTo), reason: q.qid);
          lastEnd = s.end;
          lastTo = s.to;
        }
        // 读到最后一个字就够本了，末尾静音不该算进有效朗读时长
        expect(clip.voiced, lessThanOrEqualTo(clip.duration + 0.01),
            reason: q.qid);
      }
    });

    test('语音清单里没有多余片段（改了题库没重跑生成脚本会在这里暴露）', () {
      final wanted = <String>{kQaAnswerHeadKey, kQaAnswerTailKey};
      for (final q in bank.questions) {
        wanted.add(q.clipKey);
        for (var i = 0; i < q.options.length; i++) {
          if (q.options[i].hasText) wanted.add(q.optionClipKey(i));
        }
      }
      expect(bank.clips.keys.toSet(), wanted);
    });

    test('语速档位都在播放器允许的区间里', () {
      for (final r in kQaSpeechRates) {
        expect(r, inInclusiveRange(QaSpeech.minRate, QaSpeech.maxRate));
      }
      expect(kQaSpeechRates, contains(1.0));
    });
  });
}
