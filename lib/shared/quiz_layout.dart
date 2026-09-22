import 'package:flutter/widgets.dart';

/// 答题页内容区的基准宽度：手机窄屏按这个宽度排版，也就是原来那版尺寸。
const double kQuizBaseWidth = 560;

/// 基准高度：手机窄屏去掉顶栏后刚好一屏放得下题目和四个选项的高度。
const double kQuizBaseHeight = 620;

/// 最大放大倍数，内容宽度跟着一起封顶（[kQuizBaseWidth] × [kQuizMaxScale]）。
const double kQuizMaxScale = 1.8;

/// 答题页的自适应尺度。
///
/// 原来两个答题页都硬顶 `maxWidth: 620`，在平板上就是窄窄一条居中、两边大片空白，
/// 题目和答案都小。现在按**可用宽高**算一个放大倍数：手机保持 1.0（版式和以前
/// 一模一样），平板这种大屏最多放大 [kQuizMaxScale] 倍，内容宽度跟着一起长。
///
/// 竖向还有富余时（平板竖屏）额外做两件事：图片类的行再放大一点，并且允许图片
/// 格子**按宽度撑高** —— 空间够就别让题面图和选项图只是个居中的小方块。
/// 横屏这种「高度更紧」的情况则一律按高度来，绝不让选项被挤到屏幕外面去。
class QuizLayout {
  const QuizLayout._(
      this.scale, this.pictureScale, this.fillPictures, this.maxWidth);

  factory QuizLayout.of(BoxConstraints c) {
    // 判「竖向有没有富余」一律用**没封顶**的比值：封顶之后宽高可能都等于上限，
    // 那样比出来会变成「不富余」，屏幕更大反而画得更小。
    final wRaw = (c.maxWidth - 32) / kQuizBaseWidth;
    final hRaw = (c.maxHeight - 8) / kQuizBaseHeight;
    final w = _factor(wRaw);
    final h = _factor(hRaw);
    // 哪个方向更挤就听哪个，保证一屏放得下；宽度本身也要留边。
    final limit = kQuizBaseWidth * kQuizMaxScale;
    final scale = w < h ? w : h;
    // 手机（360×640）的基准本来就是「高度刚好用满」，所以要比 [scale] 再多出
    // 1/4 的竖向空间才算富余 —— 图片行加码大概要吃掉两成，留点安全边。
    final roomy = hRaw > scale * 1.25;
    return QuizLayout._(
      scale,
      scale * (roomy ? 1.35 : 1.0),
      roomy,
      c.maxWidth > limit ? limit : c.maxWidth,
    );
  }

  static double _factor(double v) =>
      v < 1.0 ? 1.0 : (v > kQuizMaxScale ? kQuizMaxScale : v);

  /// 普通尺寸（字号、间距、纯文字格子）的放大倍数，最小 1.0。
  final double scale;

  /// 图片类的行（题面图 / 图片选项 / 找规律的四格）的放大倍数。
  final double pictureScale;

  /// 竖向是否还有富余（平板竖屏为真，横屏为假）。
  final bool fillPictures;

  /// 内容区宽度上限。
  final double maxWidth;

  /// 题面图片行的高度。
  ///
  /// 竖屏平板有富余，跟着 [pictureScale] 放大就够了；平板横屏竖向不富余但宽得很，
  /// 定死 104dp 这一行就只剩中间一小撮（排队图整行只占中间三分之一，孩子根本看不清），
  /// 所以按可用高度再给一点余量，图片跟着变大。
  /// 手机（[scale] 还是 1.0）竖向一点富余都没有，加了就得滚动才能看到选项，保持原样。
  double sceneRowHeight(double availableHeight, {double base = 104}) {
    final grown = base * pictureScale;
    if (fillPictures || scale <= 1.0) return grown;
    final share = availableHeight * 0.24;
    return share > grown ? share : grown;
  }

  /// 图片选项格子的高度：宽屏上按格子宽度撑高，图才铺得满；
  /// 竖向不富余时只按 [pictureScale] 放大，保证两行选项都能一屏放下。
  double pictureCellHeight(double cellWidth, {double base = 116}) {
    final grown = base * pictureScale;
    if (!fillPictures) return grown;
    final wanted = cellWidth * 0.62;
    return wanted > grown ? wanted : grown;
  }
}
