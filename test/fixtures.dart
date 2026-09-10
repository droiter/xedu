import 'package:xedu/data/models.dart';

/// 构造一份两节课、带随堂测验的最小课程 JSON。
Map<String, dynamic> sampleCourseJson() => {
      'id': 'c-sample',
      'title': '样例课程',
      'subtitle': '用于测试',
      'description': '说明',
      'categoryId': 'code',
      'teacher': '老师',
      'level': '初级',
      'coverSeed': 0,
      'featured': false,
      'chapters': [
        {
          'id': 'ch1',
          'title': '第一章',
          'lessons': [
            {
              'id': 'l1',
              'title': '第一课',
              'durationMin': 5,
              'videoUrl': '',
              'blocks': [
                {'type': 'heading', 'text': '开始'},
                {'type': 'text', 'text': '正文'},
                {'type': 'list', 'items': ['要点一', '要点二']},
              ],
            },
            {
              'id': 'l2',
              'title': '第二课（测验）',
              'durationMin': 10,
              'blocks': [],
              'quiz': [
                {
                  'stem': '1 + 1 = ?',
                  'options': ['2', '3'],
                  'answer': 0,
                  'explanation': '因为二',
                }
              ],
            },
          ],
        }
      ],
    };

Map<String, dynamic> sampleCatalogJson() => {
      'categories': [
        {'id': 'code', 'name': '编程开发', 'icon': 'code'},
      ],
      'courses': [sampleCourseJson()],
    };

Course sampleCourse() => Course.fromJson(sampleCourseJson());
