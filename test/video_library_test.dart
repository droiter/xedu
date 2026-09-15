import 'dart:convert';

import 'package:android_file_picker/android_file_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xedu/core/constants.dart';
import 'package:xedu/features/video/video_category_screen.dart';
import 'package:xedu/features/video/video_import.dart';
import 'package:xedu/features/video/video_library_screen.dart';
import 'package:xedu/features/video/video_manage_screen.dart';
import 'package:xedu/features/video/video_player_screen.dart';
import 'package:xedu/state/providers.dart';

/// 铺好内存版 SharedPreferences 的容器。
Future<ProviderContainer> _container(
    {Map<String, Object> seed = const {}}) async {
  SharedPreferences.setMockInitialValues(seed);
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(
    overrides: [prefsProvider.overrideWithValue(prefs)],
  );
  addTearDown(c.dispose);
  return c;
}

/// 预置一份视频库（1 个分类 2 个视频），返回分类 id。
String _seedLibraryJson() => jsonEncode({
      'categories': [
        {
          'id': 'vc1',
          'name': '动画片',
          'videos': [
            {
              'id': 'v1',
              'title': '小猪佩奇 第 1 集',
              'source': 'https://example.com/p1.mp4',
              'kind': 'link',
            },
            {
              'id': 'v2',
              'title': '汪汪队 第 2 集',
              'source': '/data/user/0/com.xedu.xedu/files/x.mp4',
              'kind': 'file',
            },
          ],
        },
      ],
    });

Future<Widget> _host(Widget child,
    {Map<String, Object> seed = const {}}) async {
  SharedPreferences.setMockInitialValues(seed);
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [prefsProvider.overrideWithValue(prefs)],
    child: MaterialApp(home: child),
  );
}

/// 页面里有入场动画，统一用显式 pump 推进，不用 pumpAndSettle。
/// 多推一帧是为了让路由真正从树上摘掉（动画跑完还要一帧才移除）。
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

/// 装一个 Android 选择器给回来的文件。[contentUri] 是 SAF 拿到的原始地址。
PlatformFile _pickedAndroid({required String name, String? contentUri}) =>
    AndroidPlatformFile.fromMap({
      'path': '/data/user/0/com.xedu.xedu/cache/file_picker/1757500000000/$name',
      'name': name,
      'size': 1024,
      if (contentUri != null)
        'safHandle': {'uri': contentUri, 'access': 'readOnly'},
    });

/// 把「问系统要文件名」那条通道换成固定答复；[answer] 为 null 表示问不出来。
void _mockNameChannel(String? answer) {
  const channel = MethodChannel('xedu/picker');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(channel, (call) async {
    expect(call.method, 'displayName');
    return answer;
  });
  addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
}

