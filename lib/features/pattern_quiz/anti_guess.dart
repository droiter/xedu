import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../state/providers.dart';

/// 「防猜答案」开关（缺省开，家长在「我的 → 偏好设置」里管）。
///
/// 打开后，孩子每次答错都把正确答案挪到他刚点的那一格 —— 再点同一格就对。
/// 全机一份，两个答题页共用。
class QuizAntiGuessController extends Notifier<bool> {
  @override
  bool build() => ref.watch(prefsProvider).getBool(kQuizAntiGuessKey) ?? true;

  void set(bool value) {
    ref.read(prefsProvider).setBool(kQuizAntiGuessKey, value);
    state = value;
  }
}

final quizAntiGuessProvider =
    NotifierProvider<QuizAntiGuessController, bool>(QuizAntiGuessController.new);

/// 把 [answer] 放进第 [at] 格，[others] 按原次序填进剩下的格子。
///
/// 两个答题页答错后的重排都走这里：`others` 是已经打乱过的干扰项，只有
/// 「正确答案落在哪一格」被钉死。干扰项池太小、格子没那么多时退到最后一格。
List<T> withAnswerAt<T>(List<T> others, T answer, int at) {
  final slots = others.length + 1;
  final spot = at.clamp(0, slots - 1);
  final out = <T>[];
  var k = 0;
  for (var i = 0; i < slots; i++) {
    out.add(i == spot ? answer : others[k++]);
  }
  return out;
}
