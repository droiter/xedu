import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'qa_speech.dart';

/// 朗读语速四档选择（很慢 / 慢 / 正常 / 快）。
///
/// 答题页上不再放它：孩子在题中间改语速只会分心，改一次由家长在
/// 「我的 → 偏好设置 → 朗读语速」里定好，改完立刻对正在读的那段生效。
class QaRateChips extends ConsumerWidget {
  const QaRateChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final current = ref.watch(qaSpeechRateProvider);

    return Row(
      children: [
        for (final r in kQaSpeechRates) ...[
          Expanded(
            child: _RateChip(
              rate: r,
              on: (r - current).abs() < 0.01,
              scheme: scheme,
              onTap: () => ref.read(qaSpeechRateProvider.notifier).set(r),
            ),
          ),
          if (r != kQaSpeechRates.last) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _RateChip extends StatelessWidget {
  const _RateChip({
    required this.rate,
    required this.on,
    required this.scheme,
    required this.onTap,
  });

  final double rate;
  final bool on;
  final ColorScheme scheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('qa-rate-${rate.toStringAsFixed(1)}'),
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? scheme.primary : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            qaRateLabel(rate),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: on ? scheme.onPrimary : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
