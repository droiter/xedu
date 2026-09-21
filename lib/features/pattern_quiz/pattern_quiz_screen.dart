import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/back_guard.dart';
import 'celebration.dart';
import 'exit_gate.dart';
import 'pattern_quiz_bank.dart';
import 'pattern_quiz_models.dart';
import 'pattern_stats.dart';
import 'pattern_stats_screen.dart';
import 'pic_view.dart';
import 'question_taxonomy.dart';
import 'quiz_sfx.dart';

/// 「看图找规律」闯关：
/// - 按 [ages] 年龄档位取题库，可同时选多个年龄段一起出题；
/// - **每局随机抽 [sessionSize] 道题**，题库再大也不会一次做完；
/// - 每题 4 格图遵循一个规律，在允许的位置里随机挖空一格；
/// - 从多个备选中选出被挖掉的那张图；
/// - **答对**：音效 + 震动 + 炫光爆发，稍作停留后自动进入下一题；
/// - **答错**：轻音提示并重打乱备选、替换部分干扰项，可以再试，直到答对为止。
///   成绩按「一次答对」的题数计算；
/// - **没做完就想返回**：拦下来，先答对一道一位数乘法才放行（见 [showExitGate]）。
class PatternQuizScreen extends ConsumerStatefulWidget {
  const PatternQuizScreen({super.key, required this.ages});

  /// 本局使用的年龄档位（可多个，取合并题库）。
  final Set<PatternAgeGroup> ages;

  /// 每局出题数量。
  static const int sessionSize = 10;

  @override
  ConsumerState<PatternQuizScreen> createState() => _PatternQuizScreenState();
}

