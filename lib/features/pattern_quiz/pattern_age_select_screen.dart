import 'package:flutter/material.dart';

import 'pattern_quiz_bank.dart';
import 'pattern_quiz_models.dart';
import 'pattern_quiz_screen.dart';

/// 「看图找规律」的年龄选择页。
///
/// 支持**多选**：可同时勾选多个年龄段，进入后从合并题库里出题，
/// 题量更大、难度梯度也更连续。默认勾选 3–4 岁。
class PatternAgeSelectScreen extends StatefulWidget {
  const PatternAgeSelectScreen({super.key});

  @override
  State<PatternAgeSelectScreen> createState() => _PatternAgeSelectScreenState();
}

class _PatternAgeSelectScreenState extends State<PatternAgeSelectScreen> {
  static const Map<PatternAgeGroup, Color> _accents = {
    PatternAgeGroup.baby: Color(0xFFEC407A),
    PatternAgeGroup.toddler: Color(0xFFF59E0B),
    PatternAgeGroup.preschool: Color(0xFF22B573),
    PatternAgeGroup.lowerGrade: Color(0xFF3D7BFF),
    PatternAgeGroup.upperGrade: Color(0xFF8E24AA),
  };

  final Set<PatternAgeGroup> _selected = {PatternAgeGroup.toddler};

  int get _total => patternBankForAges(_selected).length;

  void _toggle(PatternAgeGroup g) {
    setState(() {
      if (!_selected.remove(g)) _selected.add(g);
    });
  }

  void _start() {
    if (_selected.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PatternQuizScreen(ages: Set.of(_selected)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('看图找规律')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
              children: [
                const Text('选择宝贝的年龄',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('可以多选，选中的年龄段会一起出题；选得越多题目越丰富',
                    style: TextStyle(
                        fontSize: 13, color: scheme.onSurfaceVariant)),
                const SizedBox(height: 18),
                for (final g in PatternAgeGroup.values) ...[
                  _ageCard(context, g),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _startBar(context),
    );
  }

  Widget _ageCard(BuildContext context, PatternAgeGroup g) {
    final accent = _accents[g]!;
    final bank = patternBankFor(g);
    final maxStar = bank.isEmpty
        ? 1
        : bank.map((q) => q.difficulty).reduce((a, b) => a > b ? a : b);
    final on = _selected.contains(g);

    return Material(
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(18),
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _toggle(g),
        child: Ink(
          decoration: BoxDecoration(
            color: on ? accent.withOpacity(0.16) : accent.withOpacity(0.06),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: on ? accent : accent.withOpacity(0.25),
              width: on ? 2.0 : 1.2,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(on ? 0.24 : 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(g.emoji, style: const TextStyle(fontSize: 26)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(g.ageText,
                              style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: accent)),
                          const SizedBox(width: 8),
                          Text(g.stageName,
                              style: TextStyle(
                                  fontSize: 12.5,
                                  color: accent.withOpacity(0.9))),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(g.blurb,
                          style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text('题库 ${bank.length} 题',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: accent.withOpacity(0.9),
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(width: 10),
                          for (var i = 0; i < maxStar; i++)
                            Icon(Icons.star_rounded,
                                size: 15, color: accent.withOpacity(0.85)),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  on
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: on ? accent : accent.withOpacity(0.45),
                  size: 26,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _startBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final n = _selected.length;
    final canStart = n > 0;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
        ),
        // heightFactor 让底栏按内容高度收缩，否则 Center 会撑满整个屏幕高度。
        child: Align(
          alignment: Alignment.center,
          heightFactor: 1.0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(n == 0 ? '还没有选择年龄段' : '已选 $n 个年龄段',
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                          canStart
                              ? '每局随机 ${PatternQuizScreen.sessionSize} 题 · 题库共 $_total 题'
                              : '请至少选择一个年龄段',
                          style: TextStyle(
                              fontSize: 12.5, color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: canStart ? _start : null,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('开始闯关'),
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
