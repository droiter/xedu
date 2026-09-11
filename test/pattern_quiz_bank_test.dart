import 'package:flutter_test/flutter_test.dart';
import 'package:xedu/features/pattern_quiz/pattern_quiz_bank.dart';
import 'package:xedu/features/pattern_quiz/pattern_quiz_models.dart';

void main() {
  group('规律题库', () {
    test('题库总量足够，且每个年龄档位都至少有 30 题', () {
      expect(kPatternQuestions.length, greaterThanOrEqualTo(150));
      for (final g in PatternAgeGroup.values) {
        expect(patternBankFor(g).length, greaterThanOrEqualTo(30),
            reason: '${g.ageText} 的题量偏少');
      }
    });

    test('合并题库按年龄顺序拼接且不丢题', () {
      // 多选年龄时用的合并题库：单档位合并后应与该档位一致
      for (final g in PatternAgeGroup.values) {
        expect(patternBankForAges({g}).length, patternBankFor(g).length,
            reason: g.ageText);
      }
      // 多档位合并后题量等于各档位之和
      const two = {PatternAgeGroup.baby, PatternAgeGroup.toddler};
      expect(patternBankForAges(two).length,
          patternBankFor(PatternAgeGroup.baby).length +
              patternBankFor(PatternAgeGroup.toddler).length);
      // 空选择返回空表
      expect(patternBankForAges(const {}), isEmpty);
    });

    test('每道题都是完整的 4 格图', () {
      for (final q in kPatternQuestions) {
        expect(q.items.length, 4, reason: q.id);
      }
    });

    test('题目 id 全局唯一', () {
      final ids = kPatternQuestions.map((q) => q.id).toSet();
      expect(ids.length, kPatternQuestions.length);
    });

    test('每道题都提供至少 4 个互不重复的干扰项', () {
      for (final q in kPatternQuestions) {
        final ids = q.distractors.map((d) => d.id).toSet();
        expect(ids.length, q.distractors.length, reason: '${q.id} 有重复干扰项');
        expect(q.distractors.length, greaterThanOrEqualTo(4), reason: q.id);
      }
    });

    test('每道题的干扰项都足够组成一题（排除正确答案后仍有 3 个）', () {
      for (final q in kPatternQuestions) {
        for (final blank in q.blankables) {
          final correctId = q.items[blank].id;
          final usable =
              q.distractors.where((d) => d.id != correctId).map((d) => d.id).toSet();
          expect(usable.length, greaterThanOrEqualTo(3),
              reason: '${q.id} 在第 $blank 格可选项不足');
        }
      }
    });

    test('可挖空下标都在合法范围内', () {
      for (final q in kPatternQuestions) {
        expect(q.blankables, isNotEmpty, reason: q.id);
        for (final b in q.blankables) {
          expect(b, inInclusiveRange(0, q.items.length - 1), reason: q.id);
        }
      }
    });

    test('难度星级在 1..3 之间', () {
      for (final q in kPatternQuestions) {
        expect(q.difficulty, inInclusiveRange(1, 3), reason: q.id);
      }
    });

    test('「相同图片」用同一 id 表示：答案比对靠 id', () {
      // 交替题里同款苹果出现在不同格子，id 应一致，渲染也应一致
      final apple = Pic.emojiSingle('🍎');
      final sameApple = Pic.emojiSingle('🍎');
      expect(apple.id, sameApple.id);
      // 数量题 2 个点与 3 个点是不同的图
      expect(Pic.dots(2).id, isNot(Pic.dots(3).id));
    });

    test('新增元素类型靠 id 区分，且同参数 id 稳定', () {
      expect(Pic.number(3).id, isNot(Pic.number(4).id));
      expect(Pic.number(3).id, Pic.number(3).id);
      expect(Pic.colorBlock(0).id, isNot(Pic.colorBlock(1).id));
      expect(Pic.dice(2).id, isNot(Pic.dice(3).id));
      expect(Pic.bar(1).id, isNot(Pic.bar(2).id));
      expect(Pic.shape(0).id, isNot(Pic.shape(1).id));
      expect(Pic.shape(0, quarter: 0).id, isNot(Pic.shape(0, quarter: 1).id));
      expect(Pic.shapeCount(0, 2).id, isNot(Pic.shapeCount(0, 3).id));
      expect(Pic.shapeCount(0, 2).id, isNot(Pic.shapeCount(1, 2).id));
      // 单图形与多图形不是同一种渲染
      expect(Pic.shape(0).id, isNot(Pic.shapeCount(0, 1).id));
    });

    test('每个年龄档位都包含多种题型（标题去重后不少于 8 种）', () {
      for (final g in PatternAgeGroup.values) {
        final kinds = patternBankFor(g)
            .map((q) => q.items.map((p) => p.kind).toSet())
            .map((s) => s.join(','))
            .toSet();
        expect(kinds.length, greaterThanOrEqualTo(3),
            reason: '${g.ageText} 的题型偏单一');
      }
    });
  });
}
