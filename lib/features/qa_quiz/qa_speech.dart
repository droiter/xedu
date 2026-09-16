import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../state/providers.dart';
import 'qa_models.dart';

/// 问答题的朗读播放器：放题面 / 选项的预生成语音，并把播放进度换算成
/// 「现在读到第几个字」，供文字跟读高亮使用。
///
/// 音频打包进 App，运行时不联网。高亮不用音频做实时分析，而是读预生成时
/// 记下的逐词时间轴（见 `scripts/gen_qa_voice.py`），所以又准又省电。
///
/// 计时靠 [Stopwatch] 推（40ms 一跳，比位置回调细腻得多），但**播放启动有延迟**，
/// 所以每收到一次真实播放位置就校准一次，高亮不会越跑越偏。
class QaSpeech {
  QaSpeech._();

  static final QaSpeech instance = QaSpeech._();

  /// 语速上下限，和 UI 上的档位保持一致。
  static const double minRate = 0.6;
  static const double maxRate = 1.4;

  /// 正在播放的片段键（题面 = 题号，选项 = 题号.o2）；没在播时为 null。
  final ValueNotifier<String?> speaking = ValueNotifier<String?>(null);

  /// 当前正在读的字符区间；没在读时为 null。
  final ValueNotifier<QaSpan?> activeSpan = ValueNotifier<QaSpan?>(null);

  final AudioPlayer _player = AudioPlayer(playerId: 'xedu_qa_voice');

  /// 播放语速，1.0 为原速。由 [QaSpeedController] 写入。
  double rate = 1.0;

  StreamSubscription<Duration>? _posSub;
  StreamSubscription<void>? _doneSub;
  List<QaSpan> _spans = const [];
  String? _key;
  QaVoiceClip? _clip;
  Timer? _ticker;
  Timer? _stopAt;
  final Stopwatch _clock = Stopwatch();

  /// 本段的语速。
  double _speed = 1.0;

  /// 已经**确认**走过的媒体时间（秒），加上表走的这段就是当前媒体时间。
  double _base = 0.0;

  /// 语速是否已经下发过（Android 上只有播放中设才生效，所以要等真的出声）。
  bool _rateSent = false;

  /// 当前媒体时间（秒）。媒体时间不受语速影响，和语音时间轴同一把尺子。
  double get _media => _base + _clock.elapsedMicroseconds / 1e6 * _speed;

  /// 开始监听播放事件。任何环节失败都不抛出去 —— 朗读是锦上添花，
  /// 设备放不出声时不能把答题也带崩。
  Future<void> init() async {
    try {
      _doneSub ??= _player.onPlayerComplete.listen((_) => _finish());
      await _player.setReleaseMode(ReleaseMode.stop);
    } catch (e) {
      debugPrint('QaSpeech: 播放器初始化失败：$e');
    }
  }

