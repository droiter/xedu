import 'dart:async';

import 'package:flutter/widgets.dart';

/// 把「不是孩子按的」返回键挡在门外。
///
/// 合上平板再打开时，系统偶尔会把「唤醒」当成一次返回键发过来（Android 侧
/// 返回回调的老毛病），做题页的 [PopScope] 收到就自己弹出家长验证框。用这个
/// mixin 约定：只有 App 真的停在前台、且回到前台已经超过 [grace] 了，那一次
/// 返回才算孩子按的。
mixin BackGuard<T extends StatefulWidget> on State<T> {
  /// 回到前台后这段时间里收到的返回一律不认。
  ///
  /// 取两秒是折中：唤醒事件多半就在这一瞬间到，而孩子合上平板又打开、
  /// 立刻按返回的概率很低。
  static const Duration grace = Duration(seconds: 2);

  AppLifecycleState _life = AppLifecycleState.resumed;
  Timer? _graceTimer;
  bool _inGrace = false;

  late final _LifecycleWatcher _watcher = _LifecycleWatcher(_onLifecycle);

  /// 这一次返回是不是真的出自孩子的手。
  bool isRealBack() => _life == AppLifecycleState.resumed && !_inGrace;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(_watcher);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_watcher);
    _graceTimer?.cancel();
    super.dispose();
  }

  void _onLifecycle(AppLifecycleState state) {
    _life = state;
    if (state != AppLifecycleState.resumed) return;
    _inGrace = true;
    _graceTimer?.cancel();
    _graceTimer = Timer(grace, () => _inGrace = false);
  }
}

/// 只关心前后台切换的观察者。
///
/// 让 mixin 直接 `implements WidgetsBindingObserver` 会把整个接口压到用它的人
/// 身上（十几个回调都得实现），这里用一个转发对象把它收成一条。
class _LifecycleWatcher with WidgetsBindingObserver {
  _LifecycleWatcher(this._onChange);

  final ValueChanged<AppLifecycleState> _onChange;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _onChange(state);
}
