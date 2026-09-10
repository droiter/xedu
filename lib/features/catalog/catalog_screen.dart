import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../shared/widgets/content_viewer.dart' show EmptyHint;
import '../../shared/widgets/course_card.dart';
import '../../state/providers.dart';
import '../course/course_detail_screen.dart';

/// 全部课程：搜索 + 分类筛选 + 手机列表 / 平板宫格。
class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({super.key});

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  final _search = TextEditingController();
  String? _category; // null = 全部

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalogAsync = ref.watch(catalogProvider);

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: '搜索课程、老师或关键词',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () {
                                _search.clear();
                                setState(() {});
                              },
                            ),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: catalogAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('课程加载失败：$e')),
              data: (catalog) => _content(context, catalog),
            ),
          ),
        ],
      ),
    );
  }

  Widget _content(BuildContext context, CatalogData catalog) {
    final study = ref.watch(studyControllerProvider);
    final categories = catalog.categories;

    final query = _search.text.trim().toLowerCase();
    final filtered = catalog.courses.where((c) {
      final inCat = _category == null || c.categoryId == _category;
      final inQuery = query.isEmpty ||
          c.title.toLowerCase().contains(query) ||
          c.subtitle.toLowerCase().contains(query) ||
          c.teacher.toLowerCase().contains(query);
      return inCat && inQuery;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            children: [
              _filterChip(context, null, '全部'),
              for (final cat in categories) _filterChip(context, cat.id, cat.name),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 2, 18, 8),
          child: Text('共 ${filtered.length} 门课程',
              style: TextStyle(
                  fontSize: 12.5, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ),
        Expanded(
          child: filtered.isEmpty
              ? EmptyHint(
                  icon: Icons.search_off_rounded,
                  text: '没有找到匹配的课程',
                  detail: '换个关键词或分类试试')
              : LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 700) {
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => _card(context, filtered[i], study),
                      );
                    }
                    final cols = constraints.maxWidth >= 1000 ? 3 : 2;
                    return GridView.builder(
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        mainAxisExtent: 130,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) => _card(context, filtered[i], study),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _filterChip(BuildContext context, String? id, String label) {
    final selected = _category == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _category = id),
        showCheckmark: false,
      ),
    );
  }

  Widget _card(BuildContext context, Course course, StudyState study) {
    final cs = study.courses[course.id];
    final progress = cs == null ? null : cs.done.length / course.totalLessons;
    return CourseCard(
      course: course,
      progress: progress,
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CourseDetailScreen(course: course),
      )),
    );
  }
}
