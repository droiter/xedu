import 'package:flutter/material.dart';

import 'qa_models.dart';
import 'qa_speech.dart';

/// 题面 / 选项文字。朗读到哪个字，哪个字就跟着亮起来。
///
/// 时间轴来自预生成语音（见 `scripts/gen_qa_voice.py`），所以高亮和读音是
/// 严格对上的；[clip] 为空或 [highlight] 为假时就是一段普通文字。
class QaKaraokeText extends StatelessWidget {
  const QaKaraokeText({
    super.key,
    required this.text,
    required this.clipKey,
    required this.clip,
    this.highlight = true,
    this.fontSize = 21,
    this.fontWeight = FontWeight.w700,
    this.height = 1.35,
    this.maxLines,
    this.overflow,
  });

  final String text;

  /// 这段文字对应的音频键，用来判断「现在读的是不是这一段」。
  final String clipKey;

  /// 语音与时间轴；null 表示这段不朗读。
  final QaVoiceClip? clip;

  /// 是否做跟读高亮（家长关掉朗读、或这段没有语音时就不高亮）。
  final bool highlight;

  final double fontSize;
  final FontWeight fontWeight;
  final double height;

  /// 选项格子地方小，允许限制行数并省略。
  final int? maxLines;
  final TextOverflow? overflow;

  bool get _active => highlight && clip != null;

  @override
  Widget build(BuildContext context) {
    final speech = QaSpeech.instance;
    if (!_active) return _plain(context);

    return AnimatedBuilder(
      animation: Listenable.merge([speech.speaking, speech.activeSpan]),
      builder: (context, _) {
        // 选项在朗读时，题面不该跟着亮。
        final span =
            speech.speaking.value == clipKey ? speech.activeSpan.value : null;
        return _rich(context, span);
      },
    );
  }

  TextStyle get _style => TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        height: height,
      );

  Widget _plain(BuildContext context) => Text(
        text,
        textAlign: TextAlign.center,
        maxLines: maxLines,
        overflow: overflow,
        style: _style,
      );

  Widget _rich(BuildContext context, QaSpan? active) {
    final scheme = Theme.of(context).colorScheme;
    final spans = clip!.spans;
    final base = _style.copyWith(color: scheme.onSurface);

    // 还没开始读：按普通文字显示（不拆 span），高度不会跳，
    // 外层 `find.text` 之类的也还能按整串找到它。
    if (spans.isEmpty || active == null) return _plain(context);

    final children = <InlineSpan>[];
    var cursor = 0;
    for (final s in spans) {
      final start = s.start.clamp(0, text.length);
      final end = s.end.clamp(start, text.length);
      if (start > cursor) {
        children.add(TextSpan(text: text.substring(cursor, start)));
      }
      final isActive = start == active.start && end == active.end;
      final isDone = s.to <= active.from && !isActive;
      children.add(TextSpan(
        text: text.substring(start, end),
        style: isActive
            ? base.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w900,
                backgroundColor: scheme.primary.withOpacity(0.20),
              )
            : (isDone ? base.copyWith(color: scheme.onSurface.withOpacity(0.45)) : null),
      ));
      cursor = end;
    }
    if (cursor < text.length) {
      children.add(TextSpan(text: text.substring(cursor)));
    }

    return Text.rich(TextSpan(style: base, children: children),
        textAlign: TextAlign.center);
  }
}
