import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../shared/widgets/glow_border.dart';
import '../catalog/catalog_screen.dart';
import '../home/home_screen.dart';
import '../profile/profile_screen.dart';
import '../progress/progress_screen.dart';
import '../qa_quiz/qa_age_select_screen.dart';
import '../video/video_library_screen.dart';

/// 底部导航主框架。
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = kQuizTab;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(onOpenTab: _goTab),
          const QaAgeSelectScreen(),
          VideoLibraryScreen(onOpenManage: () => _goTab(kProfileTab)),
          const CatalogScreen(),
          ProgressScreen(onExplore: () => _goTab(kCourseTab)),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: _TabBar(index: _index, onSelect: _goTab),
    );
  }

  /// 只有 [kOpenTabs] 里的选项卡能进入；置灰的入口任何跳转都忽略。
  void _goTab(int index) {
    if (!kOpenTabs.contains(index) || index == _index) return;
    setState(() => _index = index);
  }
}

/// 底部选项卡。
///
/// 「现在在哪个分类」靠高亮表示（当前那格是主色 + 药丸底色），光辉只在刚切
/// 进去的那一下转一圈就收，不再常驻 —— 常驻既晃眼，也说不清到底在哪个分类。
/// 置灰的格子点不进去。
///
/// 六格并排比原来挤，字号和内边距都收了一点，字太长会省略号收尾。
class _TabBar extends StatefulWidget {
  const _TabBar({required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  /// 刚切过去的那一格，光辉亮这么久就收。
  static const Duration burstFor = Duration(milliseconds: 1200);

  @override
  State<_TabBar> createState() => _TabBarState();
}

class _TabBarState extends State<_TabBar> with SingleTickerProviderStateMixin {
  /// 只用来给「刚切过去的那一格」计时，不控制光辉自己的转动。
  late final AnimationController _burst = AnimationController(
    vsync: this,
    duration: _TabBar.burstFor,
  );
  int? _burstTab;

  @override
  void initState() {
    super.initState();
    _burst.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _burstTab = null);
      }
    });
  }

  @override
  void dispose() {
    _burst.dispose();
    super.dispose();
  }

  /// 进到某个分类：先让这一格亮一下，换页仍然交给外壳。
  void _select(int i) {
    if (i == widget.index) return;
    setState(() => _burstTab = i);
    _burst.forward(from: 0);
    widget.onSelect(i);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const cells = [
      (Icons.auto_awesome_rounded, '看图找规律'),
      (Icons.question_answer_rounded, '看图问答'),
      (Icons.ondemand_video_rounded, '看视频'),
      (Icons.grid_view_outlined, '课程'),
      (Icons.leaderboard_outlined, '进度'),
      (Icons.person_outline_rounded, '我的'),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        border: Border(
          top: BorderSide(color: scheme.outlineVariant, width: 0.6),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 70,
          child: Row(
            children: [
              for (var i = 0; i < cells.length; i++)
                _TabCell(
                  key: ValueKey('tab-$i'),
                  icon: cells[i].$1,
                  label: cells[i].$2,
                  selected: i == widget.index,
                  glow: i == _burstTab,
                  onTap: kOpenTabs.contains(i) ? () => _select(i) : null,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 一格选项卡。[onTap] 为空即「置灰不可进入」，[selected] 是「现在就在这个分类里」。
class _TabCell extends StatelessWidget {
  const _TabCell({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    this.onTap,
    this.glow = false,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  /// 刚切过来的这一格，光辉亮一下就收。
  final bool glow;

  bool get _open => onTap != null;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = !_open
        ? scheme.onSurface.withOpacity(0.32)
        : selected
            ? scheme.primary
            : scheme.onSurfaceVariant;

    final body = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 当前这一格垫一层药丸底色，一眼看出现在在哪个分类。
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(
            color: selected ? scheme.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 22,
            color: selected ? scheme.onPrimaryContainer : color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            // 六格并排，字要收一点才不会被截断。
            fontSize: 9.5,
            fontWeight: selected
                ? FontWeight.w700
                : (_open ? FontWeight.w600 : FontWeight.w500),
            color: color,
          ),
        ),
      ],
    );

    // 六格并排本来就不宽，光辉那格也只用同样的内边距，不然文字会被挤成省略号。
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 4),
      child: body,
    );

    return Expanded(
      child: Semantics(
        button: true,
        enabled: _open,
        selected: selected,
        child: IgnorePointer(
          ignoring: !_open,
          child: InkWell(
            onTap: onTap,
            child: Center(
              child: glow
                  ? GlowBorder(
                      radius: 14,
                      strokeWidth: 2,
                      period: const Duration(milliseconds: 600),
                      child: content,
                    )
                  : content,
            ),
          ),
        ),
      ),
    );
  }
}
