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
/// 计时靠 [Stopwatch] 推（40ms 一跳，比位置回调细腻得多），再用真实播放位置校准。
/// 校准的规矩见 [QaReadClock]：只补开播延迟和「表落后了」，不往回拨。
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

  /// 每读完一小节 +1。答题页靠它认出「题面刚读完」，
  /// 好在这个节骨眼把四个选项的边框闪一下辉光。
  final ValueNotifier<int> completed = ValueNotifier<int>(0);

  final AudioPlayer _player = AudioPlayer(playerId: 'xedu_qa_voice');

  /// 播放语速，1.0 为原速。由 [QaSpeechRateController] 写入。
  double rate = 1.0;

  StreamSubscription<Duration>? _posSub;
  StreamSubscription<void>? _doneSub;
  List<QaSpan> _spans = const [];
  String? _key;
  QaVoiceClip? _clip;
  Timer? _ticker;
  Timer? _stopAt;
  final Stopwatch _clock = Stopwatch();

  /// 还排在这一节后面、等着读的片段（整段跟读用，见 [speakAll]）。
  List<QaReadSeg> _pending = const [];

  /// 播放代际：换一节或停下都 +1，用来丢掉上一节迟到的回调。
  int _gen = 0;

  /// 朗读进度：计时表读数 + 真实播放位置的对表。
  final QaReadClock _sync = QaReadClock();

  /// 计时表读数（秒），每对一次表就归零重走。
  double get _elapsed => _clock.elapsedMicroseconds / 1e6;

  /// 当前媒体时间（秒）。媒体时间不受语速影响，和语音时间轴同一把尺子。
  double get _media => _sync.media(_elapsed);

  /// 开始监听播放事件。任何环节失败都不抛出去 —— 朗读是锦上添花，
  /// 设备放不出声时不能把答题也带崩。
  Future<void> init() async {
    try {
      await _player.setReleaseMode(ReleaseMode.stop);
    } catch (e) {
      debugPrint('QaSpeech: 播放器初始化失败：$e');
    }
  }

  /// 朗读 [clip] 一段。[key] 用来在 UI 上标记「是哪一条在读」。
  ///
  /// 出错只降级成「这一遍没声音」，不清空 [speaking] 以外的状态、也不永久停用 ——
  /// 下一题还会再试一次。
  Future<void> speak(String key, QaVoiceClip clip,
      {double? rateOverride}) async {
    await init();
    await stop();
    await _play(key, clip, (rateOverride ?? rate).clamp(minRate, maxRate));
  }

  /// 连着朗读好几小节（题面 →「答案有」→ 各选项 →「你选择哪个」），
  /// 一节读完自动接下一节。中途 [stop] 或单段 [speak] 会把没读到的那几节丢掉。
  Future<void> speakAll(Iterable<QaReadSeg> segs) async {
    final list = segs.toList();
    await init();
    await stop();
    if (list.isEmpty) return;
    _pending = list.sublist(1);
    await _play(list.first.key, list.first.clip, rate);
  }

  /// 播放一小节。[speed] 是这一节的语速。
  Future<void> _play(String key, QaVoiceClip clip, double speed) async {
    final gen = ++_gen;
    await _halt();
    // 等停播放器的这点时间里有别的朗读插进来（或页面被关掉）就作废。
    if (gen != _gen) return;

    _key = key;
    _clip = clip;
    _spans = clip.spans;
    _sync.begin(speed);
    speaking.value = key;
    activeSpan.value = null;

    try {
      _posSub = _player.onPositionChanged.listen(_onPosition, onError: (_) {});
      _doneSub = _player.onPlayerComplete.listen((_) {
        if (gen == _gen) _finish();
      });
      // 语速要在起播**之前**送，而且每一段都送、1.0 也送。Android 和 iOS 都只是把
      // 这个值存下来（播放中才立刻生效），再按它起播。要 1.0 时干脆不送，播放器里就
      // 留着上一档的 0.6：声音慢着读，计时表却按 1.0 推 —— 高亮被一次次往回拨，
      // 光标就在相邻两个字之间来回跳。
      await _sendRate(speed);
      await _player.play(AssetSource(clip.asset));
    } catch (e) {
      debugPrint('QaSpeech: 播放失败，这一段静音：$e');
      if (gen == _gen) _finish();
      return;
    }
    if (gen != _gen) return;

    _clock
      ..reset()
      ..start();
    _ticker = Timer.periodic(const Duration(milliseconds: 40), (_) {
      if (gen == _gen) _tick();
    });

    // 末尾有半秒多的静音，读完就停，不用等它播完。
    _stopAt = Timer(
      Duration(milliseconds: ((clip.voiced / speed) * 1000).round() + 280),
      () {
        if (gen == _gen) _finish();
      },
    );
  }

  /// 真实播放位置回调。播放器报的位置粗、还带台阶，只拿它粗对一下表，
  /// 怎么对见 [QaReadClock]。
  void _onPosition(Duration pos) {
    final media = pos.inMicroseconds / 1e6;
    if (media <= 0) return; // 0 表示还没真的出声
    if (_sync.onPosition(media, _elapsed)) {
      _clock
        ..reset()
        ..start();
    }
  }

  void _tick() {
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

  /// 下发语速。老系统（< 6.0）根本不支持变速，设不上就按原速播，高亮照样跟得上。
  Future<void> _sendRate(double speed) async {
    try {
      await _player.setPlaybackRate(speed);
    } catch (e) {
      debugPrint('QaSpeech: 变速没生效，按原速播放：$e');
    }
  }

  /// 停下播放器，并撤掉上一节的监听与计时（末尾的静音尾巴不听）。
  Future<void> _halt() async {
    await _posSub?.cancel();
    await _doneSub?.cancel();
    _posSub = null;
    _doneSub = null;
    _ticker?.cancel();
    _ticker = null;
    _stopAt?.cancel();
    _stopAt = null;
    _clock
      ..stop()
      ..reset();
    try {
      await _player.stop();
    } catch (_) {/* 没在播时 stop 会抛，忽略 */}
  }

  Future<void> stop() async {
    _gen++;
    _pending = const [];
    await _halt();
    _spans = const [];
    _key = null;
    _clip = null;
    speaking.value = null;
    activeSpan.value = null;
  }

  /// 一节读完（或被截停）：清状态，接着读排队里的下一节；没有下一节就收工。
  /// 不 stop 播放器 —— 剩下的静音尾巴无所谓，下一节开头会 stop。
  void _finish() {
    _posSub?.cancel();
    _posSub = null;
    _doneSub?.cancel();
    _doneSub = null;
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
    speaking.value = null;
    activeSpan.value = null;
    completed.value++;

    final next = _pending;
    if (next.isEmpty) return;
    _pending = next.sublist(1);
    unawaited(_play(next.first.key, next.first.clip, _sync.speed));
  }

  /// 正在朗读的是不是 [key]。
  bool isSpeaking(String key) => speaking.value == key;

  /// 语速变了：正在读的这节按新语速从头再读一遍，后面没读完的接着排，听感才连贯。
  Future<void> applyRate(double next) async {
    rate = next.clamp(minRate, maxRate);
    final clip = _clip;
    final key = _key;
    if (clip == null || key == null) return;
    await speakAll([QaReadSeg(key, clip), ..._pending]);
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

/// 朗读进度的尺子：计时表读数 + 播放器报回的真实位置，算出此刻读到了哪儿。
///
/// 播放器报回来的位置比高亮需要的粒度粗得多（还常带台阶和抖动），所以
/// **平时按计时表推**，只在两种情况下重新对表：
///
/// * 第一次收到真实位置 —— 播放启动比计时表晚，这一下正是那段启动延迟；
/// * 声音跑到表**前面**一大截 —— 表落后了（设备没按档位播，或者卡完刚追上来）。
///
/// 「声音落在表后面」一律不管。位置回调自己就带台阶：表被拨回台阶值之后，再走到
/// 台阶边上又被拨回来，光标就在相邻两个字之间来回跳 —— 就是「读答案时光标来回切」
/// 的毛病。所以对表**只往一个方向**，拨不回去。
class QaReadClock {
  /// 声音比表快这么多（秒）才值得对表；更小的差是回调自己的台阶。
  static const double _ahead = 0.12;

  /// 这一节的语速（媒体秒 / 真实秒），按家长定的档位来。
  double _speed = 1.0;

  /// 上一次对表时的媒体时间（秒）。
  double _base = 0.0;

  /// 这一节是否对过表了（第一次无条件对，抹掉开播延迟）。
  bool _synced = false;

  /// 这一节的语速。整段跟读里后面几小节沿用同一个值。
  double get speed => _speed;

  /// 开一节新朗读：[speed] 是这一节的语速，调用方会把计时表归零。
  void begin(double speed) {
    _speed = speed;
    _base = 0;
    _synced = false;
  }

  /// 计时表走了 [elapsed] 秒时，音频应该在的位置（媒体秒）。
  double media(double elapsed) => _base + elapsed * _speed;

  /// 收到播放器报回来的真实位置 [reported]（媒体秒），[elapsed] 是计时表读数（秒）。
  ///
  /// 返回 true 表示基准改了，调用方要把计时表归零重走。
  bool onPosition(double reported, double elapsed) {
    if (reported <= 0) return false; // 0 表示还没真的出声
    if (_synced && reported - media(elapsed) < _ahead) return false;
    _base = reported;
    _synced = true;
    return true;
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

/// 要不要朗读：家长在「我的 → 偏好设置」里定，全机一份，**缺省朗读**。
///
/// 关掉之后进题目不自动读，题面和选项上的小喇叭也不再出现 —— 孩子自己读。
class QaReadAloudController extends Notifier<bool> {
  @override
  bool build() => ref.watch(prefsProvider).getBool(kQaReadAloudKey) ?? true;

  void set(bool value) {
    ref.read(prefsProvider).setBool(kQaReadAloudKey, value);
    state = value;
    if (!value) QaSpeech.instance.stop();
  }
}

final qaReadAloudProvider =
    NotifierProvider<QaReadAloudController, bool>(QaReadAloudController.new);

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
