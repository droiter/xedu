import 'package:flutter_test/flutter_test.dart';
import 'package:xedu/shared/reward_rule.dart';

void main() {
  group('黑屏秒数', () {
    test('第一次 X 秒，每错一次多 1 秒，涨到 Y 秒就不再加', () {
      int at(int count) =>
          blackoutSeconds(count: count, firstSeconds: 3, maxSeconds: 5);
      expect(at(1), 3);
      expect(at(2), 4);
      expect(at(3), 5);
      expect(at(4), 5);
      expect(at(99), 5);
    });

    test('Y 比 X 还小时按 X 封顶：惩罚不能越往后越轻', () {
      expect(blackoutSeconds(count: 1, firstSeconds: 6, maxSeconds: 5), 6);
      expect(blackoutSeconds(count: 3, firstSeconds: 6, maxSeconds: 5), 6);
    });

    test('还没开始黑屏（第 0 次）是 0 秒', () {
      expect(blackoutSeconds(count: 0, firstSeconds: 3, maxSeconds: 5), 0);
    });
  });

  group('奖励能看几秒', () {
    int watch(int index, {int video = 600, int step = 30, int min = 30}) =>
        rewardWatchSeconds(
          videoSeconds: video,
          rewardIndex: index,
          stepSeconds: step,
          minSeconds: min,
        );

    test('第一次看完整片', () {
      expect(watch(1), 600);
    });

    test('之后每次少 A 秒，直到 B 秒封顶不再减', () {
      expect(watch(2), 570);
      expect(watch(3), 540);
      expect(watch(20), 30);
      expect(watch(50), 30);
    });

    test('片子本身比 B 还短时不会因为 B 反而变长', () {
      expect(watch(5, video: 12), 12);
      expect(watch(1, video: 12), 12);
    });

    test('把 A 填成 0 就是每次都看完整片', () {
      expect(watch(3, step: 1, min: 600), 600);
    });
  });

  group('奖励额度', () {
    test('第一次是整片，之后的额度按 A / B 算出来', () {
      const first = RewardWatchLimit(index: 1, stepSeconds: 30, minSeconds: 30);
      const later = RewardWatchLimit(index: 2, stepSeconds: 30, minSeconds: 30);
      expect(first.isFull, isTrue);
      expect(later.isFull, isFalse);
      expect(first.limitFor(const Duration(minutes: 10)),
          const Duration(minutes: 10));
      expect(later.limitFor(const Duration(minutes: 10)),
          const Duration(minutes: 9, seconds: 30));
    });
  });
}
