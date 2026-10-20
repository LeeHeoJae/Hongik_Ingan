import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:hongik_ingan/core/presentation/app_motion.dart';

import 'home_attendance_action_layout.dart';
import 'home_attendance_density.dart';

/// Measures the new body while authentication changes share the card's timeline.
class HomeLoginTransition extends StatefulWidget {
  const HomeLoginTransition({
    super.key,
    required this.isLoggedIn,
    required this.child,
    this.animateLogin = true,
    this.bottomAligned = false,
    this.frameBuilder,
  });

  final bool isLoggedIn;
  final Widget child;
  final bool animateLogin;
  final bool bottomAligned;
  final Widget Function(
    BuildContext context,
    Widget body,
    Animation<double> incoming,
  )?
  frameBuilder;

  @override
  State<HomeLoginTransition> createState() => _HomeLoginTransitionState();
}

/// Uses natural content spacing independently of the moving card's height.
class HomeLoginBody extends StatelessWidget {
  const HomeLoginBody({
    super.key,
    required this.status,
    required this.fields,
    required this.action,
  });

  final Widget status;
  final List<Widget> fields;
  final Widget action;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final density = HomeAttendanceDensityScope.bodyOf(context);
      final body = HomeAttendanceActionLayout(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            status,
            SizedBox(height: density.contentGap),
            fields[0],
            SizedBox(height: density.sectionGap),
            fields[1],
            SizedBox(height: density.contentGap),
            fields[2],
          ],
        ),
        action: action,
      );
      final cardHeight = HomeAttendanceCardScope.heightOf(context);
      final wide =
          MediaQuery.sizeOf(context).width >= 960 &&
          constraints.maxWidth >= 480 &&
          MediaQuery.textScalerOf(context).scale(14) <= 19;
      if (wide || cardHeight == null) return body;
      return _LoginBodyViewport(
        availableHeight:
            (cardHeight -
                    HomeAttendanceActionScope.bodyTopOf(context) -
                    HomeAttendanceActionScope.bottomPaddingOf(context))
                .clamp(0, double.infinity),
        bottomAligned: MediaQuery.sizeOf(context).width < 600,
        child: body,
      );
    },
  );
}

/// Reveals one naturally laid-out block while the card catches up with its size.
class _LoginBodyViewport extends SingleChildRenderObjectWidget {
  const _LoginBodyViewport({
    required this.availableHeight,
    required this.bottomAligned,
    required super.child,
  });

  final double availableHeight;
  final bool bottomAligned;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderLoginBodyViewport(availableHeight, bottomAligned);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderLoginBodyViewport renderObject,
  ) {
    renderObject
      ..availableHeight = availableHeight
      ..bottomAligned = bottomAligned
      ..markNeedsPaint()
      ..markNeedsSemanticsUpdate();
  }
}

class _RenderLoginBodyViewport extends RenderProxyBox {
  _RenderLoginBodyViewport(this.availableHeight, this.bottomAligned);

  double availableHeight;
  bool bottomAligned;

  Rect get viewport => Rect.fromLTWH(
    0,
    bottomAligned ? size.height - availableHeight : 0,
    size.width,
    availableHeight,
  );

  Offset get translation => Offset(0, viewport.bottom - size.height);

  @override
  void paint(PaintingContext context, Offset offset) {
    context.pushClipRect(
      needsCompositing,
      offset,
      viewport,
      (context, offset) => context.paintChild(child!, offset + translation),
    );
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!viewport.contains(position) ||
        !hitTestChildren(result, position: position)) {
      return false;
    }
    result.add(BoxHitTestEntry(this, position));
    return true;
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      result.addWithPaintOffset(
        offset: translation,
        position: position,
        hitTest: (result, position) =>
            child!.hitTest(result, position: position),
      );

  @override
  Rect? describeApproximatePaintClip(RenderObject child) => viewport;

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.translateByDouble(translation.dx, translation.dy, 0, 1);
  }
}

class _HomeLoginTransitionState extends State<HomeLoginTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Animation<double> _incoming = const AlwaysStoppedAnimation(1);
  Animation<double> _outgoing = const AlwaysStoppedAnimation(0);
  GlobalKey _currentKey = GlobalKey();
  GlobalKey? _previousKey;
  Widget? _previous;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          vsync: this,
          duration: AppMotion.layoutDuration,
          value: 1,
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed && _previous != null) {
            setState(() {
              _previous = null;
              _previousKey = null;
            });
          }
        });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) _finishTransition();
  }

  @override
  void didUpdateWidget(HomeLoginTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isLoggedIn == widget.isLoggedIn) return;

    if (!widget.isLoggedIn) {
      // Reuse a departing form when logout interrupts login, but show it now.
      _currentKey = _previousKey ?? GlobalKey();
      _finishTransition();
      return;
    }
    if (!widget.animateLogin || MediaQuery.disableAnimationsOf(context)) {
      _finishTransition();
      return;
    }

    final currentOpacity = _incoming.value;
    _previous = oldWidget.child;
    _previousKey = _currentKey;
    _currentKey = GlobalKey();
    _incoming = Tween<double>(begin: 0, end: 1)
        .chain(CurveTween(curve: AppMotion.layoutIncomingCurve))
        .animate(_controller);
    _outgoing = Tween<double>(begin: currentOpacity, end: 0)
        .chain(CurveTween(curve: AppMotion.layoutOutgoingCurve))
        .animate(_controller);
    _controller.stop();
    _controller.value = 0;
    final generation = ++_generation;
    // Natural-size reporting commits the card's target after this layout.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && generation == _generation) _controller.forward();
    });
  }

  void _finishTransition() {
    _generation++;
    _previous = null;
    _previousKey = null;
    _incoming = const AlwaysStoppedAnimation(1);
    _outgoing = const AlwaysStoppedAnimation(0);
    _controller.stop();
    _controller.value = 1;
  }

  @override
  void dispose() {
    _generation++;
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body = Stack(
      clipBehavior: Clip.none,
      alignment: widget.bottomAligned
          ? Alignment.bottomLeft
          : Alignment.topLeft,
      children: [
        if (_previous != null)
          Positioned(
            top: widget.bottomAligned ? null : 0,
            bottom: widget.bottomAligned ? 0 : null,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: ExcludeFocus(
                child: ExcludeSemantics(
                  child: FadeTransition(
                    opacity: _outgoing,
                    child: KeyedSubtree(key: _previousKey, child: _previous!),
                  ),
                ),
              ),
            ),
          ),
        AnimatedBuilder(
          animation: _incoming,
          child: FadeTransition(
            key: const ValueKey('home-login-incoming'),
            opacity: _incoming,
            child: KeyedSubtree(key: _currentKey, child: widget.child),
          ),
          builder: (context, child) => IgnorePointer(
            ignoring: _incoming.value == 0,
            child: ExcludeFocus(
              excluding: _incoming.value == 0,
              child: ExcludeSemantics(
                excluding: _incoming.value == 0,
                child: child!,
              ),
            ),
          ),
        ),
      ],
    );
    return widget.frameBuilder?.call(context, body, _incoming) ?? body;
  }
}
