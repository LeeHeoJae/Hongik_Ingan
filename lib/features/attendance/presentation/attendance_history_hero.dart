import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/attendance_controller.dart';
import 'attendance_history_view.dart';

/// Keeps the history action continuous when its in-page anchor changes.
class AttendanceHistoryHero extends ConsumerStatefulWidget {
  const AttendanceHistoryHero({
    super.key,
    required this.atPanelHeading,
    required this.headingAnchor,
    required this.summaryAnchor,
    required this.visible,
    required this.child,
  });

  final bool atPanelHeading;
  final GlobalKey headingAnchor;
  final GlobalKey summaryAnchor;
  final bool visible;
  final Widget child;

  @override
  ConsumerState<AttendanceHistoryHero> createState() =>
      _AttendanceHistoryHeroState();
}

class _AttendanceHistoryHeroState extends ConsumerState<AttendanceHistoryHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  OverlayEntry? _flight;
  Rect? _lastRect;
  Rect? _startRect;
  Rect? _currentRect;
  Rect? _capturedStart;
  bool _pendingMove = false;
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addStatusListener(_onStatus);
  }

  Rect? _anchorRect() {
    final key = widget.atPanelHeading
        ? widget.headingAnchor
        : widget.summaryAnchor;
    final box = key.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  @override
  void didUpdateWidget(covariant AttendanceHistoryHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.atPanelHeading != widget.atPanelHeading) {
      _startRect = _capturedStart ?? _currentRect ?? _lastRect;
      _capturedStart = null;
      _controller.stop();
      _removeFlight();
      _pendingMove = _startRect != null;
    }
  }

  void _removeFlight() {
    _flight?.remove();
    _flight?.dispose();
    _flight = null;
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    _removeFlight();
    setState(() {
      _lastRect = _anchorRect();
      _currentRect = null;
    });
  }

  void _afterLayout() {
    if (!mounted) return;
    if (!_enabled) {
      final hadFlight = _flight != null || _pendingMove;
      _controller.stop();
      _removeFlight();
      _pendingMove = false;
      _lastRect = null;
      _currentRect = null;
      _capturedStart = null;
      if (hadFlight) setState(() {});
      return;
    }
    final target = _anchorRect();
    if (target == null) return;
    if (!_pendingMove) {
      if (_flight == null) _lastRect = target;
      return;
    }
    _pendingMove = false;
    if (MediaQuery.disableAnimationsOf(context) || _startRect == target) {
      setState(() {
        _lastRect = target;
        _currentRect = null;
      });
      return;
    }
    final overlay = Overlay.of(context);
    final container = ProviderScope.containerOf(context, listen: false);
    final button = InheritedTheme.captureAll(
      context,
      UncontrolledProviderScope(
        container: container,
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          child: const AttendanceHistoryButton(),
        ),
      ),
    );
    _flight = OverlayEntry(
      builder: (context) => AnimatedBuilder(
        animation: _controller,
        child: button,
        builder: (context, child) {
          // Follow the destination while the bottom-aligned card resizes.
          final destination = _anchorRect() ?? target;
          _currentRect = MaterialRectArcTween(
            begin: _startRect,
            end: destination,
          ).transform(Curves.easeInOutCubic.transform(_controller.value));
          final overlayBox = overlay.context.findRenderObject() as RenderBox;
          final local = overlayBox.globalToLocal(_currentRect!.topLeft);
          return Positioned.fromRect(
            rect: local & _currentRect!.size,
            child: child!,
          );
        },
      ),
    );
    overlay.insert(_flight!);
    setState(() {});
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _removeFlight();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _enabled = widget.visible && TickerMode.valuesOf(context).enabled;
    ref.listen(attendanceProvider, (previous, next) {
      final wasAtHeading =
          previous != null &&
          previous.currentLecture != null &&
          previous.error == null;
      final isAtHeading = next.currentLecture != null && next.error == null;
      if (wasAtHeading != isAtHeading) {
        _capturedStart = _currentRect ?? _anchorRect() ?? _lastRect;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _afterLayout());
    return _HistoryFlightScope(
      hidden: !_enabled || _pendingMove || _flight != null,
      child: widget.child,
    );
  }
}

class AttendanceHistoryHeroAnchor extends StatelessWidget {
  const AttendanceHistoryHeroAnchor({
    super.key,
    required this.width,
    this.foregroundColor,
  });

  final double width;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final hidden = context
        .dependOnInheritedWidgetOfExactType<_HistoryFlightScope>()!
        .hidden;
    return SizedBox(
      width: width,
      height: 44,
      child: hidden
          ? null
          : AttendanceHistoryButton(foregroundColor: foregroundColor),
    );
  }
}

class _HistoryFlightScope extends InheritedWidget {
  const _HistoryFlightScope({required this.hidden, required super.child});

  final bool hidden;

  @override
  bool updateShouldNotify(_HistoryFlightScope oldWidget) =>
      hidden != oldWidget.hidden;
}
