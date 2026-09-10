import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';

class _Slide {
  const _Slide(this.icon, this.title, this.subtitle, this.colors);
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> colors;
}

const List<_Slide> _slides = [
  _Slide(Icons.tablet_mac_rounded, '手机和平板都能学',
      '一套课程，在手机上随手刷，在平板上专心学，进度自动同步。',
      [Color(0xFF4F6BFF), Color(0xFF9A5CFF)]),
  _Slide(Icons.menu_book_rounded, '课程 · 讲义 · 测验',
      '从章节讲义到随堂测验，学完即测，薄弱点一目了然。',
      [Color(0xFF00B8A9), Color(0xFF0F8B8D)]),
  _Slide(Icons.emoji_events_rounded, '记录每一份努力',
      '连续打卡、学习时长、课程进度，看着自己一点点变强。',
      [Color(0xFFFF7043), Color(0xFFFF3D6E)]),
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish() {
    ref.read(onboardingControllerProvider.notifier).markSeen();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final last = _index == _slides.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: _finish, child: const Text('跳过')),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) => _SlideView(data: _slides[i]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
              child: Row(
                children: [
                  for (var i = 0; i < _slides.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 6),
                      width: i == _index ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _index ? scheme.primary : scheme.outlineVariant,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: last
                        ? _finish
                        : () => _controller.nextPage(
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOut),
                    child: Text(last ? '开始学习' : '下一步'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.data});

  final _Slide data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: data.colors,
              ),
              boxShadow: [
                BoxShadow(
                  color: data.colors.last.withOpacity(0.35),
                  blurRadius: 32,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Icon(data.icon, color: Colors.white, size: 84),
          ),
          const SizedBox(height: 48),
          Text(data.title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          Text(
            data.subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 15, height: 1.7, color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
