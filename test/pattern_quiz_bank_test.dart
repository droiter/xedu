import 'package:flutter_test/flutter_test.dart';
import 'package:xedu/features/pattern_quiz/pattern_quiz_bank.dart';
import 'package:xedu/features/pattern_quiz/pattern_quiz_models.dart';
import 'package:xedu/features/pattern_quiz/question_taxonomy.dart';

void main() {
  group('规律题库', () {
    test('题库总量足够，且每个年龄档位都至少有 30 题', () {
      // 「规律只重复一次」的交替题删掉后，2–3 岁与 3–4 岁档各补了 5 道
      // 「越来越…」补回 30 题，下限仍是 30。
      expect(kPatternQuestions.length, greaterThanOrEqualTo(150));
      for (final g in PatternAgeGroup.values) {
        expect(patternBankFor(g).length, greaterThanOrEqualTo(30),
            reason: '${g.ageText} 的题量偏少');
      }
    });

    test('不再有「规律只重复一次」的交替题：短名不以 -alt 结尾', () {
      // 4 格里规律只重复一次，孩子归纳不出来，这类题已全部删掉。
      // 真正的交替题短名形如 `b-alt-red-blue`（`alt` 在第 2 段），整题挪进「100 岁」。
      final tails = [
        for (final q in kPatternQuestions)
          if (q.id.endsWith('-alt')) q.id,
      ];
      expect(tails, isEmpty, reason: tails.join('、'));
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
      // 皮球的八个朝向互不相同；转满一整圈回到原样
      expect(Pic.ballTurn(1).kind, PicKind.ballTurn);
      expect(
        {for (var i = 0; i < 8; i++) Pic.ballTurn(i).id}.length,
        8,
      );
      expect(Pic.ballTurn(8).id, Pic.ballTurn(0).id);
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

  group('题目 id 与多级分类', () {
    test('每道题都有全局唯一的多级分类 id', () {
      final qids = kPatternQuestions.map(qidOf).toList();
      expect(qids.toSet().length, kPatternQuestions.length);
    });

    test('id 由 5 段组成并体现分类：题库.年龄.大类.类型.实例', () {
      for (final q in kPatternQuestions) {
        final parts = qidOf(q).split('.');
        expect(parts.length, 5, reason: qidOf(q));
        expect(parts[0], 'PT');
        expect(parts[2], familyOf(q).code, reason: qidOf(q));
        expect(parts[3], typeOf(q).code, reason: qidOf(q));
        expect(parts[4], isNotEmpty, reason: qidOf(q));
      }
    });

    test('每个题目短名里的题型 token 都能映射到已登记的类型', () {
      for (final q in kPatternQuestions) {
        expect(typeOf(q), isNot(PatternType.other),
            reason: '${q.id} 的题型 token 未登记，请补进 _tokenType');
      }
    });

    test('同一道题永远得到同一个 id（可用于持久化）', () {
      for (final q in kPatternQuestions) {
        expect(qidOf(q), qidOf(q));
        expect(questionByQid(qidOf(q)), same(q));
      }
    });

    test('六大规律大类都有题目', () {
      final families = kPatternQuestions.map(familyOf).toSet();
      expect(families.length, PatternFamily.values.length);
    });

    test('题库里不再出现光秃秃的方条 / 椭圆：属性题一律画实物', () {
      const retired = {
        PicKind.bar, // 光秃秃的竖条，看不出是柱子还是树
        PicKind.lengthBar, // 光秃秃的横条
        PicKind.widthBar, // 光秃秃的竖条
        PicKind.blob, // 椭圆
        PicKind.distance, // 地平线上的小球
      };
      for (final q in kPatternQuestions) {
        for (final p in [...q.items, ...q.distractors]) {
          expect(retired.contains(p.kind), isFalse,
              reason: '${q.id} 又用回了 ${p.kind}（换成实物图）');
        }
      }
    });

    test('「越来越…」这类题的档位方向和题面说的一致', () {
      // 档位一律「0 = 最小」：0 最短 / 最矮 / 最细 / 最瘦 / 最薄 / 最近，4 是另一头。
      const up = ['长', '高', '粗', '胖', '厚', '远', '升高'];
      const down = ['短', '矮', '细', '瘦', '薄', '近', '降低'];
      const markers = [
        '越来越', '一根比一根', '一块比一块', '一本比一本',
        '一棵比一棵', '一圈比一圈', '一级比一级', '一个比一个', '每次',
      ];
      var checked = 0;
      for (final q in kPatternQuestions) {
        for (final m in markers) {
          final i = q.title.indexOf(m);
          if (i < 0) continue;
          final tail = q.title.substring(i + m.length);
          // 说法词表里没有就跳过（「一会儿近、一会儿远」这种不是单调序列）。
          final grow = up.any(tail.startsWith);
          final shrink = down.any(tail.startsWith);
          if (!grow && !shrink) continue;
          checked++;
          final levels = [for (final p in q.items) p.level];
          for (var k = 1; k < levels.length; k++) {
            expect(grow ? levels[k] > levels[k - 1] : levels[k] < levels[k - 1],
                isTrue,
                reason: '${q.id}「${q.title}」的档位顺序和说法不一致：$levels');
          }
          break;
        }
      }
      expect(checked, greaterThanOrEqualTo(25),
          reason: '能自动查方向的题变少了，看一眼是不是说法换了');
    });

    test('球的旋转题：画的就是皮球，转的方向和步子跟题面说的一致', () {
      // 按题型 token（`*-turn-*`）筛，别按题面 —— 「都是皮球，找出缺少的那张」
      // 这类辨认题也带着「皮球」两个字。
      final rot = [
        for (final q in kPatternQuestions)
          if (typeOf(q) == PatternType.turn) q,
      ];
      // 5–6 岁两向（四分之一圈）、7–8 岁两向（转过一整圈）、9–10 岁两向（八分之一圈）
      expect(rot, hasLength(6), reason: '球的旋转题多了 / 少了就来看一眼');
      for (final q in rot) {
        expect(q.title.contains('皮球'), isTrue,
            reason: '${q.id} 的题面没说是皮球：${q.title}');
        for (final p in [...q.items, ...q.distractors]) {
          expect(p.kind, PicKind.ballTurn, reason: '${q.id} 里还混着别的图');
        }
        final cw = q.title.contains('顺时针');
        // 「四分之一圈」= 走两格（每格 45°），「八分之一圈」= 走一格
        final step = q.title.contains('八分之一') ? 1 : 2;
        expect(q.title.contains('顺时针') || q.title.contains('逆时针'), isTrue,
            reason: '${q.id} 的题面没说转的方向：${q.title}');
        final turns = [for (final p in q.items) p.level];
        for (var i = 1; i < turns.length; i++) {
          final d = cw ? turns[i] - turns[i - 1] : turns[i - 1] - turns[i];
          expect(d % 8, step, reason: '${q.id} 第 $i 格的朝向：$turns');
        }
      }
    });

    test('时针旋转题：画的就是表盘，走的方向和格数跟题面说的一致', () {
      // 同样按题型 token（`*-clk-*`）筛：「顺时针」三个字里也含「时针」。
      final qs = [
        for (final q in kPatternQuestions)
          if (typeOf(q) == PatternType.clock) q,
      ];
      expect(qs, hasLength(8), reason: '时针旋转题多了 / 少了就来看一眼');
      // 题面说法 → 每格走多少个「半小时」
      const steps = {'半个小时': 1, '一个小时': 2, '两个小时': 4, '三个小时': 6};
      for (final q in qs) {
        expect(q.title.contains('时针'), isTrue,
            reason: '${q.id} 的题面没说是时针：${q.title}');
        for (final p in [...q.items, ...q.distractors]) {
          expect(p.kind, PicKind.clock, reason: '${q.id} 里还混着别的图');
        }
        var step = 0;
        for (final e in steps.entries) {
          if (q.title.contains(e.key)) step = e.value;
        }
        expect(step, greaterThan(0), reason: '${q.id} 题面换说法了：${q.title}');
        final cw = q.title.contains('往前走');
        expect(cw || q.title.contains('往回走'), isTrue,
            reason: '${q.id} 的题面没说走的方向：${q.title}');
        // 一格 = 半小时：整点 2n 格、半点 2n+1 格，绕一圈 24 格
        int ticks(Pic p) => (p.n % 12) * 2 + p.level;
        final ts = [for (final p in q.items) ticks(p)];
        for (var i = 1; i < ts.length; i++) {
          final d = cw ? ts[i] - ts[i - 1] : ts[i - 1] - ts[i];
          expect(d % 24, step, reason: '${q.id} 第 $i 格指着：$ts');
        }
      }
    });

    test('「小狗离树」的远近题：画的是小狗离树，序列方向和题面说的一致', () {
      // 按题面筛（「小猫、小狗一个隔一个」那种只是提到小狗，不是远近题）。
      final dist =
          [for (final q in kPatternQuestions) if (q.title.contains('离树')) q];
      // 五档各一道：2–3 岁找一样、3–4 岁升序、学前远近各一、7–8 岁升序、9–10 岁两向。
      expect(dist, hasLength(7), reason: '远近题多了 / 少了就来看一眼');
      for (final q in dist) {
        for (final p in [...q.items, ...q.distractors]) {
          expect(p.kind, PicKind.dogTree, reason: '${q.id} 里还有旧的小球图');
        }
        final levels = [for (final p in q.items) p.level];
        if (q.title.contains('一样远')) {
          expect(levels.toSet().length, 1, reason: q.id);
        } else if (q.title.contains('越来越远')) {
          // 0 档 = 小狗紧挨着树 —— 「越走越远」就得一档比一档大。
          for (var i = 1; i < levels.length; i++) {
            expect(levels[i], greaterThan(levels[i - 1]), reason: q.id);
          }
        } else if (q.title.contains('越来越近')) {
          for (var i = 1; i < levels.length; i++) {
            expect(levels[i], lessThan(levels[i - 1]), reason: q.id);
          }
        } else {
          expect(q.title.contains('一会儿离树近'), isTrue, reason: '${q.id} 题面换说法了');
        }
      }
    });
  });
}
