import 'dart:io';

import 'package:android_file_picker/android_file_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// 本机视频复制到 App 私有目录后存放的子目录名。
///
/// 不直接用选择器返回的缓存路径：缓存会被系统清掉，孩子过几天就打不开了。
const String kVideoDirName = 'xedu_videos';

/// 问系统要文件显示名的通道，实现在 android/.../MainActivity.kt。
const MethodChannel _nameChannel = MethodChannel('xedu/picker');

/// 用户挑中的一个本机视频。[name] 是能问到的显示名，问不到时是空串。
class PickedVideo {
  const PickedVideo({required this.name, required this.path});

  final String name;
  final String path;
}

/// 打开系统文件选择器挑视频，可以一次多选；取消或一个路径都拿不到时返回空列表。
Future<List<PickedVideo>> pickLocalVideos() async {
  // 带上 SAF 选项，选择器才会把原始 content:// 地址一起给回来，
  // 后面自己查文件名要靠它。
  final files = await FilePicker.pickFiles(
    type: FileType.video,
    androidOptions: const FilePickerAndroidOptions(),
  );
  final picked = <PickedVideo>[];
  for (final f in files) {
    final path =
        f.path ?? (f.uri.scheme == 'file' ? f.uri.toFilePath() : null);
    if (path == null) continue;
    picked.add(PickedVideo(name: await resolveVideoName(f), path: path));
  }
  return picked;
}

/// 文件名去掉后缀，当视频名字的默认值。
String videoNameFromFileName(String fileName) {
  final dot = fileName.lastIndexOf('.');
  final base = dot > 0 ? fileName.substring(0, dot) : fileName;
  return base.trim();
}

/// 视频名字的默认值：文件名去掉后缀；实在问不到就用「视频 N」占位。
String defaultVideoName(String pickedName, int index) {
  final name = videoNameFromFileName(pickedName);
  return name.isEmpty ? '视频 $index' : name;
}

/// 挑中的文件 → 记进视频库的名字。
///
/// 先问自己写的系统查询，再退回选择器给的 [PlatformFile.name]：选择器给的名字
/// 在有些机器上并不是文件名，而是内容提供者那边的编号
/// （`content://media/.../1234` 的最后一段），家长看了完全对不上。
Future<String> resolveVideoName(PlatformFile f) async {
  final safUri = f is AndroidPlatformFile ? f.safHandle?.uri : null;
  if (safUri != null) {
    final system = await _systemDisplayName(safUri);
    if (system != null) return system;
  }
  return _meaningful(f.name) ? f.name.trim() : '';
}

Future<String?> _systemDisplayName(Uri uri) async {
  try {
    final name = await _nameChannel
        .invokeMethod<String>('displayName', {'uri': uri.toString()});
    return _meaningful(name) ? name!.trim() : null;
  } catch (_) {
    // 平台上没接这个通道（测试、桌面）或者查询出错，都当没问到。
    return null;
  }
}

/// 内部编号、`unamed` 这类名字对家长没有意义，当成没拿到。
bool _meaningful(String? raw) {
  final name = raw?.trim() ?? '';
  if (name.isEmpty || name.contains(':')) return false;
  final lower = name.toLowerCase();
  if (lower == 'unamed' || lower == 'unnamed') return false;
  // 纯数字的一长串多半是编号或时间戳，不是家长认得的文件名。
  return !RegExp(r'^\d{6,}$').hasMatch(videoNameFromFileName(name));
}

/// 把挑中的视频复制进 App 私有目录，返回可长期播放的绝对路径。
Future<String> importLocalVideo(PickedVideo picked) async {
  final dir = Directory(
      '${(await getApplicationDocumentsDirectory()).path}/$kVideoDirName');
  if (!dir.existsSync()) await dir.create(recursive: true);
  final dest = '${dir.path}/${DateTime.now().microsecondsSinceEpoch}'
      '_${_safeFileName(picked.name)}';
  await File(picked.path).copy(dest);
  await _dropPickerCacheCopy(picked.path);
  return dest;
}

/// 从视频库里移除本地视频时顺带删掉文件，避免留下孤儿。
Future<void> deleteLocalVideoFile(String path) async {
  try {
    final f = File(path);
    if (f.existsSync()) await f.delete();
  } catch (_) {
    // 文件删不掉不影响「从列表里移除」这件事。
  }
}

/// 选择器会把 SAF 选中的文件复制一份到自己的缓存目录，导入完就没用了。
/// 只删我们自己缓存目录里的副本——万一拿到的是用户真实路径，绝不能碰。
Future<void> _dropPickerCacheCopy(String sourcePath) async {
  try {
    final cache = (await getTemporaryDirectory()).path;
    if (sourcePath.startsWith(cache)) await File(sourcePath).delete();
  } catch (_) {
    // 清缓存失败无所谓，系统迟早会回收。
  }
}

/// 只保留文件名部分，并去掉路径分隔符等非法字符。
String _safeFileName(String name) {
  final base = name.split(RegExp(r'[/\\]')).last.trim();
  final cleaned = base.replaceAll(RegExp(r'[<>:"|?*\x00-\x1f]'), '_');
  return cleaned.isEmpty ? 'video.mp4' : cleaned;
}
