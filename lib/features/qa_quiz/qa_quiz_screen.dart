import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../pattern_quiz/celebration.dart';
import '../pattern_quiz/exit_gate.dart';
import '../pattern_quiz/pattern_quiz_models.dart';
import '../pattern_quiz/pic_view.dart';
import '../pattern_quiz/quiz_sfx.dart';
import 'qa_bank.dart';
import 'qa_karaoke_text.dart';
import 'qa_models.dart';
import 'qa_speech.dart';

/// 「看图问答」闯关：
/// - 按 [ages] 取题库，可同时选多个年龄段一起出题，每局随机 [sessionSize] 道；
/// - **展示题目时朗读题面文字**，读到哪个字哪个字就高亮，
///   语速由家长在「我的 → 偏好设置」里设好（`QaRateChips`）；
/// - 四个选项可以是文字、图片或图文，点选项卡片右上角的小喇叭也能听一遍；
/// - **答对**：音效 + 震动，稍作停留自动进入下一题；
/// - **答错**：选项标红，可以接着再选，直到答对为止。成绩按「一次答对」算；
/// - **没做完就想返回**：先过家长验证（见 [showExitGate]）。
///
/// 题面文字**同时**是朗读文字和屏幕文字，三者必须一致语音高亮才对得上，
/// 所以题库里的题面不写阿拉伯数字（见 `assets/data/qa_questions.json`）。
class QaQuizScreen extends ConsumerStatefulWidget {
  const QaQuizScreen({super.key, required this.ages, required this.bank});

  /// 本局使用的年龄档位（可多个，取合并题库）。
  final Set<PatternAgeGroup> ages;

  /// 已加载的题库。
  final QaBank bank;

  /// 每局出题数量。
  static const int sessionSize = 10;

  @override
  ConsumerState<QaQuizScreen> createState() => _QaQuizScreenState();
}

class _QaQuizScreenState extends ConsumerState<QaQuizScreen> {
  static const Duration _celebrateFor = Duration(milliseconds: 1150);

  static const List<String> _praises = [
    '太棒了！',
    '答对啦！',
    '真聪明！',
    '好厉害！',
    '说得真好！',
    '你真棒！',
  ];

  final Random _rng = Random();

  late List<QaQuestion> _order;
  int _qi = 0;
  Timer? _nextTimer;

  // 当前回合
  bool _resolved = false;
  int _missedThis = 0;
  final Set<int> _wrongPicks = {}; // 本题已经点错过的选项
  String _praise = _praises.first;

  // 统计
  int _firstTryRight = 0;
  int _wrongTotal = 0;
  bool _finished = false;

  /// 通过家长验证后置真，放行这一次返回。
  bool _exiting = false;

  int get _total => _order.length;
  bool get _isLast => _qi >= _total - 1;
  QaQuestion get _q => _order[_qi];

  /// 标题里的年龄段文案：单个直接显示，多个显示混合档位。
  String get _agesLabel {
    final picked = [
      for (final g in PatternAgeGroup.values)
        if (widget.ages.contains(g)) g.ageText,
    ];
    if (picked.isEmpty) return '看图问答';
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
    _nextTimer?.cancel();
    QaSpeech.instance.stop();
    QuizSfx.instance.dispose();
    super.dispose();
  }

  void _restart() {
    _nextTimer?.cancel();
    final all = [...widget.bank.forAges(widget.ages)]..shuffle(_rng);
    _order = all.take(QaQuizScreen.sessionSize).toList();
    _qi = 0;
    _firstTryRight = 0;
    _wrongTotal = 0;
    _finished = _order.isEmpty;
    if (_order.isEmpty) {
      QaSpeech.instance.stop();
      return;
    }
    _begin();
  }

