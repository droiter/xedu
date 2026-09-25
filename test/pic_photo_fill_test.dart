import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xedu/features/pattern_quiz/pattern_quiz_models.dart';
import 'package:xedu/features/pattern_quiz/pic_view.dart';

/// 照片要「铺满方框」——以前按字形字号给尺寸，只占方框的一半边长（面积的四分之一），
/// 两个答题页的题面图/选项格里照片四周全是空的。这里把边长钉住，防止改回去。
Widget _host(Pic pic, double w, double h) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(width: w, height: h, child: PicView(pic: pic)),
        ),
      ),
    );

/// 画出来的照片位置与大小（SizedBox 给的是紧约束，取 Image 的渲染矩形即可）。
List<Rect> _photoRects(WidgetTester tester) {
  final f = find.byType(Image);
  return [
    for (var i = 0; i < f.evaluate().length; i++) tester.getRect(f.at(i)),
  ];
}

void main() {
  // 方框边长 = min(宽, 高)，用正方形尺寸最直观。
  const box = 200.0;

  testWidgets('单张照片铺满方框', (tester) async {
    await tester.pumpWidget(_host(Pic.emojiSingle('🍎'), box, box));
    final rects = _photoRects(tester);
    expect(rects, hasLength(1));
    // 留一点边距，但不许再退回「半个方框」。
    expect(rects.single.width, greaterThan(box * 0.85));
    expect(rects.single.height, greaterThan(box * 0.85));
    expect(rects.single.width, lessThanOrEqualTo(box));
  });

  testWidgets('大小题的档位按整个方框缩放，最大档铺满', (tester) async {
    await tester.pumpWidget(_host(Pic.emojiSize('🎈', 0), box, box));
    final small = _photoRects(tester).single.width;
    await tester.pumpWidget(_host(Pic.emojiSize('🎈', 3), box, box));
    final big = _photoRects(tester).single.width;

    expect(big, greaterThan(box * 0.85));
    // 最大档 : 最小档 = 1 : 0.5（四档的档差没有被压扁）。
    expect(small / big, closeTo(0.5, 0.02));
  });

  testWidgets('数量题排成网格，每张比并排一行时大', (tester) async {
    await tester.pumpWidget(_host(Pic.emojiCount('🍎', 4), box, box));
    final rects = _photoRects(tester);
    expect(rects, hasLength(4));

    // 2×2：四张一样大，各占方框一半边长（并排一行的话只有四分之一）。
    final side = rects.first.width;
    expect(side, greaterThan(box * 0.4));
    expect(rects.map((r) => r.width), everyElement(closeTo(side, 0.01)));

    final xs = rects.map((r) => r.left.round()).toSet();
    final ys = rects.map((r) => r.top.round()).toSet();
    expect(xs, hasLength(2), reason: '两列');
    expect(ys, hasLength(2), reason: '两行');
  });

  testWidgets('答题页的格子尺寸下也铺满', (tester) async {
    // 找规律的 4 格 / 选项格（手机宽度下）、看图问答的题面图和选项格。
    const cells = [
      Size(83.5, 118), // 找规律 4 格
      Size(83.5, 118), // 找规律选项（和 4 格同高，长短题两边才是同一把尺子）
      Size(70, 92), // 看图问答题面图里的一格
      Size(154, 90), // 看图问答选项
    ];
    for (final c in cells) {
      await tester.pumpWidget(_host(Pic.emojiSingle('🍎'), c.width, c.height));
      final side = _photoRects(tester).single.width;
      final shorter = c.shortestSide;
      expect(side, greaterThan(shorter * 0.85), reason: '$c');
      expect(side, lessThanOrEqualTo(shorter), reason: '$c');
    }
  });

  testWidgets('铅笔长短题：档位只改长短，不改粗细', (tester) async {
    final widths = <double>[];
    final heights = <double>[];
    for (var lvl = 0; lvl <= 4; lvl++) {
      await tester.pumpWidget(_host(Pic.pencil(lvl), box, box));
      final r = tester.getRect(find.byType(CustomPaint).last);
      widths.add(r.width);
      heights.add(r.height);
    }

    for (var i = 1; i < widths.length; i++) {
      expect(widths[i], greaterThan(widths[i - 1]), reason: '第 $i 档');
    }
    expect(widths.last, greaterThan(box * 0.95), reason: '最长那档铺满方框');
    // 最短那档也得留得下笔尖 + 金属箍 + 橡皮（约 0.33box），别画成一条线。
    expect(widths.first, greaterThan(box * 0.36));
    expect(heights.toSet(), hasLength(1), reason: '笔的粗细不随档位变');
  });

  testWidgets('树的高矮题：档位只改高矮，不改粗细', (tester) async {
    final widths = <double>[];
    final heights = <double>[];
    final bottoms = <double>[];
    for (var lvl = 0; lvl <= 4; lvl++) {
      await tester.pumpWidget(_host(Pic.tree(lvl), box, box));
      final r = tester.getRect(find.byType(CustomPaint).last);
      widths.add(r.width);
      heights.add(r.height);
      bottoms.add(r.bottom);
    }

    for (var i = 1; i < heights.length; i++) {
      expect(heights[i], greaterThan(heights[i - 1]), reason: '第 $i 档');
    }
    expect(heights.last, closeTo(box, 0.5), reason: '最高那档顶到方框顶');
    expect(heights.first, greaterThan(box * 0.5), reason: '最矮那档也是棵树');
    expect(widths.toSet(), hasLength(1), reason: '树的粗细不随档位变');
    expect(bottoms.toSet(), hasLength(1), reason: '所有档位站在同一条地平线上');
  });

  testWidgets('楼 / 塔 / 柱子的高矮题：档位只改高矮，底边齐平', (tester) async {
    for (final pic in ['楼', '塔', '柱子']) {
      final maker = switch (pic) {
        '楼' => Pic.house,
        '塔' => Pic.tower,
        _ => Pic.pillar,
      };
      final widths = <double>[];
      final heights = <double>[];
      final bottoms = <double>[];
      for (var lvl = 0; lvl <= 4; lvl++) {
        await tester.pumpWidget(_host(maker(lvl), box, box));
        final r = tester.getRect(find.byType(CustomPaint).last);
        widths.add(r.width);
        heights.add(r.height);
        bottoms.add(r.bottom);
      }
      for (var i = 1; i < heights.length; i++) {
        expect(heights[i], greaterThan(heights[i - 1]), reason: '$pic 第 $i 档');
      }
      expect(heights.last, closeTo(box, 0.5), reason: '$pic 最高那档顶到方框顶');
      expect(heights.first, greaterThan(box * 0.5), reason: '$pic 最矮那档也是座$pic');
      expect(widths.toSet(), hasLength(1), reason: '$pic 的宽度不随档位变');
      expect(bottoms.toSet(), hasLength(1), reason: '$pic 所有档位站在同一条地平线上');
    }
  });

  testWidgets('横着的小棒 / 丝带：档位只改长短，不改粗细', (tester) async {
    for (final entry in {'小棒': Pic.stick, '丝带': Pic.ribbon}.entries) {
      final widths = <double>[];
      final heights = <double>[];
      for (var lvl = 0; lvl <= 4; lvl++) {
        await tester.pumpWidget(_host(entry.value(lvl), box, box));
        final r = tester.getRect(find.byType(CustomPaint).last);
        widths.add(r.width);
        heights.add(r.height);
      }
      for (var i = 1; i < widths.length; i++) {
        expect(widths[i], greaterThan(widths[i - 1]), reason: '${entry.key} 第 $i 档');
      }
      expect(widths.last, greaterThan(box * 0.95), reason: '${entry.key} 最长那档铺满方框');
      expect(widths.first, greaterThan(box * 0.3), reason: '${entry.key} 最短那档也看得出是${entry.key}');
      expect(heights.toSet(), hasLength(1), reason: '${entry.key} 的粗细不随档位变');
    }
  });

  testWidgets('竖着的小棒：档位只改粗细，不改长短', (tester) async {
    final widths = <double>[];
    final heights = <double>[];
    for (var lvl = 0; lvl <= 4; lvl++) {
      await tester.pumpWidget(_host(Pic.rod(lvl), box, box));
      final r = tester.getRect(find.byType(CustomPaint).last);
      widths.add(r.width);
      heights.add(r.height);
    }
    for (var i = 1; i < widths.length; i++) {
      expect(widths[i], greaterThan(widths[i - 1]), reason: '第 $i 档');
    }
    expect(widths.last, greaterThan(box * 0.4), reason: '最粗那档看得出粗细差');
    expect(heights.toSet(), hasLength(1), reason: '小棒的长短不随档位变');
  });

  testWidgets('小狗离树远近题：树是基准不动，小狗越远越小、离树越远', (tester) async {
    // 真实格子：找规律的 4 格（手机/平板）、找规律的选项格、看图问答的选项格。
    for (final cell in const [
      Size(76, 118),
      Size(83.5, 118),
      Size(139, 90),
      Size(181, 162),
    ]) {
      final trees = <Rect>[];
      final dogs = <Rect>[];
      for (var lvl = 0; lvl <= 4; lvl++) {
        await tester.pumpWidget(_host(Pic.dogTree(lvl), cell.width, cell.height));
        trees.add(tester.getRect(find.byType(CustomPaint).last));
        dogs.add(tester.getRect(find.byType(Image)));
      }
      final where = '$cell';

      // 树是基准：五档大小、位置完全一样，否则没法比。
      expect(trees.map((r) => r.width).toSet(), hasLength(1), reason: '$where 树的大小变了');
      expect(trees.map((r) => r.height).toSet(), hasLength(1), reason: '$where 树的大小变了');
      expect(trees.map((r) => r.left).toSet(), hasLength(1), reason: '$where 树挪位置了');

      // 小狗：一档比一档离树远、一档比一档小，两条线索都要单调。
      for (var i = 1; i < dogs.length; i++) {
        expect(dogs[i].left, greaterThan(dogs[i - 1].left),
            reason: '$where 第 $i 档没走得更远');
        expect(dogs[i].width, lessThan(dogs[i - 1].width),
            reason: '$where 第 $i 档没变得更小');
      }
      // 都站在同一条地平线上（尺寸不同，底边会有浮点尾数，所以给点容差）。
      for (final r in dogs) {
        expect(r.bottom, closeTo(dogs.first.bottom, 0.01),
            reason: '$where 小狗没站在地平线上');
      }
      expect(dogs.first.bottom, closeTo(trees.first.bottom, 0.01),
          reason: '$where 小狗和树不在同一条地平线上');

      // 0 档紧挨着树，4 档顶到格子右边。
      expect(dogs.first.left - trees.first.right, lessThan(1.0), reason: '$where 0 档没挨着树');
      expect(cell.width - dogs.last.right, lessThan(1.0), reason: '$where 4 档没到最右边');

      // 远近得看得出来：最远那只明显更小、也明显更靠右。
      expect(dogs.last.width / dogs.first.width, lessThan(0.7),
          reason: '$where 最远那档没小下去');
      expect(dogs.last.left - dogs.first.left, greaterThan(cell.width * 0.15),
          reason: '$where 最远那档没拉开距离');
    }
  });

  testWidgets('没有照片的字形照旧按字形画', (tester) async {
    await tester.pumpWidget(_host(Pic.emojiSingle('➕'), box, box));
    expect(find.byType(Image), findsNothing);
    expect(find.byType(Text), findsOneWidget);
  });
}
