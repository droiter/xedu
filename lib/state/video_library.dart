import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import 'prefs.dart';

/// 视频来源：网络链接 / 本机文件。
enum VideoKind { link, file }

/// 一个视频条目。[source] 对 [VideoKind.link] 是 http(s) 地址，
/// 对 [VideoKind.file] 是 App 私有目录下的本地绝对路径。
@immutable
class VideoItem {
  const VideoItem({
    required this.id,
    required this.title,
    required this.source,
    required this.kind,
  });

  factory VideoItem.fromJson(Map<String, dynamic> json) => VideoItem(
        id: json['id'] as String,
        title: json['title'] as String? ?? '未命名视频',
        source: json['source'] as String? ?? '',
        kind: json['kind'] == 'file' ? VideoKind.file : VideoKind.link,
      );

  final String id;
  final String title;
  final String source;
  final VideoKind kind;

  bool get isLocal => kind == VideoKind.file;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'source': source,
        'kind': kind.name,
      };
}

/// 一个视频分类，内含若干视频。
@immutable
class VideoCategory {
  const VideoCategory({
    required this.id,
    required this.name,
    this.videos = const [],
  });

  factory VideoCategory.fromJson(Map<String, dynamic> json) => VideoCategory(
        id: json['id'] as String,
        name: json['name'] as String? ?? '未命名分类',
        videos: [
          for (final v in (json['videos'] as List? ?? const []))
            VideoItem.fromJson((v as Map).cast<String, dynamic>()),
        ],
      );

  final String id;
  final String name;
  final List<VideoItem> videos;

  VideoCategory copyWith({String? name, List<VideoItem>? videos}) =>
      VideoCategory(
        id: id,
        name: name ?? this.name,
        videos: videos ?? this.videos,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'videos': [for (final v in videos) v.toJson()],
      };
}

/// 整份视频库。
@immutable
class VideoLibrary {
  const VideoLibrary({this.categories = const []});

  factory VideoLibrary.fromJson(Map<String, dynamic> json) => VideoLibrary(
        categories: [
          for (final c in (json['categories'] as List? ?? const []))
            VideoCategory.fromJson((c as Map).cast<String, dynamic>()),
        ],
      );

  final List<VideoCategory> categories;

  bool get isEmpty => categories.isEmpty;

  int get totalVideos =>
      categories.fold(0, (sum, c) => sum + c.videos.length);

  VideoCategory? byId(String id) {
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'categories': [for (final c in categories) c.toJson()],
      };
}

/// 视频库的增删改，落盘到 SharedPreferences（全机一份）。
class VideoLibraryController extends Notifier<VideoLibrary> {
  @override
  VideoLibrary build() => _load();

  VideoLibrary _load() {
    try {
      final raw = ref.read(prefsProvider).getString(kVideoLibraryKey);
      if (raw == null || raw.isEmpty) return const VideoLibrary();
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const VideoLibrary();
      return VideoLibrary.fromJson(decoded.cast<String, dynamic>());
    } catch (_) {
      return const VideoLibrary();
    }
  }

  Future<void> _save(VideoLibrary next) async {
    state = next;
    await ref
        .read(prefsProvider)
        .setString(kVideoLibraryKey, jsonEncode(next.toJson()));
  }

  /// 新建分类，返回新分类的 id。
  Future<String> addCategory(String name) async {
    final id = 'vc${DateTime.now().microsecondsSinceEpoch}';
    await _save(VideoLibrary(categories: [
      ...state.categories,
      VideoCategory(id: id, name: name.trim()),
    ]));
    return id;
  }

  Future<void> renameCategory(String categoryId, String name) async {
    await _save(VideoLibrary(categories: [
      for (final c in state.categories)
        c.id == categoryId ? c.copyWith(name: name.trim()) : c,
    ]));
  }

  /// 删除分类（连同分类里的视频记录）。
  Future<void> removeCategory(String categoryId) async {
    await _save(VideoLibrary(
      categories: [
        for (final c in state.categories)
          if (c.id != categoryId) c,
      ],
    ));
  }

  Future<void> addVideo(
    String categoryId, {
    required String title,
    required String source,
    VideoKind kind = VideoKind.link,
  }) async {
    final item = VideoItem(
      id: 'v${DateTime.now().microsecondsSinceEpoch}',
      title: title.trim().isEmpty ? '未命名视频' : title.trim(),
      source: source,
      kind: kind,
    );
    await _save(VideoLibrary(categories: [
      for (final c in state.categories)
        c.id == categoryId
            ? c.copyWith(videos: [...c.videos, item])
            : c,
    ]));
  }

  Future<void> removeVideo(String categoryId, String videoId) async {
    await _save(VideoLibrary(categories: [
      for (final c in state.categories)
        c.id == categoryId
            ? c.copyWith(
                videos: [
                  for (final v in c.videos)
                    if (v.id != videoId) v,
                ],
              )
            : c,
    ]));
  }
}

final videoLibraryProvider =
    NotifierProvider<VideoLibraryController, VideoLibrary>(
        VideoLibraryController.new);