  void _begin() {
    _resolved = false;
    _missedThis = 0;
    _wrongPicks.clear();
    _praise = _praises.first;
    // 等这一帧画完再读，确保高亮能立刻跟上第一段。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _speakPrompt();
    });
  }

  void _speakPrompt() {
    if (_finished) return;
    final q = _q;
    if (!q.readPrompt) return;
    final clip = widget.bank.promptClip(q);
    if (clip == null) return;
    QaSpeech.instance.speak(q.clipKey, clip);
  }

  void _toggleOptionSpeech(int i) {
    final q = _q;
    final clip = widget.bank.optionClip(q, i);
    if (clip == null) return;
    final key = q.optionClipKey(i);
    if (QaSpeech.instance.isSpeaking(key)) {
      QaSpeech.instance.stop();
    } else {
      QaSpeech.instance.speak(key, clip);
    }
  }

  void _pick(int i) {
    if (_resolved || _wrongPicks.contains(i)) return;
    QaSpeech.instance.stop();

    if (i == _q.answer) {
      setState(() {
        _resolved = true;
        _praise = _praises[_rng.nextInt(_praises.length)];
        if (_missedThis == 0) _firstTryRight++;
      });
      QuizSfx.instance.playRight();
      HapticFeedback.mediumImpact();
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
      setState(() => _wrongPicks.add(i));
    }
  }

  void _next() {
    if (!mounted) return;
    QaSpeech.instance.stop();
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
      canPop: _finished || _exiting,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _guardExit();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('看图问答 · $_agesLabel'),
          actions: [
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
    final q = _q;
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
              if (q.scene.isNotEmpty) ...[
                _sceneRow(context, q),
                const SizedBox(height: 10),
              ],
              _promptCard(context, q),
              const SizedBox(height: 10),
              _readHint(context, q),
              Text('请选择答案',
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurfaceVariant)),
              const SizedBox(height: 8),
              _optionGrid(context, q),
              const SizedBox(height: 10),
              if (_resolved) _praiseBanner(context),
            ],
          ),
        ),
      ),
    );
  }

  /// 一行放下三样：题号进度、本题 id、难度星；窄屏上 id 会自动缩一点。
  Widget _headRow(BuildContext context, QaQuestion q) {
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
            q.stars > i ? Icons.star_rounded : Icons.star_outline_rounded,
            size: 18,
            color:
                q.stars > i ? const Color(0xFFF59E0B) : scheme.outlineVariant,
          ),
      ],
    );
  }

  /// 题号徽标：展示结构化题号（反馈问题直接贴它），点一下复制。
  Widget _idBadge(BuildContext context, QaQuestion q) {
    final scheme = Theme.of(context).colorScheme;
    final qid = q.qid;

    void copyId() {
      Clipboard.setData(ClipboardData(text: qid));
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('已复制题号 $qid'),
          duration: const Duration(seconds: 1),
        ));
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
                // 年龄段已经在标题栏里了，这里只留中文分类，省得一行放不下。
                Text(
                  q.kind.label,
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

  // ---------- 题面图 ----------
  Widget _sceneRow(BuildContext context, QaQuestion q) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 104,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? scheme.surfaceContainerHigh
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < q.scene.length; i++) ...[
            Expanded(
              child: PicView(pic: q.scene[i], color: scheme.primary),
            ),
            if (i != q.scene.length - 1) const SizedBox(width: 2),
          ],
        ],
      ),
    );
  }

  // ---------- 题面文字 ----------
  /// 题面 + 重播键**同一行**：读完想再听一遍就点右边那个喇叭，
  /// 不用再去下面找一行按钮。语速由家长在「我的 → 偏好设置」里定，这里不给调。
  Widget _promptCard(BuildContext context, QaQuestion q) {
    final scheme = Theme.of(context).colorScheme;
    final clip = q.readPrompt ? widget.bank.promptClip(q) : null;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, 12, clip == null ? 16 : 6, 12),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withOpacity(0.45),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: QaKaraokeText(
              text: q.prompt,
              clipKey: q.clipKey,
              clip: widget.bank.promptClip(q),
              highlight: q.readPrompt,
            ),
          ),
          if (clip != null)
            AnimatedBuilder(
              animation: QaSpeech.instance.speaking,
              builder: (context, _) {
                final playing = QaSpeech.instance.isSpeaking(q.clipKey);
                return IconButton.filledTonal(
                  onPressed: playing
                      ? () => QaSpeech.instance.stop()
                      : () => QaSpeech.instance.speak(q.clipKey, clip),
                  tooltip: playing ? '停止' : '再读一遍',
                  icon: Icon(
                      playing ? Icons.stop_rounded : Icons.volume_up_rounded),
                  iconSize: 20,
                  visualDensity: VisualDensity.compact,
                  constraints:
                      const BoxConstraints.tightFor(width: 40, height: 40),
                );
              },
            ),
        ],
      ),
    );
  }

  /// 不朗读的题（阅读选图）给一行小提示，朗读题不需要，占位为零。
  Widget _readHint(BuildContext context, QaQuestion q) {
    if (q.readPrompt) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.menu_book_rounded, size: 16, color: scheme.outline),
          const SizedBox(width: 6),
          Flexible(
            child: Text('读一读题目，选出对应的图片',
                style: TextStyle(fontSize: 12.5, color: scheme.outline)),
          ),
        ],
      ),
    );
  }

  // ---------- 选项 ----------
  Widget _optionGrid(BuildContext context, QaQuestion q) {
    final n = q.options.length;
    final cols = n <= 2 ? n : 2;
    final rows = (n / cols).ceil();
    final hasPic = q.options.any((o) => o.hasPic);
    final cellH = hasPic ? 116.0 : 74.0;

    return Column(
      children: [
        for (var r = 0; r < rows; r++) ...[
          if (r > 0) const SizedBox(height: 8),
          SizedBox(
            height: cellH,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var c = 0; c < cols; c++) ...[
                  if (c > 0) const SizedBox(width: 10),
                  Expanded(
                    child: r * cols + c < n
                        ? _optionCell(context, q, r * cols + c)
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _optionCell(BuildContext context, QaQuestion q, int i) {
    final o = q.options[i];
    final scheme = Theme.of(context).colorScheme;
    final isRight = i == q.answer;
    final wrong = _wrongPicks.contains(i);
    final revealRight = _resolved && isRight;

    Color? bg;
    Color? border;
    if (revealRight) {
      bg = Colors.green.withOpacity(0.12);
      border = Colors.green;
    } else if (wrong) {
      bg = scheme.errorContainer.withOpacity(0.55);
      border = scheme.error;
    }

    final letter = String.fromCharCode(65 + i);
    final clip = widget.bank.optionClip(q, i);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _resolved || wrong ? null : () => _pick(i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: bg ??
                (Theme.of(context).brightness == Brightness.dark
                    ? scheme.surfaceContainerHigh
                    : Colors.white),
            border: Border.all(
              color: border ?? Colors.transparent,
              width: 1.8,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 20, 10, 6),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (o.hasPic)
                        Expanded(
                          child: PicView(pic: o.pic!, color: scheme.primary),
                        ),
                      if (o.hasPic && o.hasText) const SizedBox(height: 4),
                      if (o.hasText)
                        Text(
                          o.text,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 5,
                left: 7,
                child: Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: revealRight
                        ? Colors.green
                        : (Theme.of(context).brightness == Brightness.dark
                            ? scheme.surfaceContainerHighest
                            : scheme.primaryContainer),
                    border: Border.all(
                      color: revealRight
                          ? Colors.green
                          : (Theme.of(context).brightness == Brightness.dark
                              ? scheme.outline
                              : Colors.white),
                      width: 1.5,
                    ),
                  ),
                  child: Text(letter,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: revealRight
                              ? Colors.white
                              : scheme.onPrimaryContainer)),
                ),
              ),
              if (clip != null)
                Positioned(
                  top: 0,
                  right: 0,
                  child: AnimatedBuilder(
                    animation: QaSpeech.instance.speaking,
                    builder: (context, _) {
                      final playing =
                          QaSpeech.instance.isSpeaking(q.optionClipKey(i));
                      return IconButton(
                        onPressed: () => _toggleOptionSpeech(i),
                        tooltip: playing ? '停止' : '读一读这个选项',
                        icon: Icon(playing
                            ? Icons.stop_circle_rounded
                            : Icons.volume_up_rounded),
                        iconSize: 19,
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        constraints:
                            const BoxConstraints.tightFor(width: 32, height: 32),
                        color: playing ? scheme.primary : scheme.outline,
                      );
                    },
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
      >= 90 => ('太棒了！', '听得又准又认真，全都答对啦'),
      >= 60 => ('真不错', '再多练几题会更好'),
      _ => ('继续加油', '慢慢听、认真看，下次一定更棒'),
    };
    final stars = switch (percent) {
      >= 90 => 3,
      >= 70 => 2,
      >= 40 => 1,
      _ => 0,
    };

    return Stack(
      children: [
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
                      textAlign: TextAlign.center,
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
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

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
