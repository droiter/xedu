import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'pattern_quiz_bank.dart';
import 'pattern_quiz_models.dart';
import 'pic_view.dart';

/// 「看图找规律」闯关：
/// - 按 [ages] 年龄档位取题库，可同时选多个年龄段一起出题；
/// - 每题 4 格图遵循一个规律，在允许的位置里随机挖空一格；
/// - 从多个备选中选出被挖掉的那张图；
/// - 答对进下一题；答错会重打乱备选顺序、并替换部分干扰项，可再试，直到答对为止。
class PatternQuizScreen extends StatefulWidget {
  const PatternQuizScreen({super.key, required this.ages});

  /// 本局使用的年龄档位（可多个，取合并题库）。
  final Set<PatternAgeGroup> ages;

  @override
  State<PatternQuizScreen> createState() => _PatternQuizScreenState();
}

class _PatternQuizScreenState extends State<PatternQuizScreen> {
  static const int _optionCount = 4; // 1 个正确 + 3 个干扰项
  static const int _wrongSlots = _optionCount - 1;

  final Random _rng = Random();

  late List<PatternQuestion> _order;
  int _qi = 0;
  Timer? _retryTimer;

  // 当前回合
  int _blank = 0;
  late Pic _correct;
  // 展示给玩家的完整备选（含正确答案，顺序打乱；错误重排时才更新）。
  List<Pic> _options = [];
  bool _resolved = false;
  int _picked = -1; // 最近一次点选的选项下标（高亮用）
  bool _busy = false; // 错误反馈 / 重排动画期间禁止再点

  // 统计
  int _right = 0;
  int _wrongTotal = 0;
  bool _finished = false;

  int get _total => _order.length;
  bool get _isLast => _qi >= _total - 1;

  /// 标题里的年龄段文案：单个直接显示，多个显示混合档位。
  String get _agesLabel {
    final picked = [
      for (final g in PatternAgeGroup.values)
        if (widget.ages.contains(g)) g.ageText,
    ];
    if (picked.isEmpty) return '看图找规律';
    if (picked.length == 1) return picked.first;
    if (picked.length == 2) return '${picked[0]} + ${picked[1]}';
    return '混龄 · ${picked.length} 个年龄段';
  }