  /// 朗读 [clip]。[key] 用来在 UI 上标记「是哪一条在读」。
  ///
  /// 出错只降级成「这一遍没声音」，不清空 [speaking] 以外的状态、也不永久停用 ——
  /// 下一题还会再试一次。
  Future<void> speak(String key, QaVoiceClip clip,
      {double? rateOverride}) async {
    final speed = (rateOverride ?? rate).clamp(minRate, maxRate);
    await init();
    await stop();

    _key = key;
    _clip = clip;
    _spans = clip.spans;
    _speed = speed;
    _base = 0;
    _rateSent = false;
    speaking.value = key;
    activeSpan.value = null;

    try {
      _posSub = _player.onPositionChanged.listen(_onPosition, onError: (_) {});
      await _player.play(AssetSource(clip.asset));
    } catch (e) {
      debugPrint('QaSpeech: 播放失败，这一段静音：$e');
      _finish();
      return;
    }

    _clock
      ..reset()
      ..start();
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 40), (_) => _tick());

    // 末尾有半秒多的静音，读完就停，不用等它播完。
    _stopAt?.cancel();
    _stopAt = Timer(
      Duration(milliseconds: ((clip.voiced / speed) * 1000).round() + 280),
      _finish,
    );
  }

  /// 真实播放位置回调：≈200ms 一次，是「声音真的走到这儿了」的唯一可靠信号。
  void _onPosition(Duration pos) {
    final media = pos.inMicroseconds / 1e6;
    if (media <= 0) return; // 0 表示还没真的出声

    if (!_rateSent) {
      _rateSent = true;
      unawaited(_applyRate());
    }
    // 拿真实位置校准计时表，把「开播延迟」抹掉；差得少就不动，免得高亮抖。
    if ((media - _media).abs() > 0.12) {
      _base = media;
      _clock
        ..reset()
        ..start();
    }
  }

  void _tick() {
    // 位置回调迟迟不来时的兜底：到点就先把语速设上。
    if (!_rateSent && _clock.elapsedMilliseconds > 350) {
      _rateSent = true;
      unawaited(_applyRate());
    }

    final media = _media;
    QaSpan? hit;
    for (final s in _spans) {
      if (media >= s.from && media < s.to) {
        hit = s;
        break;
      }
    }
    // 读完最后一个字之后、音频还没停的这段时间，保持最后一段高亮不闪。
    if (hit == null && _spans.isNotEmpty && media >= _spans.last.to) {
      hit = _spans.last;
    }
    if (!identical(hit, activeSpan.value)) activeSpan.value = hit;
  }

  /// 下发语速。
  ///
  /// Android 侧是 `if (playing) player.setRate(v)` —— 没在播时设了**不报错也不生效**，
  /// 所以要等到真的出声才设。老系统（< 6.0）根本不支持变速，设不上就按原速播。
  Future<void> _applyRate() async {
    final speed = _speed;
    if ((speed - 1.0).abs() < 0.001) return;
    try {
      await _player.setPlaybackRate(speed);
    } catch (e) {
      debugPrint('QaSpeech: 变速没生效，按原速播放：$e');
    }
  }

  Future<void> stop() async {
    await _posSub?.cancel();
    _posSub = null;
    _ticker?.cancel();
    _ticker = null;
    _stopAt?.cancel();
    _stopAt = null;
    _clock
      ..stop()
      ..reset();
    _spans = const [];
    _key = null;
    _clip = null;
    _base = 0;
    speaking.value = null;
    activeSpan.value = null;
    try {
      await _player.stop();
    } catch (_) {/* 没在播时 stop 会抛，忽略 */}
  }

  /// 读完（或被打断）后只清状态，不 stop 播放器：剩下的静音尾巴无所谓，
  /// 下次 [speak] 开头会 stop。
  void _finish() {
    _posSub?.cancel();
    _posSub = null;
    _ticker?.cancel();
    _ticker = null;
    _stopAt?.cancel();
    _stopAt = null;
    _clock
      ..stop()
      ..reset();
    _spans = const [];
    _key = null;
    _clip = null;
    _base = 0;
    speaking.value = null;
    activeSpan.value = null;
  }

  /// 正在朗读的是不是 [key]。
  bool isSpeaking(String key) => speaking.value == key;

  /// 语速变了：正在读的这段按新语速从头再读一遍，听感才连贯。
  Future<void> applyRate(double next) async {
    rate = next.clamp(minRate, maxRate);
    final clip = _clip;
    final key = _key;
    if (clip == null || key == null) return;
    await speak(key, clip, rateOverride: rate);
  }

  Future<void> dispose() async {
    await stop();
    await _doneSub?.cancel();
    _doneSub = null;
    try {
      await _player.dispose();
    } catch (_) {/* 释放失败无所谓 */}
  }
}

/// 朗读语速：全机一份（家长在设置里定，孩子账号跟着用），改完立刻对正在读的那段生效。
class QaSpeechRateController extends Notifier<double> {
  @override
  double build() {
    final saved = ref.watch(prefsProvider).getDouble(kQaSpeechRateKey);
    final rate = (saved ?? 1.0).clamp(QaSpeech.minRate, QaSpeech.maxRate);
    QaSpeech.instance.rate = rate;
    return rate;
  }

  void set(double value) {
    final rate = value.clamp(QaSpeech.minRate, QaSpeech.maxRate);
    ref.read(prefsProvider).setDouble(kQaSpeechRateKey, rate);
    state = rate;
    QaSpeech.instance.applyRate(rate);
  }
}

final qaSpeechRateProvider = NotifierProvider<QaSpeechRateController, double>(
    QaSpeechRateController.new);

/// 语速档位：慢到快四档，够用又不至于让家长挑花眼。
const List<double> kQaSpeechRates = [0.6, 0.8, 1.0, 1.3];

/// 档位的中文名，比倍数好认；与 [kQaSpeechRates] 一一对应。
/// （不能写成 `Map<double,String>`：double 不能当常量 map 的 key。）
const List<String> kQaRateLabels = ['很慢', '慢', '正常', '快'];

/// 档位的显示名，认不出倍数时退回「1.2×」这种写法。
String qaRateLabel(double rate) {
  final i = kQaSpeechRates.indexOf(rate);
  return i < 0 ? '${rate.toStringAsFixed(1)}×' : kQaRateLabels[i];
}
