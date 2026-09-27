import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/reward_rule.dart';
import 'quiz_reward.dart';

/// 弹出「做题奖惩」的设置框：四个数（X / Y / A / B）加一个计数清零。
///
/// 两个答题页共用同一份配置，改完立刻生效（下一次答错 / 答对就用新值）。
Future<void> showQuizRewardSettings(BuildContext context) => showDialog<void>(
      context: context,
      builder: (_) => const _QuizRewardDialog(),
    );

class _QuizRewardDialog extends ConsumerStatefulWidget {
  const _QuizRewardDialog();

  @override
  ConsumerState<_QuizRewardDialog> createState() => _QuizRewardDialogState();
}

class _QuizRewardDialogState extends ConsumerState<_QuizRewardDialog> {
  late final TextEditingController _x;
  late final TextEditingController _y;
  late final TextEditingController _a;
  late final TextEditingController _b;

  @override
  void initState() {
    super.initState();
    final s = ref.read(quizRewardProvider);
    _x = TextEditingController(text: '${s.firstBlackoutSeconds}');
    _y = TextEditingController(text: '${s.maxBlackoutSeconds}');
    _a = TextEditingController(text: '${s.rewardStepSeconds}');
    _b = TextEditingController(text: '${s.rewardMinSeconds}');
  }

  @override
  void dispose() {
    _x.dispose();
    _y.dispose();
    _a.dispose();
    _b.dispose();
    super.dispose();
  }

  /// 读一个输入框；填了不是数字就退回 [fallback]，越界交给控制器夹。
  int _read(TextEditingController c, int fallback) =>
      int.tryParse(c.text.trim()) ?? fallback;

  Future<void> _save() async {
    final s = ref.read(quizRewardProvider);
    await ref.read(quizRewardProvider.notifier).setConfig(
          firstBlackoutSeconds: _read(_x, s.firstBlackoutSeconds),
          maxBlackoutSeconds: _read(_y, s.maxBlackoutSeconds),
          rewardStepSeconds: _read(_a, s.rewardStepSeconds),
          rewardMinSeconds: _read(_b, s.rewardMinSeconds),
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(quizRewardProvider);
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      scrollable: true,
      icon: Icon(Icons.gavel_rounded, color: scheme.primary),
      title: const Text('做题奖惩'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '累计答错超过 $kPunishAfterWrongs 次后，每次答错都黑屏：'
            '第一次 ${s.firstBlackoutSeconds} 秒，每错一次多 1 秒，'
            '最长 ${s.maxBlackoutSeconds} 秒。',
            style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
          Text(
            '「一次答对」（第一下就选对）奖励看一段「我的视频」：'
            '第一次整片看完，之后每次少 ${s.rewardStepSeconds} 秒，'
            '最少看 ${s.rewardMinSeconds} 秒。',
            style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _numField(_x, '首次黑屏 X（秒）')),
            const SizedBox(width: 10),
            Expanded(child: _numField(_y, '黑屏最长 Y（秒）')),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _numField(_a, '每次少看 A（秒）')),
            const SizedBox(width: 10),
            Expanded(child: _numField(_b, '最少看 B（秒）')),
          ]),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  '已答错 ${s.wrongTotal} 次 · 已奖励 ${s.rewardCount} 次',
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ),
              TextButton(
                onPressed: () =>
                    ref.read(quizRewardProvider.notifier).resetCounters(),
                child: const Text('计数清零'),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _save, child: const Text('保存')),
      ],
    );
  }

  Widget _numField(TextEditingController c, String label) => TextField(
        controller: c,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        maxLength: 3,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        decoration: InputDecoration(
          labelText: label,
          counterText: '',
          isDense: true,
          border: const OutlineInputBorder(),
        ),
      );
}
