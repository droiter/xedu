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

/// 只有还不认字的年龄段才给选项配音，和 scripts/gen_qa_voice.py 保持一致。
const _speakOptionAges = {
  PatternAgeGroup.baby,
  PatternAgeGroup.toddler,
  PatternAgeGroup.preschool,
};

void main() {
  final bank = _load();

  group('问答题库', () {
    test('五个年龄段都有题，题量够玩几局', () {
      expect(bank.questions.length, greaterThanOrEqualTo(50));
      for (final g in [
        PatternAgeGroup.baby,
        PatternAgeGroup.toddler,
        PatternAgeGroup.preschool,
        PatternAgeGroup.lowerGrade,
        PatternAgeGroup.upperGrade,
      ]) {
        expect(bank.forAge(g).length, greaterThanOrEqualTo(10),
            reason: '${g.ageText} 的题量偏少');
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

    test('新旧三种属性图形都能构造出来', () {
      expect(Pic.speed(2).kind, PicKind.speed);
      expect(Pic.depth(3).kind, PicKind.depth);
      expect(Pic.queue(const ['🐼', '🐰']).kind, PicKind.queue);
      expect(Pic.queue(const ['🐼', '🐰']).emojis.length, 2);
    });
  });

  group('语音时间轴', () {
    test('朗读题的题面都有音频，选项图文题才有选项音频', () {
      for (final q in bank.questions) {
        if (q.readPrompt) {
          expect(bank.promptClip(q), isNotNull, reason: '${q.qid} 缺题面语音');
        } else {
          expect(bank.promptClip(q), isNull,
              reason: '${q.qid} 是阅读题，不该有题面语音');
        }
        for (var i = 0; i < q.options.length; i++) {
          final clip = bank.optionClip(q, i);
          final expectClip =
              _speakOptionAges.contains(q.age) && q.options[i].hasText;
          expect(clip != null, expectClip,
              reason: '${q.qid} 选项 $i 的语音不该${expectClip ? '缺' : '有'}');
        }
      }
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
      final wanted = <String>{};
      for (final q in bank.questions) {
        if (q.readPrompt) wanted.add(q.clipKey);
        if (_speakOptionAges.contains(q.age)) {
          for (var i = 0; i < q.options.length; i++) {
            if (q.options[i].hasText) wanted.add(q.optionClipKey(i));
          }
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
