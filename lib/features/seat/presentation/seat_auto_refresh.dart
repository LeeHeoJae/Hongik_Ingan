import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

const seatWebAutoRefreshInterval = Duration(seconds: 30);
const seatNativeAutoRefreshInterval = Duration(seconds: 15);

Duration seatAutoRefreshInterval({bool? isWeb}) {
  return (isWeb ?? kIsWeb)
      ? seatWebAutoRefreshInterval
      : seatNativeAutoRefreshInterval;
}

/// 좌석 화면이 보이고 앱이 포그라운드일 때만 선택 건물을 자동 갱신.
class SeatAutoRefresh extends StatefulWidget {
  const SeatAutoRefresh({
    required this.onRefresh,
    required this.child,
    this.enabled = true,
    this.interval,
    super.key,
  });

  final Future<void> Function() onRefresh;
  final Widget child;
  final bool enabled;
  final Duration? interval;

  @override
  State<SeatAutoRefresh> createState() => _SeatAutoRefreshState();
}

class _SeatAutoRefreshState extends State<SeatAutoRefresh>
    with WidgetsBindingObserver {
  Timer? _timer;
  late bool _isForeground;
  bool _isVisible = false;
  bool _visibilityInitialized = false;

  Duration get _interval => widget.interval ?? seatAutoRefreshInterval();

  bool get _isActive => widget.enabled && _isForeground && _isVisible;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    _isForeground =
        lifecycleState == null || lifecycleState == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isVisible = TickerMode.valuesOf(context).enabled;
    if (_visibilityInitialized && _isVisible == isVisible) return;

    final becameVisible = !_isVisible && isVisible;
    _visibilityInitialized = true;
    _isVisible = isVisible;
    if (!_isVisible) {
      _stop();
    } else if (becameVisible && widget.enabled && _isForeground) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isActive) {
          _start(immediate: true);
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant SeatAutoRefresh oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) {
      _stop();
      return;
    }
    if (!oldWidget.enabled && _isForeground) {
      _start(immediate: true);
      return;
    }
    if (oldWidget.interval != widget.interval && _isActive) {
      _start(immediate: false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final wasForeground = _isForeground;
    _isForeground = state == AppLifecycleState.resumed;
    if (!_isForeground) {
      _stop();
    } else if (!wasForeground && widget.enabled) {
      _start(immediate: true);
    }
  }

  void _start({required bool immediate}) {
    _timer?.cancel();
    if (!_isActive) return;
    if (immediate) {
      unawaited(widget.onRefresh());
    }
    _timer = Timer.periodic(_interval, (_) {
      if (_isActive) {
        unawaited(widget.onRefresh());
      }
    });
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
