import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../shared/widgets/content_viewer.dart';
import '../../shared/widgets/course_card.dart';
import '../../shared/widgets/glow_border.dart';
import '../../state/providers.dart';
import '../course/course_detail_screen.dart';
import '../pattern_quiz/pattern_age_select_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, required this.onOpenTab});

  /// 通知外壳切换底部导航（0 首页 / 1 课程 / 2 进度）。
  final ValueChanged<int> onOpenTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider.select((s) => s.user));
    final catalogAsync = ref.watch(catalogProvider);

    return SafeArea(
      bottom: false,
      child: catalogAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('课程加载失败：$e')),
        data: (catalog) => _build(context, ref, user?.name ?? '同学', catalog),
      ),
    );
  }

  Widget _build(BuildContext context, WidgetRef ref, String name, CatalogData catalog) {
    final study = ref.watch(studyControllerProvider);
    final courses = catalog.courses;

    double progressOf(Course c) => study.courses.containsKey(c.id)
        ? study.courses[c.id]!.done.length / c.totalLessons
        : 0;

    final enrolled = courses.where((c) => study.courses.containsKey(c.id)).toList();
    final featuredIt = courses.where((c) => c.featured).iterator;
    final featured = featuredIt.moveNext() ? featuredIt.current : null;
    final fresh = courses.where((c) => !study.courses.containsKey(c.id)).take(6).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
      children: [
        _greeting(context, name),
        const SizedBox(height: 12),
        // 除「看图找规律」外的入口一律置灰保留，看得见但点不进去。
        _Locked(child: _searchBar(context)),
        const SizedBox(height: 8),
        if (featured != null)
          _Locked(child: _featuredBanner(context, featured)),
        _quizEntry(context),
        const SizedBox(height: 16),
        if (enrolled.isNotEmpty)
          _Locked(
            child: Column(
              children: [
                SectionHeader(
                    title: '继续学习',
                    actionText: '我的进度',
                    onAction: () => onOpenTab(2)),
                SizedBox(
                  height: 148,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: enrolled.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (_, i) => SizedBox(
                      width: 310,
                      child: CourseCard(
                        course: enrolled[i],
                        progress: progressOf(enrolled[i]),
                        onTap: () => _open(context, enrolled[i]),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (fresh.isNotEmpty)
          _Locked(
            child: Column(
              children: [
                SectionHeader(
                    title: '为你推荐',
                    actionText: '全部课程',
                    onAction: () => onOpenTab(1)),
                for (final c in fresh) ...[
                  CourseCard(course: c, onTap: () => _open(context, c)),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          )
        else ...[
          const SizedBox(height: 12),
          const EmptyHint(
            icon: Icons.school_outlined,
            text: '把感兴趣的课都学一遍吧',
            detail: '前往「课程」页浏览全部课程',
          ),
        ],
      ],
    );
  }

  Widget _greeting(BuildContext context, String name) {
    final hour = DateTime.now().hour;
    final greet = hour < 6
        ? '夜深了'
        : hour < 12
            ? '早上好'
            : hour < 18
                ? '下午好'
                : '晚上好';
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: scheme.primaryContainer,
          child: Text(name.isNotEmpty ? name.substring(0, 1) : '同',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: scheme.onPrimaryContainer)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$greet，$name',
                  style: const TextStyle(
                      fontSize: 19, fontWeight: FontWeight.w800)),
              Text('今天也要进步一点点哦',
                  style: TextStyle(
                      fontSize: 12.5, color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _searchBar(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => onOpenTab(1),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.search_rounded, color: Colors.grey),
              SizedBox(width: 10),
              Text('搜索想学的课程',
                  style: TextStyle(color: Colors.grey, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quizEntry(BuildContext context) {
    final colors = coverGradient('pattern-quiz');
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: GlowBorder(
        radius: 18,
        child: Material(
          clipBehavior: Clip.antiAlias,
          borderRadius: BorderRadius.circular(18),
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PatternAgeSelectScreen()),
            ),
            child: Ink(
              height: 86,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: colors,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.22),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.auto_awesome_rounded,
                          color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('看图找规律',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 3),
                          Text('选年龄（可多选） · 补全 4 格图找规律',
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.85),
                                  fontSize: 12.5)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        color: Colors.white.withOpacity(0.9), size: 28),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _featuredBanner(BuildContext context, Course course) {
    final colors = coverGradient(course.id);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Material(
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(20),
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _open(context, course),
          child: Ink(
            height: 150,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: colors,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.22),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('本周精选',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 11)),
                        ),
                        const SizedBox(height: 10),
                        Text(course.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 6),
                        Text('${course.teacher} · ${course.totalLessons} 节课',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.play_circle_fill_rounded,
                      color: Colors.white.withOpacity(0.9), size: 52),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context, Course course) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CourseDetailScreen(course: course),
    ));
  }
}

/// 置灰且不可点：入口仍然看得见，但点不进去。
class _Locked extends StatelessWidget {
  const _Locked({required this.child});

  final Widget child;

  // 去色矩阵（Rec. 709 亮度权重），让入口一眼看出是关着的。
  static const ColorFilter _grey = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 1, 0, //
  ]);

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Opacity(
        opacity: 0.42,
        child: ColorFiltered(colorFilter: _grey, child: child),
      ),
    );
  }
}
