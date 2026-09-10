import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models.dart';

const String _catalogAsset = 'assets/data/courses.json';

Future<CatalogData> _loadCatalog() async {
  final raw = await rootBundle.loadString(_catalogAsset);
  return CatalogData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

/// 课程目录（首次读取后缓存）。
final catalogProvider = FutureProvider<CatalogData>((ref) => _loadCatalog());