void main() {
  group('视频库状态', () {
    test('建分类、加视频、删视频、删分类都会落盘', () async {
      final c = await _container();
      final lib = c.read(videoLibraryProvider.notifier);

      expect(c.read(videoLibraryProvider).isEmpty, isTrue);

      final id = await lib.addCategory('动画片');
      await lib.addVideo(id, title: '小猪佩奇', source: 'https://a.com/1.mp4');
      await lib.addVideo(id,
          title: '汪汪队', source: '/tmp/x.mp4', kind: VideoKind.file);

      var snapshot = c.read(videoLibraryProvider);
      expect(snapshot.categories.single.name, '动画片');
      expect(snapshot.totalVideos, 2);
      expect(snapshot.categories.single.videos.last.isLocal, isTrue);

      await lib.removeVideo(id, snapshot.categories.single.videos.first.id);
      expect(c.read(videoLibraryProvider).totalVideos, 1);

      await lib.removeCategory(id);
      expect(c.read(videoLibraryProvider).isEmpty, isTrue);
    });

    test('重新读盘能还原分类与视频', () async {
      final c1 = await _container();
      final id = await c1.read(videoLibraryProvider.notifier).addCategory('儿歌');
      await c1.read(videoLibraryProvider.notifier).addVideo(id,
          title: '小星星', source: 'https://a.com/twinkle.mp4');

      // 同一份 prefs 换一个容器，相当于 App 重启后再读一次。
      final c2 = ProviderContainer(overrides: [
        prefsProvider.overrideWithValue(await SharedPreferences.getInstance()),
      ]);
      addTearDown(c2.dispose);

      final back = c2.read(videoLibraryProvider);
      expect(back.categories.single.name, '儿歌');
      expect(back.categories.single.videos.single.title, '小星星');
      expect(back.categories.single.videos.single.isLocal, isFalse);
    });

    test('空数据 / 脏数据不炸', () async {
      final c = await _container();
      expect(c.read(videoLibraryProvider).categories, isEmpty);

      SharedPreferences.setMockInitialValues({kVideoLibraryKey: '不是 json'});
      final dirty = ProviderContainer(overrides: [
        prefsProvider.overrideWithValue(await SharedPreferences.getInstance()),
      ]);
      addTearDown(dirty.dispose);
      expect(dirty.read(videoLibraryProvider).categories, isEmpty);
    });

    test('改名只动名字，视频还在', () async {
      final c = await _container();
      final lib = c.read(videoLibraryProvider.notifier);
      final id = await lib.addCategory('动画片');
      await lib.addVideo(id, title: '佩奇', source: 'https://a.com/1.mp4');

      await lib.renameCategory(id, '英文动画');
      final cat = c.read(videoLibraryProvider).categories.single;
      expect(cat.name, '英文动画');
      expect(cat.videos.single.title, '佩奇');
    });
  });

  group('「我的」里的视频管理页', () {
    testWidgets('新建分类 + 添加链接视频，列表立刻更新', (tester) async {
      await tester.pumpWidget(await _host(const VideoManageScreen()));
      await tester.pump();

      expect(find.text('还没有视频分类'), findsOneWidget);

      // 新建分类
      await tester.tap(find.text('新建分类'));
      await _settle(tester);
      await tester.enterText(find.byType(TextField), '动画片');
      await tester.tap(find.text('创建'));
      await _settle(tester);

      expect(find.text('动画片'), findsOneWidget);
      expect(find.text('0 个视频'), findsOneWidget);

      // 添加一个链接视频
      await tester.tap(find.text('添加视频'));
      await _settle(tester);
      await tester.tap(find.text('粘贴视频链接'));
      await _settle(tester);

      await tester.enterText(find.byType(TextField).at(0), '小猪佩奇 第 1 集');
      await tester.enterText(find.byType(TextField).at(1), 'https://a.com/p1.mp4');
      await tester.tap(find.text('添加'));
      await _settle(tester);

      expect(find.text('小猪佩奇 第 1 集'), findsOneWidget);
      expect(find.text('1 个视频'), findsOneWidget);
    });

    testWidgets('链接格式不对时不给加', (tester) async {
      await tester.pumpWidget(
          await _host(const VideoManageScreen(), seed: {kVideoLibraryKey: _seedLibraryJson()}));
      await tester.pump();

      await tester.tap(find.text('添加视频'));
      await _settle(tester);
      await tester.tap(find.text('粘贴视频链接'));
      await _settle(tester);

      await tester.enterText(find.byType(TextField).at(1), '随便写点什么');
      await tester.tap(find.text('添加'));
      await _settle(tester);

      expect(find.text('请填以 http:// 或 https:// 开头的地址'), findsOneWidget);
    });

    testWidgets('建完一个分类后，列表里还能再建一个', (tester) async {
      await tester.pumpWidget(await _host(const VideoManageScreen(),
          seed: {kVideoLibraryKey: _seedLibraryJson()}));
      await tester.pump();

      // 只剩 AppBar 上一个小图标的话，家长会以为只能建一个分类。
      await tester.ensureVisible(find.text('新建分类'));
      await tester.pump();
      await tester.tap(find.text('新建分类'));
      await _settle(tester);
      await tester.enterText(find.byType(TextField), '儿歌');
      await tester.tap(find.text('创建'));
      await _settle(tester);

      expect(find.text('动画片'), findsOneWidget);
      expect(find.text('儿歌'), findsOneWidget);
    });

    testWidgets('重命名分类时预填原名，并整段选中', (tester) async {
      await tester.pumpWidget(await _host(const VideoManageScreen(),
          seed: {kVideoLibraryKey: _seedLibraryJson()}));
      await tester.pump();

      await tester.tap(find.byTooltip('分类操作'));
      await _settle(tester);
      await tester.tap(find.text('重命名'));
      await _settle(tester);

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, '动画片');
      expect(field.controller!.selection,
          const TextSelection(baseOffset: 0, extentOffset: 3));
    });

    testWidgets('删掉视频后分类里就没了', (tester) async {
      await tester.pumpWidget(await _host(const VideoManageScreen(),
          seed: {kVideoLibraryKey: _seedLibraryJson()}));
      await tester.pump();

      expect(find.text('小猪佩奇 第 1 集'), findsOneWidget);
      await tester.tap(find.byTooltip('删除视频').first);
      await _settle(tester);
      await tester.tap(find.text('删除'));
      await _settle(tester);

      expect(find.text('小猪佩奇 第 1 集'), findsNothing);
      expect(find.text('汪汪队 第 2 集'), findsOneWidget);
      expect(find.text('1 个视频'), findsOneWidget);
    });
  });

  group('「看视频」选项卡', () {
    testWidgets('没有视频时给引导，点按钮回「我的」', (tester) async {
      var jumped = false;
      await tester.pumpWidget(await _host(
        VideoLibraryScreen(onOpenManage: () => jumped = true),
      ));
      await tester.pump();

      expect(find.text('还没有视频'), findsOneWidget);
      await tester.tap(find.text('去添加视频'));
      await tester.pump();
      expect(jumped, isTrue);
    });

    testWidgets('看到「我的」里建好的分类，点进去看到视频', (tester) async {
      await tester.pumpWidget(await _host(
        VideoLibraryScreen(onOpenManage: () {}),
        seed: {kVideoLibraryKey: _seedLibraryJson()},
      ));
      await tester.pump();

      expect(find.text('动画片'), findsOneWidget);
      expect(find.text('2 个视频'), findsOneWidget);

      await tester.tap(find.text('动画片'));
      await _settle(tester);

      expect(find.byType(VideoCategoryScreen), findsOneWidget);
      expect(find.text('小猪佩奇 第 1 集'), findsOneWidget);
      expect(find.text('汪汪队 第 2 集'), findsOneWidget);
      expect(find.text('本机'), findsOneWidget); // 本地视频的标记
      expect(find.text('网络'), findsOneWidget);
    });

    testWidgets('手机窄屏下分类卡不溢出', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(await _host(
        VideoLibraryScreen(onOpenManage: () {}),
        seed: {kVideoLibraryKey: _seedLibraryJson()},
      ));
      await tester.pump();

      expect(find.text('动画片'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('分类被删掉后列表不再显示它', (tester) async {
      final c = await _container(seed: {kVideoLibraryKey: _seedLibraryJson()});
      await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: MaterialApp(home: VideoLibraryScreen(onOpenManage: () {})),
      ));
      await tester.pump();
      expect(find.text('动画片'), findsOneWidget);

      await c.read(videoLibraryProvider.notifier).removeCategory('vc1');
      await tester.pump();
      expect(find.text('动画片'), findsNothing);
    });
  });

  group('播放页', () {
    testWidgets('点视频进播放页，按返回键随时退回（没有家长验证）', (tester) async {
      await tester.pumpWidget(await _host(
        const VideoCategoryScreen(categoryId: 'vc1'),
        seed: {kVideoLibraryKey: _seedLibraryJson()},
      ));
      await tester.pump();

      await tester.tap(find.text('小猪佩奇 第 1 集'));
      await _settle(tester);

      expect(find.byType(VideoPlayerScreen), findsOneWidget);
      // 测试环境里没有真正的播放器实现，会落到「播放失败」兜底——这没关系，
      // 这里要确认的是返回键不被拦。
      expect(find.byType(PopScope), findsNothing);

      await tester.pageBack();
      await _settle(tester);

      expect(find.byType(VideoPlayerScreen), findsNothing);
      expect(find.byType(VideoCategoryScreen), findsOneWidget);
    });

    testWidgets('本地文件不存在时给出提示和重试', (tester) async {
      await tester.pumpWidget(await _host(
        const VideoPlayerScreen(
          video: VideoItem(
            id: 'v9',
            title: '丢了的视频',
            source: '/nowhere/none.mp4',
            kind: VideoKind.file,
          ),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('打不开了'), findsOneWidget);
      expect(find.text('重试'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('视频名字（预填）', () {
    test('文件名去掉后缀；拿不到文件名就用「视频 N」占位', () {
      expect(videoNameFromFileName('小猪佩奇 01.mp4'), '小猪佩奇 01');
      expect(videoNameFromFileName('汪汪队'), '汪汪队');
      expect(defaultVideoName('小猪佩奇 01.mp4', 3), '小猪佩奇 01');
      expect(defaultVideoName('', 3), '视频 3');
    });

    test('选择器给的是编号时，自己再问一次系统', () async {
      _mockNameChannel('小猪佩奇 01.mp4');
      final f = _pickedAndroid(
        name: '1000000033',
        contentUri: 'content://media/external/video/media/1234',
      );
      expect(await resolveVideoName(f), '小猪佩奇 01.mp4');
    });

    test('问不到系统就退回选择器给的正常文件名', () async {
      _mockNameChannel(null);
      final f = _pickedAndroid(
        name: '汪汪队.mp4',
        contentUri: 'content://media/external/video/media/1234',
      );
      expect(await resolveVideoName(f), '汪汪队.mp4');
    });

    test('编号、unamed 这种都不算名字', () async {
      _mockNameChannel(null);
      expect(await resolveVideoName(_pickedAndroid(name: '1000000033')), '');
      expect(await resolveVideoName(_pickedAndroid(name: 'unamed')), '');
      expect(await resolveVideoName(_pickedAndroid(name: 'video:1234')), '');
    });

    test('平台上没接这条通道也不炸', () async {
      // 不设 mock：真机上没有对应实现时走的就是这条路。
      final f = _pickedAndroid(
        name: '汪汪队.mp4',
        contentUri: 'content://media/external/video/media/1234',
      );
      expect(await resolveVideoName(f), '汪汪队.mp4');
    });
  });

  group('播放页布局', () {
    testWidgets('高视频不会把控制条顶出屏幕（那里会被系统导航条盖住）',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: PlayerStage(
              aspectRatio: 9 / 16,
              video: ColoredBox(
                key: ValueKey('stage-video'),
                color: Colors.blue,
              ),
              controls: SizedBox(
                height: 92,
                child: Center(child: Text('控制条')),
              ),
            ),
          ),
        ),
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(tester.getRect(find.text('控制条')).bottom, lessThanOrEqualTo(1000));
      // 竖屏画面按剩下的高度缩下来，整幅都在屏幕里。
      final video = tester.getRect(find.byKey(const ValueKey('stage-video')));
      expect(video.height, greaterThan(400));
      expect(video.bottom, lessThanOrEqualTo(1000));
    });
  });
}
