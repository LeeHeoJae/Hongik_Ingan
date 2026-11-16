import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hongik_ingan/features/attendance/application/attendance_controller.dart';
import 'package:hongik_ingan/features/home/application/home_controller.dart';

const attendanceAutoRefreshInterval = Duration(seconds: 5);

/// 이 시간 동안 터치·키 입력이 없으면 자동 확인을 멈춘다.
const attendanceAutoRefreshIdleTimeout = Duration(minutes: 3);

const attendancePausedDescription = '입력이 없어 자동 확인을 멈췄어요. 화면을 누르면 다시 확인해요.';

class AttendanceAutoRefresh extends ConsumerStatefulWidget {
  const AttendanceAutoRefresh({required this.child, super.key});

  final Widget child;

  /// 입력이 없어 자동 확인을 멈췄는지 여부.
  static bool isPausedOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_AttendanceAutoRefreshScope>()
          ?.paused ??
      false;

  @override
  ConsumerState<AttendanceAutoRefresh> createState() =>
      _AttendanceAutoRefreshState();
}

class _AttendanceAutoRefreshState extends ConsumerState<AttendanceAutoRefresh>
    with WidgetsBindingObserver {
  Timer? _timer;
  Timer? _idleTimer;
  late bool _isForeground;
  bool _isVisible = false;
  bool _requestInFlight = false;
  bool _paused = false;

  bool get _canRefresh {
    final attendance = ref.read(attendanceProvider);
    return !_paused &&
        _isForeground &&
        _isVisible &&
        ref.read(homeControllerProvider).isLoggedIn &&
        !_requestInFlight &&
        !attendance.isBusy &&
        attendance.hasCheckedLecture &&
        (attendance.submissionResult == null || attendance.isLectureStale) &&
        (attendance.currentLecture == null || attendance.isLectureStale) &&
        !attendance.sessionExpired;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _isForeground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    GestureBinding.instance.pointerRouter.addGlobalRoute(_handlePointer);
    HardwareKeyboard.instance.addHandler(_handleKey);
    _restartIdleTimer();
    ref.listenManual(attendanceProvider, (_, _) => _schedule());
    ref.listenManual(homeControllerProvider, (previous, next) {
      if (previous?.isLoggedIn != next.isLoggedIn ||
          previous?.userId != next.userId) {
        _schedule();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.valuesOf(context).enabled;
    if (_isVisible == visible) return;
    _isVisible = visible;
    _schedule();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (_isForeground == foreground) return;
    _isForeground = foreground;
    // 앱으로 돌아온 것도 사용자의 입력으로 본다.
    if (foreground && _registerInput()) return;
    _schedule();
  }

  void _handlePointer(PointerEvent event) {
    if (event is PointerDownEvent || event is PointerSignalEvent) {
      _registerInput();
    }
  }

  bool _handleKey(KeyEvent event) {
    if (event is KeyDownEvent) _registerInput();
    return false;
  }

  /// 입력 시점을 갱신하고, 멈춘 상태였다면 바로 다시 확인한다.
  bool _registerInput() {
    if (!mounted) return false;
    _restartIdleTimer();
    if (!_paused) return false;
    setState(() => _paused = false);
    _timer?.cancel();
    _timer = null;
    unawaited(_refresh());
    return true;
  }

  void _restartIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(attendanceAutoRefreshIdleTimeout, () {
      if (!mounted) return;
      _timer?.cancel();
      _timer = null;
      setState(() => _paused = true);
    });
  }

  void _schedule() {
    _timer?.cancel();
    _timer = null;
    if (!mounted || !_canRefresh) return;
    final serverDelay = ref.read(attendanceProvider.notifier).lectureRetryDelay;
    final delay = serverDelay > attendanceAutoRefreshInterval
        ? serverDelay
        : attendanceAutoRefreshInterval;
    _timer = Timer(delay, () => unawaited(_refresh()));
  }

  Future<void> _refresh() async {
    _timer = null;
    if (!mounted || !_canRefresh) return;
    _requestInFlight = true;
    try {
      await ref
          .read(attendanceProvider.notifier)
          .fetchLecture(forceRefresh: true, isAutomatic: true);
    } finally {
      _requestInFlight = false;
      if (mounted) _schedule();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _idleTimer?.cancel();
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_handlePointer);
    HardwareKeyboard.instance.removeHandler(_handleKey);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _AttendanceAutoRefreshScope(paused: _paused, child: widget.child);
}

class _AttendanceAutoRefreshScope extends InheritedWidget {
  const _AttendanceAutoRefreshScope({
    required this.paused,
    required super.child,
  });

  final bool paused;

  @override
  bool updateShouldNotify(_AttendanceAutoRefreshScope oldWidget) =>
      paused != oldWidget.paused;
}