  @override
  void initState() {
    super.initState();
    _restart();
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  void _restart() {
    _order = [...patternBankForAges(widget.ages)]..shuffle(_rng);
    _qi = 0;
    _right = 0;
    _wrongTotal = 0;
    _finished = _order.isEmpty;
    if (_order.isEmpty) return;
    _begin();
  }

  /// 进入当前索引题目：在允许的位置里随机挖空一格并生成备选。
  void _begin() {
    final q = _order[_qi];
    final blanks = q.blankables;
    _blank = blanks[_rng.nextInt(blanks.length)];
    _correct = q.items[_blank];
    _options = _shuffleDisplay(_makeWrongs(keepShown: 0));
    _resolved = false;
    _picked = -1;
    _busy = false;
  }

  List<Pic> _shuffleDisplay(List<Pic> wrongs) =>
      [_correct, ...wrongs]..shuffle(_rng);

  /// 从干扰项池生成 [_wrongSlots] 个干扰项（不会与正确答案重复、彼此不重复）。
  /// [keepShown] 表示保留几道上一轮展示过的旧选项（其余换成新的）。
  List<Pic> _makeWrongs({required int keepShown}) {
    final pool = _order[_qi].distractors;
    final correctId = _correct.id;
    final need = _wrongSlots;

    final wrongs = <Pic>[];
    final used = <String>{correctId};

    // 1) 保留部分上一轮展示的干扰项
    final shown = [..._options.where((p) => p.id != correctId)]..shuffle(_rng);
    var kept = keepShown < 0 ? 0 : keepShown;
    if (kept > shown.length) kept = shown.length;
    for (var i = 0; i < kept; i++) {
      wrongs.add(shown[i]);
      used.add(shown[i].id);
    }

    // 2) 用未用过的干扰项补满
    final fresh = [...pool]..shuffle(_rng);
    for (final p in fresh) {
      if (wrongs.length >= need) break;
      if (used.contains(p.id)) continue;
      wrongs.add(p);
      used.add(p.id);
    }
    // 3) 极少数题干扰项池不够大时，兜底从池中再取不同 id
    for (final p in pool) {
      if (wrongs.length >= need) break;
      if (p.id == correctId) continue;
      if (wrongs.any((w) => w.id == p.id)) continue;
      wrongs.add(p);
    }

    wrongs.shuffle(_rng);
    return wrongs;
  }

  void _pick(int i) {
    if (_resolved || _busy) return;
    final picked = _options[i];
    final isRight = picked.id == _correct.id;

    if (isRight) {
      setState(() {
        _resolved = true;
        _picked = i;
        _right++;
      });
    } else {
      _wrongTotal++;
      // 反馈红色瞬间后，重打乱并替换部分干扰项，可以再试
      _busy = true;
      setState(() => _picked = i);
      _toast('不对哦，再想想');
      _retryTimer?.cancel();
      _retryTimer = Timer(const Duration(milliseconds: 650), () {
        if (!mounted) return;
        setState(() {
          _options = _shuffleDisplay(
              _makeWrongs(keepShown: _rng.nextInt(_wrongSlots)));
          _picked = -1;
          _busy = false;
        });
      });
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(msg, textAlign: TextAlign.center),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 900),
      ));
  }

  void _next() {
    if (_isLast) {
      setState(() => _finished = true);
      return;
    }
    setState(() {
      _qi++;
      _begin();
    });
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('看图找规律 · $_agesLabel'),
        actions: [
          IconButton(
            tooltip: '重新开始',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              _retryTimer?.cancel();
              setState(_restart);
            },
          ),
        ],
      ),
      body: SafeArea(child: _finished ? _resultView(context) : _gameView(context)),
    );
  }

  Widget _gameView(BuildContext context) {
    final q = _order[_qi];
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _progressBar(context),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('第 ${_qi + 1} / $_total 题',
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: scheme.onPrimaryContainer)),
                  ),
                  const Spacer(),
                  for (var i = 0; i < 3; i++)
                    Icon(
                      q.difficulty > i
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 18,
                      color: q.difficulty > i
                          ? const Color(0xFFF59E0B)
                          : scheme.outlineVariant,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(q.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('找出规律，选出空白处缺少的那张图',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
              const SizedBox(height: 14),
              _slotRow(context),
              const SizedBox(height: 20),
              Text('请选择',
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurfaceVariant)),
              const SizedBox(height: 10),
              _optionRow(context),
              const SizedBox(height: 16),
              if (_resolved) _resultPanel(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _progressBar(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: (_qi + (_resolved ? 1 : 0)) / _total,
        minHeight: 5,
      ),
    );
  }

  // ---------- 4 格图 ----------
  Widget _slotRow(BuildContext context) {
    final q = _order[_qi];
    return SizedBox(
      height: 118,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < q.items.length; i++) ...[
            Expanded(child: _slot(context, i)),
            if (i != q.items.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _slot(BuildContext context, int index) {
    final q = _order[_qi];
    final isBlank = index == _blank;
    final scheme = Theme.of(context).colorScheme;
    final filled = isBlank && _resolved;

    Widget content;
    if (isBlank && !_resolved) {
      content = Container(
        margin: const EdgeInsets.all(14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: scheme.surfaceContainerHigh,
        ),
        child: Text('?',
            style: TextStyle(
                fontSize: 34, fontWeight: FontWeight.w800, color: scheme.outline)),
      );
    } else {
      content = PicView(
          pic: isBlank ? _correct : q.items[index],
          color: scheme.primary);
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: filled
            ? Colors.green.withOpacity(0.1)
            : (Theme.of(context).brightness == Brightness.dark
                ? scheme.surfaceContainerHigh
                : Colors.white),
        border: Border.all(
          color: filled
              ? Colors.green
              : (isBlank
                  ? scheme.outlineVariant.withOpacity(0.7)
                  : Colors.transparent),
          width: 1.6,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: content,
    );
  }

  // ---------- 备选答案 ----------
  Widget _optionRow(BuildContext context) {
    return SizedBox(
      height: 104,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < _options.length; i++) ...[
            Expanded(child: _option(context, i)),
            if (i != _options.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _option(BuildContext context, int i) {
    final pic = _options[i];
    final scheme = Theme.of(context).colorScheme;
    final isCorrectOpt = pic.id == _correct.id;
    final isChosen = i == _picked;

    Color? bg;
    Color? border;
    if (_resolved && isCorrectOpt) {
      bg = Colors.green.withOpacity(0.12);
      border = Colors.green;
    } else if (isChosen) {
      // 答错后的红闪反馈（等待自动重排期间）
      bg = scheme.errorContainer;
      border = scheme.error;
    }

    final letter = String.fromCharCode(65 + i);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _resolved || _busy ? null : () => _pick(i),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: bg ??
                (Theme.of(context).brightness == Brightness.dark
                    ? scheme.surfaceContainerHigh
                    : Colors.white),
            border: Border.all(
              color: border ??
                  (_resolved && isChosen ? scheme.primary : Colors.transparent),
              width: 1.6,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Stack(
            children: [
              Positioned(
                top: 4,
                left: 6,
                child: Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCorrectOpt && _resolved
                        ? Colors.green
                        : (Theme.of(context).brightness == Brightness.dark
                            ? scheme.surfaceContainerHighest
                            : scheme.primaryContainer),
                  ),
                  child: Text(letter,
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: isCorrectOpt && _resolved
                              ? Colors.white
                              : scheme.onPrimaryContainer)),
                ),
              ),
              Center(child: PicView(pic: pic, color: scheme.primary)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _resultPanel(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text('答对啦！规律掌握得不错',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: _next,
              icon: Icon(_isLast ? Icons.emoji_events_rounded : Icons.arrow_forward_rounded),
              label: Text(_isLast ? '查看成绩' : '下一题'),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- 结果 ----------
  Widget _resultView(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_total == 0) {
      return Center(
        child: Text('这个年龄还没有题目，先看看别的年龄吧',
            style: TextStyle(color: scheme.onSurfaceVariant)),
      );
    }
    final percent = (_right * 100 / _total).round();
    final (headline, sub) = switch (percent) {
      >= 90 => ('太棒了！', '规律题全掌握，逻辑力满分'),
      >= 60 => ('真不错', '再多练几题会更好'),
      _ => ('继续加油', '多观察多练习，下次一定更棒'),
    };

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              const SizedBox(height: 22),
              Text(headline, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(sub, style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant)),
              const SizedBox(height: 12),
              Text('答对 $_right / $_total 题 · 累计答错 $_wrongTotal 次',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: () => setState(_restart),
                  child: const Text('再玩一次'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.child_care_rounded),
                  label: const Text('换个年龄'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