class _PatternQuizScreenState extends ConsumerState<PatternQuizScreen>
    with SingleTickerProviderStateMixin, BackGuard<PatternQuizScreen> {
  static const int _optionCount = 4; // 1 个正确 + 3 个干扰项
  static const int _wrongSlots = _optionCount - 1;
  static const Duration _celebrateFor = Duration(milliseconds: 950);

  static const List<String> _praises = [
    '太棒了！',
    '答对啦！',
    '真聪明！',
    '好厉害！',
    '就是这张！',
    '眼睛真尖！',
  ];

  final Random _rng = Random();

  /// 答对瞬间的炫光爆发动画（0 → 1）。
  late final AnimationController _celebrate = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  late List<PatternQuestion> _order;
  int _qi = 0;
  Timer? _retryTimer;
  Timer? _nextTimer;

  // 当前回合
  int _blank = 0;
  late Pic _correct;
  // 展示给玩家的完整备选（含正确答案，顺序打乱；错误重排时才更新）。
  List<Pic> _options = [];
  bool _resolved = false;
  int _picked = -1; // 最近一次点选的选项下标（高亮用）
  bool _busy = false; // 错误反馈 / 重排动画期间禁止再点
  int _burstSeed = 7;
  String _praise = _praises.first;

  // 统计
  int _firstTryRight = 0; // 一次就答对的题数，作为成绩
  int _missedThis = 0; // 本题已经答错几次
  int _wrongTotal = 0; // 累计答错次数
  bool _finished = false;

  /// 通过家长验证后置真，放行这一次返回。
  bool _exiting = false;

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
    QuizSfx.instance.preload();
    _restart();
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _nextTimer?.cancel();
    _celebrate.dispose();
    QuizSfx.instance.dispose();
    super.dispose();
  }

  void _restart() {
    _retryTimer?.cancel();
    _nextTimer?.cancel();
    _celebrate.value = 0;
    final all = [...patternBankForAges(widget.ages)]..shuffle(_rng);
    _order = all.take(PatternQuizScreen.sessionSize).toList();
    _qi = 0;
    _firstTryRight = 0;
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
    _missedThis = 0;
    _celebrate.value = 0;
  }

  List<Pic> _shuffleDisplay(List<Pic> wrongs) =>
      [_correct, ...wrongs]..shuffle(_rng);

  /// 从干扰项池生成 [_wrongSlots] 个干扰项（不会与正确答案重复、彼此不重复）。
  /// [keepShown] 表示保留几道上一轮展示过的旧选项（其余换成新的）。
  List<Pic> _makeWrongs({required int keepShown}) {
    final pool = _order[_qi].distractors;
    final correctId = _correct.id;
    const need = _wrongSlots;

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
      // 记录这一题的成绩：这次首答是否正确 + 这次答错几次。
      ref.read(patternStatsProvider.notifier).record(
            qid: qidOf(_order[_qi]),
            wrong: _missedThis,
          );
      setState(() {
        _resolved = true;
        _picked = i;
        _praise = _praises[_rng.nextInt(_praises.length)];
        if (_missedThis == 0) _firstTryRight++;
        _burstSeed = _rng.nextInt(1 << 20);
      });
      // 声光鼓励：音效 + 震动 + 炫光爆发
      QuizSfx.instance.playRight();
      HapticFeedback.mediumImpact();
      _celebrate.forward(from: 0);
      // 玩够了自动进入下一题，不用再点按钮
      _nextTimer?.cancel();
      _nextTimer = Timer(
          _isLast
              ? _celebrateFor + const Duration(milliseconds: 350)
              : _celebrateFor,
          _next);
    } else {
      _wrongTotal++;
      _missedThis++;
      QuizSfx.instance.playWrong();
      HapticFeedback.lightImpact();
      // 反馈红色瞬间后，重打乱并替换部分干扰项，可以再试
      _busy = true;
      setState(() => _picked = i);
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

  void _next() {
    if (!mounted) return;
    if (_isLast) {
      setState(() => _finished = true);
      QuizSfx.instance.playWin();
      HapticFeedback.heavyImpact();
      return;
    }
    setState(() {
      _qi++;
      _begin();
    });
  }

  /// 没做完就想走：先过家长验证，答对乘法题才放行。
  Future<void> _guardExit() async {
    final result = await showExitGate(context);
    if (!mounted) return;
    if (result.isPassed) {
      setState(() => _exiting = true);
      Navigator.of(context).pop();
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(result.message),
        duration: const Duration(seconds: 2),
      ));
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    return PopScope(
      // 做完（成绩页）直接放行；做题中则拦下来验证。
      canPop: _finished || _exiting,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // 合上平板再打开时系统会补一个返回键过来，那一下不算孩子按的。
        if (!isRealBack()) return;
        _guardExit();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('看图找规律 · $_agesLabel'),
          actions: [
            IconButton(
              tooltip: '学习统计',
              icon: const Icon(Icons.insights_rounded),
              onPressed: () => _openStats(context),
            ),
            IconButton(
              tooltip: '重新开始',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => setState(_restart),
            ),
          ],
        ),
        body: SafeArea(
            child: _finished ? _resultView(context) : _gameView(context)),
      ),
    );
  }

  Widget _gameView(BuildContext context) {
    final q = _order[_qi];
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _headRow(context, q),
              const SizedBox(height: 8),
              _hintLine(context, q),
              const SizedBox(height: 2),
              Text('找出规律，选出空白处缺少的那张图',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12.5, color: scheme.onSurfaceVariant)),
              const SizedBox(height: 8),
              _slotRow(context),
              const SizedBox(height: 12),
              Text('请选择',
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurfaceVariant)),
              const SizedBox(height: 8),
              _optionRow(context),
              const SizedBox(height: 10),
              if (_resolved) _praiseBanner(context),
            ],
          ),
        ),
      ),
    );
  }

  /// 一行放下三样：题号进度、本题 id、难度星；窄屏上 id 会自动缩一点。
  Widget _headRow(BuildContext context, PatternQuestion q) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
        const SizedBox(width: 8),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: _idBadge(context, q),
          ),
        ),
        const SizedBox(width: 8),
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
    );
  }

  /// 规律提示：**答错一次之前不显示**，做错后才亮出来帮孩子找规律。
  Widget _hintLine(BuildContext context, PatternQuestion q) {
    final shown = _missedThis > 0;
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: shown
          ? Row(
              key: const ValueKey('hint'),
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lightbulb_outline_rounded,
                    size: 16, color: Color(0xFFF59E0B)),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(q.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                ),
              ],
            )
          : const SizedBox(key: ValueKey('no-hint'), height: 0),
    );
  }

  /// 题号徽标：展示题目唯一 id（含多级分类）+ 中文分类；
  /// id 旁的复制图标（整块徽标也可点）把 id 拷到剪贴板。
  Widget _idBadge(BuildContext context, PatternQuestion q) {
    final scheme = Theme.of(context).colorScheme;
    final qid = qidOf(q);

    void copyId() {
      Clipboard.setData(ClipboardData(text: qid));
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('已复制题号 $qid'),
            duration: const Duration(seconds: 1),
          ),
        );
    }

    return Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: copyId,
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 3, 8, 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: scheme.outlineVariant.withOpacity(0.6)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    qid,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.3,
                      fontFamily: 'monospace',
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                IconButton(
                  onPressed: copyId,
                  tooltip: '复制题号',
                  icon: const Icon(Icons.copy_rounded),
                  iconSize: 15,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  constraints:
                      const BoxConstraints.tightFor(width: 26, height: 24),
                  color: scheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  categoryLabelOf(q),
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.3,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ));
  }

  void _openStats(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PatternStatsScreen()),
    );
  }

  // ---------- 4 格图 ----------
  Widget _slotRow(BuildContext context) {
    final q = _order[_qi];
    return SizedBox(
      height: 118,
      // Clip.none：让答对的炫光可以飞出格子范围。
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < q.items.length; i++) ...[
                Expanded(child: _slot(context, i)),
                if (i != q.items.length - 1) const SizedBox(width: 8),
              ],
            ],
          ),
          if (_resolved)
            Positioned.fill(
              child: IgnorePointer(
                child: SparkleBurst(
                  animation: _celebrate,
                  centerFraction: (_blank + 0.5) / q.items.length,
                  seed: _burstSeed,
                ),
              ),
            ),
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
                fontSize: 34,
                fontWeight: FontWeight.w800,
                color: scheme.outline)),
      );
    } else {
      content = PicView(
          pic: isBlank ? _correct : q.items[index], color: scheme.primary);
    }

    // 答对时这一格亮起来，并轻微「弹」一下
    return AnimatedScale(
      scale: filled ? 1.04 : 1.0,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutBack,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: filled
              ? Colors.green.withOpacity(0.14)
              : (Theme.of(context).brightness == Brightness.dark
                  ? scheme.surfaceContainerHigh
                  : Colors.white),
          border: Border.all(
            color: filled
                ? Colors.green
                : (isBlank
                    ? scheme.outlineVariant.withOpacity(0.7)
                    : Colors.transparent),
            width: filled ? 2.4 : 1.6,
          ),
          boxShadow: filled
              ? [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.45),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ]
              : null,
          borderRadius: BorderRadius.circular(14),
        ),
        child: content,
      ),
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
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
              Center(child: PicView(pic: pic, color: scheme.primary)),
              // 序号画在图片之上：色块会铺满整格，压在下面就被挡住了。
              Positioned(
                top: 4,
                left: 6,
                child: Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCorrectOpt && _resolved
                        ? Colors.green
                        : (Theme.of(context).brightness == Brightness.dark
                            ? scheme.surfaceContainerHighest
                            : scheme.primaryContainer),
                    border: Border.all(
                      color: isCorrectOpt && _resolved
                          ? Colors.green
                          : (Theme.of(context).brightness == Brightness.dark
                              ? scheme.outline
                              : Colors.white),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Text(letter,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: isCorrectOpt && _resolved
                              ? Colors.white
                              : scheme.onPrimaryContainer)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 答对后的鼓励条：不拦手，稍后自动进入下一题。
  Widget _praiseBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.4, end: 1),
            duration: const Duration(milliseconds: 420),
            curve: Curves.elasticOut,
            builder: (_, s, child) => Transform.scale(scale: s, child: child),
            child: const Icon(Icons.auto_awesome_rounded,
                color: Colors.green, size: 22),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_praise,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          ),
          Row(
            children: [
              Icon(Icons.play_arrow_rounded,
                  size: 16, color: Colors.green.withOpacity(0.8)),
              const SizedBox(width: 3),
              Text(_isLast ? '马上看成绩' : '马上下一题',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade700)),
            ],
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
    final percent = (_firstTryRight * 100 / _total).round();
    final (headline, sub) = switch (percent) {
      >= 90 => ('太棒了！', '规律题全掌握，逻辑力满分'),
      >= 60 => ('真不错', '再多练几题会更好'),
      _ => ('继续加油', '多观察多练习，下次一定更棒'),
    };
    final stars = switch (percent) {
      >= 90 => 3,
      >= 70 => 2,
      >= 40 => 1,
      _ => 0,
    };

    return Stack(
      children: [
        // 通关撒花（纯装饰）
        const Positioned.fill(child: ConfettiRain()),
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.2, end: 1),
                    duration: const Duration(milliseconds: 650),
                    curve: Curves.elasticOut,
                    builder: (_, s, child) =>
                        Transform.scale(scale: s, child: child),
                    child: Container(
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
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: percent.toDouble()),
                              duration: const Duration(milliseconds: 900),
                              curve: Curves.easeOutCubic,
                              builder: (_, v, __) => Text('${v.round()}',
                                  style: TextStyle(
                                      fontSize: 44,
                                      fontWeight: FontWeight.w800,
                                      color: scheme.primary)),
                            ),
                            Text('分',
                                style: TextStyle(
                                    fontSize: 14, color: scheme.primary)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _starRow(stars),
                  const SizedBox(height: 14),
                  Text(headline,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(sub,
                      style: TextStyle(
                          fontSize: 14, color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 12),
                  Text('一次答对 $_firstTryRight / $_total 题 · 累计答错 $_wrongTotal 次',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 13, color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton.icon(
                      onPressed: () => setState(_restart),
                      icon: const Icon(Icons.replay_rounded),
                      label: const Text('再玩一局'),
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
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: TextButton.icon(
                      onPressed: () => _openStats(context),
                      icon: const Icon(Icons.insights_rounded),
                      label: const Text('查看学习统计'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 三颗星星依次弹出。
  Widget _starRow(int earned) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 3; i++)
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.2, end: 1),
            duration: Duration(milliseconds: 420 + i * 180),
            curve: Curves.elasticOut,
            builder: (_, s, child) => Transform.scale(scale: s, child: child),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Icon(
                i < earned ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 40,
                color: i < earned
                    ? const Color(0xFFFFC107)
                    : Colors.grey.withOpacity(0.45),
              ),
            ),
          ),
      ],
    );
  }
}
