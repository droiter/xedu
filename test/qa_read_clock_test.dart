import 'package:flutter_test/flutter_test.dart';
import 'package:xedu/features/qa_quiz/qa_models.dart';
import 'package:xedu/features/qa_quiz/qa_speech.dart';

/// 「六个」这个选项的真实时间轴：六 0.10~0.3875 秒，个 0.3875~0.6875 秒。
const List<QaSpan> _six = [
  QaSpan(0, 1, 0.1, 0.3875),
  QaSpan(1, 2, 0.3875, 0.6875),
];

/// 眼下该高亮第几个字；还没落到任何一段上时是 null。
int? _charAt(double media) {
  for (final s in _six) {
    if (media >= s.from && media < s.to) return s.start;
  }
  return media >= _six.last.to ? _six.last.end - 1 : null;
}

/// 跑一遍朗读，返回每一步高亮到的字，以及第一次对表发生在第几步（charAt 的下标）。
///
/// [speed] 是我们按档位推的语速，[actual] 是播放器实际推进的媒体秒/真实秒 ——
/// 不相等就是「声音没按我们以为的速度走」。计时表 40ms 走一格；播放器每 [poll]
/// 秒报一次位置，[startup] 是开播比计时表晚的秒数，[quantum] 是位置回调自己的
/// 台阶（报回来的位置一格一格地跳）。
(List<int> chars, int firstSync) _readAlong(double speed, double actual,
    {double poll = 0.2,
    double startup = 0.25,
    double quantum = 0.0,
    double seconds = 2.0}) {
  final clock = QaReadClock()..begin(speed);
  var elapsed = 0.0; // 计时表读数，每对一次表就归零
  var t = 0.0; // 真实时间
  var nextPoll = poll;
  var firstSync = -1;
  final chars = <int>[];
  while (t < seconds) {
    t += 0.04;
    elapsed += 0.04;
    if (t >= nextPoll - 1e-9) {
      nextPoll += poll;
      var media = (t - startup) * actual;
      if (media < 0) media = 0.0;
      if (quantum > 0) media = (media / quantum).floor() * quantum;
      if (clock.onPosition(media, elapsed)) {
        elapsed = 0;
        if (firstSync < 0) firstSync = chars.length;
      }
    }
    final c = _charAt(clock.media(elapsed));
    if (c != null) chars.add(c);
  }
  return (chars, firstSync);
}

/// 对表之后光标只许往前（对表那一下是有意往回拨的，不算）。
void _expectOnlyForward(List<int> chars, int firstSync) {
  expect(firstSync, isNonNegative, reason: '一次表都没对：$chars');
  for (var i = firstSync + 1; i < chars.length; i++) {
    expect(chars[i], greaterThanOrEqualTo(chars[i - 1]),
        reason: '光标从第 ${chars[i - 1]} 个字跳回了第 ${chars[i]} 个字：$chars');
  }
}

void main() {
  test('第一次收到真实位置：把开播延迟对上', () {
    final clock = QaReadClock()..begin(1.0);

    // 计时表已经走了 0.3 秒，声音才刚出声（位置 0.02 秒）：这一次往后拨。
    expect(clock.onPosition(0.02, 0.3), isTrue);
    expect(clock.media(0), closeTo(0.02, 1e-9));
    expect(clock.media(0.5), closeTo(0.52, 1e-9));
  });

  test('声音跑到表前面：跟上，别让高亮落在声音后面', () {
    final clock = QaReadClock()..begin(0.6);
    clock.onPosition(0.05, 0.2);

    // 表只推到 0.05 + 0.6×0.6 = 0.41，声音已经在 0.8 了。
    expect(clock.onPosition(0.8, 0.6), isTrue);
    expect(clock.media(0), closeTo(0.8, 1e-9));
  });

  test('声音落在表后面一点（回调自己的台阶）：不动表', () {
    final clock = QaReadClock()..begin(0.6);
    clock.onPosition(0.1, 0.2);

    // 表推到 0.1 + 0.4×0.6 = 0.34，声音才 0.25：差 0.09，是回调的台阶，不该拨。
    expect(clock.onPosition(0.25, 0.4), isFalse);
    expect(clock.media(0.4), closeTo(0.34, 1e-9));
  });

  test('声音比表慢（语速没送进播放器）：光标不在「六」「个」之间来回跳', () {
    // 复现 QA.L.DESC.COUNT.triangle-count 报的毛病：上一档 0.6、这一段却按 1.0 推表，
    // 于是每报一次位置就把表往回拨一下，光标在相邻两个字之间闪。
    final (chars, firstSync) = _readAlong(1.0, 0.6);

    _expectOnlyForward(chars, firstSync);
    expect(chars.last, 1, reason: '读完没落到「个」上：$chars');
  });

  test('位置回调带台阶、语速也不一致：光标照样只往前', () {
    for (final quantum in [0.05, 0.15, 0.3]) {
      final (chars, firstSync) = _readAlong(0.6, 0.6, quantum: quantum);
      _expectOnlyForward(chars, firstSync);
      expect(chars.last, 1, reason: '台阶 $quantum 秒时没读到最后：$chars');
    }
  });
}
