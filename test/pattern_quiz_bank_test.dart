import 'package:flutter_test/flutter_test.dart';
import 'package:xedu/features/pattern_quiz/pattern_quiz_bank.dart';
import 'package:xedu/features/pattern_quiz/pattern_quiz_models.dart';

void main() {
  group('规律题库', () {
    test('题库至少 12 道题', () {
      expect(kPatternQuestions.length, greaterThanOrEqualTo(12));
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

    test('「相同图片」用同一 id 表示：答案比对靠 id', () {
      // 交替题里同款苹果出现在不同格子，id 应一致，渲染也应一致
      final apple = Pic.emojiSingle('🍎');
      final sameApple = Pic.emojiSingle('🍎');
      expect(apple.id, sameApple.id);
      // 数量题 2 个点与 3 个点是不同的图
      expect(Pic.dots(2).id, isNot(Pic.dots(3).id));
    });
  });
}
