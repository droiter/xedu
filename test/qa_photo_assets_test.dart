import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xedu/features/pattern_quiz/pic_view.dart';
import 'package:xedu/features/qa_quiz/qa_bank.dart';

/// 只有算式符号还按字形画；其余 emoji 一律得有实拍素材。
const _textOnly = {'➕', '＝', '❓'};

void main() {
  final bank = QaBank.parse(
    File('assets/data/qa_questions.json').readAsStringSync(),
    File('assets/data/qa_voice.json').readAsStringSync(),
  );

  test('题库里用到的 emoji 都配了实拍素材', () {
    final missing = <String>{};
    void check(String e) {
      if (e.isEmpty || _textOnly.contains(e)) return;
      if (!kEmojiPhotos.containsKey(e)) missing.add(e);
    }

    for (final q in bank.questions) {
      for (final p in q.scene) {
        check(p.emoji);
        p.emojis.forEach(check);
      }
      for (final o in q.options) {
        final p = o.pic;
        if (p == null) continue;
        check(p.emoji);
        p.emojis.forEach(check);
      }
    }
    expect(missing, isEmpty, reason: '这些字形还没有实拍素材：$missing');
  });

  test('素材文件都在而且不是空文件', () {
    for (final entry in kEmojiPhotos.entries) {
      final f = File(entry.value);
      expect(f.existsSync(), isTrue, reason: '缺文件：${entry.value}');
      expect(f.lengthSync(), greaterThan(1024), reason: '文件可疑地小：${entry.value}');
    }
  });

  test('一个字形只指向一张图，没有重复条目', () {
    expect(kEmojiPhotos.values.toSet().length, kEmojiPhotos.length);
  });
}
