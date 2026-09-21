import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../qa_quiz/qa_rate_chips.dart';
import '../qa_quiz/qa_speech.dart';
import '../video/video_manage_screen.dart';

/// 「我的」：账号、设置、关于、退出。
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _remind = true;
  bool _remindLoaded = false;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider.select((s) => s.user));
    final dark = ref.watch(themeControllerProvider);
    final lib = ref.watch(videoLibraryProvider);
    final rate = ref.watch(qaSpeechRateProvider);
    final readAloud = ref.watch(qaReadAloudProvider);
    final scheme = Theme.of(context).colorScheme;

    if (!_remindLoaded) {
      _remind = ref.read(prefsProvider).getBool(kRemindKey) ?? true;
      _remindLoaded = true;
    }

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
        children: [
          const Text('我的',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          if (user != null) _userCard(context, scheme, user),
          const SizedBox(height: 16),
          const _SectionLabel('视频'),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.video_library_outlined),
              title: const Text('我的视频'),
              subtitle: Text(
                lib.isEmpty
                    ? '新建分类，往里面添视频'
                    : '${lib.categories.length} 个分类 · ${lib.totalVideos} 个视频',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const VideoManageScreen()),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const _SectionLabel('偏好设置'),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.dark_mode_outlined),
                  title: const Text('深色模式'),
                  subtitle: const Text('夜间学习更护眼'),
                  value: dark,
                  onChanged: (v) =>
                      ref.read(themeControllerProvider.notifier).setDark(v),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.notifications_active_outlined),
                  title: const Text('学习提醒'),
                  subtitle: const Text('每日定时提醒我学习'),
                  value: _remind,
                  onChanged: (v) {
                    setState(() => _remind = v);
                    ref.read(prefsProvider).setBool(kRemindKey, v);
                  },
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.volume_up_outlined),
                  title: const Text('朗读题目和答案'),
                  subtitle: const Text('看图问答读题面和文字答案'),
                  value: readAloud,
                  onChanged: (v) =>
                      ref.read(qaReadAloudProvider.notifier).set(v),
                ),
                ListTile(
                  leading: const Icon(Icons.record_voice_over_outlined),
                  title: const Text('朗读语速'),
                  subtitle: Text('看图问答的朗读快慢 · 当前：${qaRateLabel(rate)}'),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: QaRateChips(),
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text('关于 xEdu'),
                  subtitle: const Text('版本 $kVersion'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showAbout(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _SectionLabel('账号'),
          Card(
            margin: EdgeInsets.zero,
            color: scheme.errorContainer.withOpacity(0.35),
            child: ListTile(
              leading: Icon(Icons.logout_rounded, color: scheme.error),
              title: Text('退出登录', style: TextStyle(color: scheme.error)),
              trailing: Icon(Icons.chevron_right_rounded, color: scheme.error),
              onTap: () => _confirmLogout(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _userCard(BuildContext context, ColorScheme scheme, User user) {
    final colors = [kBrand, const Color(0xFF9A5CFF)];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              shape: BoxShape.circle,
            ),
            child: Text(
              user.name.isNotEmpty ? user.name.substring(0, 1) : '同',
              style: const TextStyle(
                  color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(user.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.85), fontSize: 12.5)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('体验版',
                style: TextStyle(color: Colors.white, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: kAppName,
      applicationVersion: kVersion,
      applicationIcon: const Icon(Icons.school_rounded,
          size: 40, color: kBrand),
      children: const [
        Text(kAppTagline),
      ],
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出当前账号吗？学习进度会保存在本机。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('退出')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(authControllerProvider.notifier).logout();
    }
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(text,
          style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant)),
    );
  }
}
