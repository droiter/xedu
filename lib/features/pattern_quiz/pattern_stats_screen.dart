import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'pattern_stats.dart';
import 'question_taxonomy.dart';

/// 「看图找规律」学习统计：按账号汇总做题记录，并做多维度分析。
///
/// - 顶部是总览（作答数 / 一次答对率 / 答错次数）；
/// - 可切换 **年龄段 / 规律大类 / 具体类型 / 难度** 四个维度分别查看；
/// - 下面还有「年龄段 × 规律大类」交叉表与「最容易做错的题」榜单。
class PatternStatsScreen extends ConsumerStatefulWidget {
  const PatternStatsScreen({super.key});

  @override
  ConsumerState<PatternStatsScreen> createState() => _PatternStatsScreenState();
}

class _PatternStatsScreenState extends ConsumerState<PatternStatsScreen> {
  StatDimension _dim = StatDimension.family;

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(patternStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('找规律 · 学习统计'),
        actions: [
          if (stats.totalAttempts > 0)
            IconButton(
              tooltip: '清空记录',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () => _confirmClear(context),
            ),
        ],
      ),
      body: SafeArea(
        child: stats.totalAttempts == 0
            ? _emptyView(context)
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
                    children: [
                      _summaryCard(context, stats),
                      const SizedBox(height: 20),
                      _sectionTitle(context, '分维度统计'),
                      const SizedBox(height: 8),
                      _dimensionChips(),
                      const SizedBox(height: 12),
                      _bucketList(context, stats),
                      const SizedBox(height: 24),
                      _sectionTitle(context, '年龄段 × 规律大类'),
                      const SizedBox(height: 8),
                      _crossTable(context, stats),
                      const SizedBox(height: 24),
                      _sectionTitle(context, '最容易做错的题'),
                      const SizedBox(height: 8),
                      _hardestList(context, stats),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  // ---------- 空状态 ----------
  Widget _emptyView(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insights_rounded, size: 56, color: scheme.outline),
            const SizedBox(height: 14),
            Text('还没有做题记录',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            Text('闯关几局后，这里会按题型统计哪些题最容易做错',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, color: scheme.outline)),
          ],
        ),
      ),
    );
  }

  // ---------- 总览 ----------
  Widget _summaryCard(BuildContext context, PatternStats stats) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.emoji_events_rounded,
                  size: 20, color: scheme.onPrimaryContainer),
              const SizedBox(width: 6),
              Text('总览',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: scheme.onPrimaryContainer)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _metric(context, '${stats.totalAttempts}', '累计作答', '题'),
              _metric(context, _pct(stats.accuracy), '一次答对率', ''),
              _metric(context, '${stats.totalWrongPicks}', '累计答错', '次'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metric(BuildContext context, String value, String label, String unit) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        children: [
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                    text: value,
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: scheme.onPrimaryContainer)),
                if (unit.isNotEmpty)
                  TextSpan(
                      text: ' $unit',
                      style: TextStyle(
                          fontSize: 12, color: scheme.onPrimaryContainer)),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 12, color: scheme.onPrimaryContainer.withOpacity(0.8))),
        ],
      ),
    );
  }

  // ---------- 维度切换 ----------
  Widget _dimensionChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final d in StatDimension.values)
          ChoiceChip(
            label: Text(d.label),
            selected: _dim == d,
            onSelected: (_) => setState(() => _dim = d),
          ),
      ],
    );
  }

  Widget _bucketList(BuildContext context, PatternStats stats) {
    final buckets = bucketsBy(stats, _dim);
    if (buckets.isEmpty) {
      return _hint(context, '这一维度还没有数据');
    }
    return Column(
      children: [
        for (final b in buckets) ...[
          _BucketRow(bucket: b),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  // ---------- 交叉表 ----------
  Widget _crossTable(BuildContext context, PatternStats stats) {
    final rows = crossByAgeFamily(stats);
    if (rows.isEmpty) return _hint(context, '还没有交叉数据');

    final scheme = Theme.of(context).colorScheme;
    const families = PatternFamily.values;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const FixedColumnWidth(66),
        border: TableBorder.all(
          color: scheme.outlineVariant.withOpacity(0.5),
          width: 1,
        ),
        children: [
          TableRow(
            decoration: BoxDecoration(color: scheme.surfaceContainerHigh),
            children: [
              _cellText('年龄段', header: true, align: TextAlign.left),
              for (final f in families) _cellText(f.label, header: true),
            ],
          ),
          for (final row in rows)
            TableRow(
              children: [
                _cellText(row.label, align: TextAlign.left),
                for (final f in families)
                  _crossCell(context, row.cells[f.code]),
              ],
            ),
        ],
      ),
    );
  }

  Widget _crossCell(BuildContext context, StatBucket? b) {
    if (b == null || b.attempts == 0) return _cellText('–', muted: true);
    return Container(
      height: 40,
      alignment: Alignment.center,
      color: _accuracyColor(context, b.accuracy).withOpacity(0.14),
      child: Text(_pct(b.accuracy),
          style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: _accuracyColor(context, b.accuracy))),
    );
  }

  Widget _cellText(String text,
      {bool header = false, bool muted = false, TextAlign align = TextAlign.center}) {
    return Container(
      height: 40,
      alignment:
          align == TextAlign.left ? Alignment.centerLeft : Alignment.center,
      padding: align == TextAlign.left
          ? const EdgeInsets.only(left: 8)
          : EdgeInsets.zero,
      child: Text(text,
          style: TextStyle(
              fontSize: header ? 12 : 12.5,
              fontWeight: header ? FontWeight.w800 : FontWeight.w600,
              color: muted ? Colors.grey : null)),
    );
  }

  // ---------- 易错题 ----------
  Widget _hardestList(BuildContext context, PatternStats stats) {
    final hard = hardestQuestions(stats);
    if (hard.isEmpty) {
      return _hint(context, '暂时没有答错过的题，继续保持！');
    }
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (final e in hard) ...[
          Builder(builder: (context) {
            final q = questionByQid(e.key);
            if (q == null) return const SizedBox.shrink();
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(q.title,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700)),
                      ),
                      Text('错 ${e.value.missedAttempts} / ${e.value.attempts}',
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: _accuracyColor(context, e.value.accuracy))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(e.key,
                      style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 2),
                  Text(categoryPathOf(q),
                      style: TextStyle(fontSize: 11.5, color: scheme.outline)),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  // ---------- 小组件 ----------
  Widget _sectionTitle(BuildContext context, String text) => Text(text,
      style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800));

  Widget _hint(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(text,
            style: TextStyle(
                fontSize: 13, color: Theme.of(context).colorScheme.outline)),
      );

  Color _accuracyColor(BuildContext context, double acc) {
    if (acc >= 0.8) return const Color(0xFF22B573);
    if (acc >= 0.5) return const Color(0xFFF59E0B);
    return Theme.of(context).colorScheme.error;
  }

  String _pct(double v) => '${(v * 100).round()}%';

  Future<void> _confirmClear(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空做题记录'),
        content: const Text('将删除这个账号的全部找规律做题与错题统计，无法恢复。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('清空')),
        ],
      ),
    );
    if (ok == true) ref.read(patternStatsProvider.notifier).clear();
  }
}

/// 一个维度的单行统计：标签 + 一次答对率进度条 + 数字。
class _BucketRow extends StatelessWidget {
  const _BucketRow({required this.bucket});

  final StatBucket bucket;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final acc = bucket.accuracy;
    final color = acc >= 0.8
        ? const Color(0xFF22B573)
        : acc >= 0.5
            ? const Color(0xFFF59E0B)
            : scheme.error;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(bucket.label,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700)),
              ),
              Text('${(acc * 100).round()}%',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800, color: color)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: acc,
              minHeight: 6,
              backgroundColor: scheme.outlineVariant.withOpacity(0.4),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '作答 ${bucket.attempts} 题 · 一次答对 ${bucket.firstTry} 题 · 答错 ${bucket.wrongPicks} 次',
            style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
