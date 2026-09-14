import 'package:flutter/material.dart';

import '../../shared/widgets/glow_border.dart';
import '../catalog/catalog_screen.dart';
import '../home/home_screen.dart';
import '../profile/profile_screen.dart';
import '../progress/progress_screen.dart';

/// 当前唯一开放的选项卡下标；其余的保留可见但置灰、点不进去。
const int kOpenTab = 0;

/// 底部导航主框架。
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = kOpenTab;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(onOpenTab: _goTab),
          const CatalogScreen(),
          ProgressScreen(onExplore: () => _goTab(1)),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: const _TabBar(),
    );
  }

  /// 只有 [kOpenTab] 能进入；其余入口已置灰，任何跳转都忽略。
  void _goTab(int index) {
    if (index != kOpenTab || index == _index) return;
    setState(() => _index = index);
  }
}

/// 底部选项卡：第一格「看图找规律」带转圈光辉，其余三格置灰不可点。
class _TabBar extends StatelessWidget {
  const _TabBar();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        border: Border(
          top: BorderSide(color: scheme.outlineVariant, width: 0.6),
        ),
      ),
      child: const SafeArea(
        top: false,
        child: SizedBox(
          height: 70,
          child: Row(
            children: [
              _TabCell(
                icon: Icons.auto_awesome_rounded,
                label: '看图找规律',
                onTap: _noop,
                glow: true,
              ),
              _TabCell(icon: Icons.grid_view_outlined, label: '课程'),
              _TabCell(icon: Icons.leaderboard_outlined, label: '进度'),
              _TabCell(icon: Icons.person_outline_rounded, label: '我的'),
            ],
          ),
        ),
      ),
    );
  }

  static void _noop() {}
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
        Icon(icon, size: 24, color: color),
        const SizedBox(height: 3),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: _open ? FontWeight.w700 : FontWeight.w500,
            color: color,
          ),
        ),
      ],
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
                      radius: 16,
                      strokeWidth: 2,
                      period: const Duration(seconds: 2, milliseconds: 400),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        child: body,
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      child: body,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
