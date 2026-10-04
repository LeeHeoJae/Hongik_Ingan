import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hongik_ingan/features/attendance/application/attendance_controller.dart';
import 'package:hongik_ingan/features/home/application/home_controller.dart';

const attendanceAutoRefreshInterval = Duration(seconds: 5);

class AttendanceAutoRefresh extends ConsumerStatefulWidget {
  const AttendanceAutoRefresh({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AttendanceAutoRefresh> createState() =>
      _AttendanceAutoRefreshState();
}

class _AttendanceAutoRefreshState extends ConsumerState<AttendanceAutoRefresh>
    with WidgetsBindingObserver {
  Timer? _timer;
  late bool _isForeground;
  bool _isVisible = false;
  bool _requestInFlight = false;

  bool get _canRefresh {
    final attendance = ref.read(attendanceProvider);
    return _isForeground &&
        _isVisible &&
        ref.read(homeControllerProvider).isLoggedIn &&
        !_requestInFlight &&
        !attendance.isBusy &&
        attendance.hasCheckedLecture &&
        attendance.currentLecture == null &&
        !attendance.sessionExpired;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _isForeground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
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
    _schedule();
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
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
