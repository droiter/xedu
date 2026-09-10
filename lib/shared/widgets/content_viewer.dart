import 'package:flutter/material.dart';

import '../../data/models.dart';

/// 把一课的结构化内容块渲染成可读正文。
class ContentViewer extends StatelessWidget {
  const ContentViewer({super.key, required this.blocks});

  final List<ContentBlock> blocks;

  @override
  Widget build(BuildContext context) {
    if (blocks.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final b in blocks) ...[
          if (b.kind == BlockKind.heading)
            _heading(context, b.text ?? '')
          else if (b.kind == BlockKind.tip)
            _tip(context, theme, b.text ?? '')
          else if (b.kind == BlockKind.list)
            _list(context, b.items)
          else
            _paragraph(context, b.text ?? ''),
          const SizedBox(height: 14),
        ],
      ],
    );
  }

  Widget _heading(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: Row(
        children: [
          Container(width: 4, height: 20, decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(2),
          )),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _paragraph(BuildContext context, String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 15.5,
        height: 1.75,
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.9),
      ),
    );
  }

  Widget _tip(BuildContext context, ThemeData theme, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withOpacity(0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_rounded,
              size: 20, color: theme.colorScheme.onSecondaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 14, height: 1.6, color: theme.colorScheme.onSecondaryContainer)),
          ),
        ],
      ),
    );
  }

  Widget _list(BuildContext context, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Icon(Icons.check_circle_rounded,
                      size: 16, color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(item,
                      style: const TextStyle(fontSize: 15, height: 1.6)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// 通用章节标题 + 「查看全部」。
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.actionText, this.onAction});

  final String title;
  final String? actionText;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Text(title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const Spacer(),
          if (actionText != null)
            TextButton(onPressed: onAction, child: Text(actionText!)),
        ],
      ),
    );
  }
}

/// 通用空态占位。
class EmptyHint extends StatelessWidget {
  const EmptyHint({super.key, required this.icon, required this.text, this.detail});

  final IconData icon;
  final String text;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final grey = Theme.of(context).colorScheme.outline;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        children: [
          Icon(icon, size: 56, color: grey.withOpacity(0.7)),
          const SizedBox(height: 14),
          Text(text, style: TextStyle(fontSize: 15, color: grey), textAlign: TextAlign.center),
          if (detail != null) ...[
            const SizedBox(height: 6),
            Text(detail!,
                style: TextStyle(fontSize: 12.5, color: grey.withOpacity(0.8)),
                textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}
