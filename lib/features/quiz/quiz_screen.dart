import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../state/providers.dart';

/// 随堂测验：逐题作答、即时反馈、结果记入最好成绩。
class QuizScreen extends ConsumerStatefulWidget {
  const QuizScreen({super.key, required this.course, required this.lesson});

  final Course course;
  final Lesson lesson;

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  int _index = 0;
  int? _selected;
  bool _answered = false;
  bool _finished = false;
  int _correct = 0;

  List<QuizQuestion> get _questions => widget.lesson.quiz;

  @override
  Widget build(BuildContext context) {
    if (_finished) return _resultView(context);
    return _questionView(context);
  }

  // ---------- 答题 ----------
  Widget _questionView(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final q = _questions[_index];
    final total = _questions.length;
    final isLast = _index == total - 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('随堂测验'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text('$_index / $total',
                  style: TextStyle(
                      fontSize: 13, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (_index + (_answered ? 1 : 0)) / total,
                  minHeight: 5,
                ),
              ),
              const SizedBox(height: 18),
              Text('第 ${_index + 1} 题',
                  style: TextStyle(
                      fontSize: 13,
                      color: scheme.primary,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(q.stem, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 18),
              Expanded(
                child: ListView.separated(
                  itemCount: q.options.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _optionTile(context, q, i),
                ),
              ),
              if (_answered) ...[
                _explanation(context, q),
                const SizedBox(height: 12),
              ],
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _answered ? () => _next(isLast) : null,
                  child: Text(isLast ? '查看结果' : '下一题'),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _optionTile(BuildContext context, QuizQuestion q, int i) {
    final scheme = Theme.of(context).colorScheme;
    final correct = i == q.answer;
    final isMine = i == _selected;

    Color? bg;
    Color? border;
    IconData? icon;
    if (_answered) {
      if (correct) {
        bg = Colors.green.withOpacity(0.12);
        border = Colors.green;
        icon = Icons.check_circle_rounded;
      } else if (isMine) {
        bg = scheme.errorContainer;
        border = scheme.error;
        icon = Icons.cancel_rounded;
      }
    }

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: _answered
          ? null
          : () => setState(() {
                _selected = i;
                _answered = true;
                if (correct) _correct++;
              }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: bg ?? (Theme.of(context).brightness == Brightness.dark
              ? scheme.surfaceContainerHigh
              : Colors.white),
          border: border != null
              ? Border.all(color: border, width: 1.6)
              : Border.all(color: Colors.transparent),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${String.fromCharCode(65 + i)}. ${q.options[i]}',
                style: TextStyle(fontSize: 15, height: 1.4),
              ),
            ),
            if (icon != null) Icon(icon, color: border ?? scheme.primary, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _explanation(BuildContext context, QuizQuestion q) {
    final scheme = Theme.of(context).colorScheme;
    final isRight = _selected == q.answer;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isRight
            ? Colors.green.withOpacity(0.08)
            : scheme.errorContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isRight ? Icons.thumb_up_alt_rounded : Icons.tips_and_updates_rounded,
            size: 20,
            color: isRight ? Colors.green : scheme.error,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isRight ? (q.explanation ?? '回答正确，太棒了！')
                  : '正确答案：${q.options[q.answer]}。${q.explanation ?? ''}',
              style: const TextStyle(fontSize: 13.5, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }

  void _next(bool isLast) {
    if (isLast) {
      final percent = (_correct * 100 / _questions.length).round();
      ref.read(studyControllerProvider.notifier)
          .recordQuizBest(widget.course.id, widget.lesson.id, percent);
      setState(() => _finished = true);
    } else {
      setState(() {
        _index++;
        _selected = null;
        _answered = false;
      });
    }
  }

  // ---------- 结果 ----------
  Widget _resultView(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final total = _questions.length;
    final percent = (_correct * 100 / total).round();
    final (headline, sub) = switch (percent) {
      >= 90 => ('太棒了！', '知识点掌握得很扎实'),
      >= 60 => ('不错哦', '再巩固一下薄弱点会更好'),
      _ => ('继续加油', '回到讲义再看一遍吧'),
    };

    return Scaffold(
      appBar: AppBar(title: const Text('测验结果')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.primaryContainer,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('$percent',
                            style: TextStyle(
                                fontSize: 44,
                                fontWeight: FontWeight.w800,
                                color: scheme.primary)),
                        Text('分', style: TextStyle(fontSize: 14, color: scheme.primary)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(headline, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(sub, style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant)),
                const SizedBox(height: 8),
                Text('答对 $_correct / $total 题',
                    style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
                const SizedBox(height: 36),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: () => setState(() {
                      _index = 0;
                      _selected = null;
                      _answered = false;
                      _correct = 0;
                      _finished = false;
                    }),
                    child: const Text('重新挑战'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('返回课程'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
