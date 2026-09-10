import 'package:flutter/foundation.dart';

/// 用户账号。
@immutable
class User {
  const User({required this.id, required this.name, required this.email});

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
      );

  final String id;
  final String name;
  final String email;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'email': email};
}

/// 认证状态。
@immutable
class AuthState {
  const AuthState({this.user});

  final User? user;

  bool get isLoggedIn => user != null;
}

/// 课程分类。
@immutable
class Category {
  const Category({required this.id, required this.name, required this.icon});

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: json['id'] as String,
        name: json['name'] as String,
        icon: json['icon'] as String,
      );

  final String id;
  final String name;
  final String icon;
}

/// 内容块类型。
enum BlockKind { heading, text, tip, list }

/// 一节课正文内容块。
@immutable
class ContentBlock {
  const ContentBlock({required this.kind, this.text, this.items = const []});

  factory ContentBlock.fromJson(Map<String, dynamic> json) {
    final kind = BlockKind.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => BlockKind.text,
    );
    return ContentBlock(
      kind: kind,
      text: json['text'] as String?,
      items: (json['items'] as List?)?.map((e) => e as String).toList() ?? const [],
    );
  }

  final BlockKind kind;
  final String? text;
  final List<String> items;
}

/// 单选题。
@immutable
class QuizQuestion {
  const QuizQuestion({
    required this.stem,
    required this.options,
    required this.answer,
    this.explanation,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) => QuizQuestion(
        stem: json['stem'] as String,
        options: (json['options'] as List).map((e) => e as String).toList(),
        answer: (json['answer'] as num).toInt(),
        explanation: json['explanation'] as String?,
      );

  final String stem;
  final List<String> options;
  final int answer; // 正确项下标
  final String? explanation;
}

/// 一节课。
@immutable
class Lesson {
  const Lesson({
    required this.id,
    required this.title,
    required this.durationMin,
    this.videoUrl,
    this.blocks = const [],
    this.quiz = const [],
  });

  factory Lesson.fromJson(Map<String, dynamic> json) => Lesson(
        id: json['id'] as String,
        title: json['title'] as String,
        durationMin: (json['durationMin'] as num?)?.toInt() ?? 0,
        videoUrl: json['videoUrl'] as String?,
        blocks: (json['blocks'] as List?)
                ?.map((e) => ContentBlock.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        quiz: (json['quiz'] as List?)
                ?.map((e) => QuizQuestion.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );

  final String id;
  final String title;
  final int durationMin;
  final String? videoUrl;
  final List<ContentBlock> blocks;
  final List<QuizQuestion> quiz;

  bool get hasVideo => videoUrl != null && videoUrl!.isNotEmpty;
  bool get hasQuiz => quiz.isNotEmpty;
}

/// 章。
@immutable
class CourseChapter {
  const CourseChapter({required this.id, required this.title, required this.lessons});

  factory CourseChapter.fromJson(Map<String, dynamic> json) => CourseChapter(
        id: json['id'] as String,
        title: json['title'] as String,
        lessons: (json['lessons'] as List)
            .map((e) => Lesson.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final String id;
  final String title;
  final List<Lesson> lessons;
}

/// 课程。
@immutable
class Course {
  const Course({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.categoryId,
    required this.teacher,
    required this.level,
    required this.coverSeed,
    required this.featured,
    required this.chapters,
  });

  factory Course.fromJson(Map<String, dynamic> json) => Course(
        id: json['id'] as String,
        title: json['title'] as String,
        subtitle: json['subtitle'] as String? ?? '',
        description: json['description'] as String? ?? '',
        categoryId: json['categoryId'] as String,
        teacher: json['teacher'] as String? ?? '',
        level: json['level'] as String? ?? '初级',
        coverSeed: (json['coverSeed'] as num?)?.toInt() ?? 0,
        featured: json['featured'] as bool? ?? false,
        chapters: (json['chapters'] as List? ?? const [])
            .map((e) => CourseChapter.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final String id;
  final String title;
  final String subtitle;
  final String description;
  final String categoryId;
  final String teacher;
  final String level;
  final int coverSeed;
  final bool featured;
  final List<CourseChapter> chapters;

  List<Lesson> get lessons =>
      chapters.expand((c) => c.lessons).toList(growable: false);

  int get totalLessons => lessons.length;

  int get totalMinutes =>
      lessons.fold(0, (sum, l) => sum + l.durationMin);

  int get chapterCount => chapters.length;
}

/// 整个课程目录。
class CatalogData {
  const CatalogData({required this.categories, required this.courses});

  factory CatalogData.fromJson(Map<String, dynamic> json) => CatalogData(
        categories: (json['categories'] as List? ?? const [])
            .map((e) => Category.fromJson(e as Map<String, dynamic>))
            .toList(),
        courses: (json['courses'] as List? ?? const [])
            .map((e) => Course.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final List<Category> categories;
  final List<Course> courses;

  Course? courseById(String id) {
    for (final c in courses) {
      if (c.id == id) return c;
    }
    return null;
  }

  Category? categoryOf(Course course) {
    for (final c in categories) {
      if (c.id == course.categoryId) return c;
    }
    return null;
  }
}
