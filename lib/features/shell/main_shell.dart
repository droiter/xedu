import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../shared/widgets/glow_border.dart';
import '../catalog/catalog_screen.dart';
import '../home/home_screen.dart';
import '../profile/profile_screen.dart';
import '../progress/progress_screen.dart';
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

/// 底部选项卡：第一格「看图找规律」带转圈光辉，置灰的格子点不进去。
class _TabBar extends StatelessWidget {
  const _TabBar({required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const cells = [
      (Icons.auto_awesome_rounded, '看图找规律'),
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
                  icon: cells[i].$1,
                  label: cells[i].$2,
                  glow: i == kQuizTab,
                  onTap: kOpenTabs.contains(i) ? () => onSelect(i) : null,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 一格选项卡。[onTap] 为空即「置灰不可进入」。
class _TabCell extends StatelessWidget {
  const _TabCell({
    required this.icon,
    required this.label,
    this.onTap,
    this.glow = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool glow;

  bool get _open => onTap != null;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = _open ? scheme.primary : scheme.onSurface.withOpacity(0.32);
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 23, color: color),
        const SizedBox(height: 3),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            // 五格并排，字要收一点才不会被截断。
            fontSize: 10.5,
            fontWeight: _open ? FontWeight.w700 : FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );

    // 五格并排本来就不宽，光辉那格也只用同样的内边距，不然文字会被挤成省略号。
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: body,
    );

    return Expanded(
      child: Semantics(
        button: true,
        enabled: _open,
        child: IgnorePointer(
          ignoring: !_open,
          child: InkWell(
            onTap: onTap,
            child: Center(
              child: glow
                  ? GlowBorder(
                      radius: 14,
                      strokeWidth: 2,
                      period: const Duration(seconds: 2, milliseconds: 400),
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
