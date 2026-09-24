import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../catalog/catalog_screen.dart';
import '../pattern_quiz/pattern_age_select_screen.dart';
import '../profile/profile_screen.dart';
import '../progress/progress_screen.dart';
import '../qa_quiz/qa_age_select_screen.dart';

/// 底部导航主框架。
///
/// 原来那页「首页」（问候语 + 搜索栏 + 精选 + 继续学习）已经隐藏：一进 App
/// 就停在「看图找规律」的年龄选择页，「看图找规律」那格也就是选中状态。
/// 首页的代码还在 `features/home/home_screen.dart`，只是没人引用。
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
          const PatternAgeSelectScreen(),
          const QaAgeSelectScreen(),
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
/// 「现在在哪个分类」只靠高亮表示（当前那格是主色 + 药丸底色），不转光辉 ——
/// 转着的光既晃眼，也说不清到底在哪个分类。置灰的格子点不进去。
///
/// 并排的格子挨得近，字号和内边距都收了一点，字太长会省略号收尾。
class _TabBar extends StatelessWidget {
  const _TabBar({required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const cells = [
      (Icons.auto_awesome_rounded, '看图找规律'),
      (Icons.question_answer_rounded, '看图问答'),
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
                  selected: i == index,
                  onTap: kOpenTabs.contains(i) ? () => onSelect(i) : null,
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
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

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
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 4),
                child: body,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
