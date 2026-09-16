import 'package:flutter/material.dart';

import 'qa_models.dart';
import 'qa_speech.dart';

/// 题面文字。朗读到哪个字，哪个字就跟着亮起来。
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
  });

  final String text;

  /// 这段文字对应的音频键，用来判断「现在读的是不是这一段」。
  final String clipKey;

  /// 语音与时间轴；null 表示这段不朗读。
  final QaVoiceClip? clip;

  /// 是否做跟读高亮（阅读选图题不朗读，也就不高亮）。
  final bool highlight;

  final double fontSize;

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

  Widget _plain(BuildContext context) => Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          height: 1.35,
        ),
      );

  Widget _rich(BuildContext context, QaSpan? active) {
    final scheme = Theme.of(context).colorScheme;
    final spans = clip!.spans;
    final base = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      height: 1.35,
      color: scheme.onSurface,
    );

    // 还没开始读：先把整句按未读状态显示出来，高度不会跳。
    if (spans.isEmpty || active == null) {
      return Text.rich(TextSpan(text: text, style: base),
          textAlign: TextAlign.center);
    }

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
