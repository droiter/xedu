import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'quiz_sfx.dart';

/// 「答题中返回」验证的结果。
enum ExitGateResult {
  /// 答对乘法题，允许返回。
  passed,

  /// 答案不对，不能返回。
  wrong,

  /// 限时内没答出来，不能返回。
  timeout;

  bool get isPassed => this == ExitGateResult.passed;

  /// 验证失败后提示给用户的文案。
  String get message => switch (this) {
        ExitGateResult.passed => '验证通过',
        ExitGateResult.wrong => '答案不对，先把这一局做完吧',
        ExitGateResult.timeout => '超时了，先把这一局做完吧',
      };
}

/// 验证题限时。
const Duration kExitGateTimeout = Duration(seconds: 10);

/// 弹出一道一位数乘法的验证框：**答对才返回 true**，答错或超时都留在原页面。
Future<ExitGateResult> showExitGate(BuildContext context) async {
  final result = await showDialog<ExitGateResult>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const ExitGateDialog(),
  );
  return result ?? ExitGateResult.wrong;
}

/// 家长验证框：算式 + 数字键盘输入 + 10 秒倒计时。
class ExitGateDialog extends StatefulWidget {
  const ExitGateDialog({super.key});

  @override
  State<ExitGateDialog> createState() => _ExitGateDialogState();
}

class _ExitGateDialogState extends State<ExitGateDialog>
    with SingleTickerProviderStateMixin {
  final Random _rng = Random();
  final TextEditingController _input = TextEditingController();

  late final int _a = 2 + _rng.nextInt(8); // 2..9
  late final int _b = 2 + _rng.nextInt(8);
  int get _answer => _a * _b;

  late final AnimationController _time = AnimationController(
    vsync: this,
    duration: kExitGateTimeout,
  );

  bool _done = false;
  bool _wrong = false;
  Timer? _closeTimer;

  @override
  void initState() {
    super.initState();
    _time.addStatusListener((s) {
      if (s == AnimationStatus.completed) _finish(ExitGateResult.timeout);
    });
    _time.forward();
  }

  @override
  void dispose() {
    _closeTimer?.cancel();
    _time.dispose();
    _input.dispose();
    super.dispose();
  }

  void _finish(ExitGateResult result) {
    if (_done) return;
    _done = true;
    _time.stop();
    Navigator.of(context).pop(result);
  }

  void _submit() {
    if (_done) return;
    if (int.tryParse(_input.text.trim()) == _answer) {
      QuizSfx.instance.playRight();
      HapticFeedback.mediumImpact();
      _finish(ExitGateResult.passed);
      return;
    }
    QuizSfx.instance.playWrong();
    HapticFeedback.lightImpact();
    // 答出来才算数：闪一下「答案不对」就关框，留在答题页。
    setState(() => _wrong = true);
    _closeTimer?.cancel();
    _closeTimer = Timer(const Duration(milliseconds: 850), () {
      if (!mounted) return;
      _finish(ExitGateResult.wrong);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return PopScope(
      // 验证框里按返回键不算数，只能答对或等超时。
      canPop: false,
      child: AlertDialog(
        // 手机弹起数字键盘时高度紧张，内容可滚动，别溢出。
        scrollable: true,
        icon: Icon(Icons.lock_outline_rounded, color: scheme.primary),
        title: const Text('家长验证'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('题目还没做完，答对下面这道题才能返回',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 14),
            Text(
              '$_a × $_b = ?',
              key: const ValueKey('gate-question'),
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _input,
              autofocus: true,
              enabled: !_done,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              textAlign: TextAlign.center,
              maxLength: 2,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                hintText: '输入得数',
                counterText: '',
                errorText: _wrong ? '答案不对' : null,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 10),
            AnimatedBuilder(
              animation: _time,
              builder: (_, __) {
                final left =
                    (kExitGateTimeout.inMilliseconds * (1 - _time.value) / 1000)
                        .ceil();
                return Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: 1 - _time.value,
                        minHeight: 5,
                        color: left <= 3 ? scheme.error : scheme.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('剩余 $left 秒',
                        style: TextStyle(
                            fontSize: 12, color: scheme.onSurfaceVariant)),
                  ],
                );
              },
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: _done ? null : _submit,
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
