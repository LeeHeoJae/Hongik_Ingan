import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

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

/// Reveals a stacked login inside the moving card without changing its natural
/// height. Mobile is already bottom aligned by the surrounding workspace.
class HomeLoginBodyAnchor extends StatelessWidget {
  const HomeLoginBodyAnchor({
    super.key,
    required this.status,
    required this.fields,
    required this.action,
    required this.hasStatusDescription,
  });

  final Widget status;
  final List<Widget> fields;
  final Widget action;
  final bool hasStatusDescription;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = MediaQuery.sizeOf(context).width;
      final wide =
          width >= 960 &&
          constraints.maxWidth >= 480 &&
          MediaQuery.textScalerOf(context).scale(14) <= 19;
      final cardHeight = HomeAttendanceCardScope.heightOf(context);
      final density = HomeAttendanceDensityScope.bodyOf(context);
      final gaps = [
        density.contentGap,
        density.sectionGap,
        density.contentGap,
        density.contentGap,
      ];
      if (wide || cardHeight == null) {
        return HomeAttendanceActionLayout(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              status,
              SizedBox(height: gaps[0]),
              fields[0],
              SizedBox(height: gaps[1]),
              fields[1],
              SizedBox(height: gaps[2]),
              fields[2],
            ],
          ),
          action: action,
        );
      }
      var statusBottomSpace = 0.0;
      if (width >= 600 && !hasStatusDescription) {
        final painter = TextPainter(
          text: TextSpan(
            text: ' ',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium!.copyWith(height: 1.5),
          ),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        statusBottomSpace = painter.height * 2 + 8;
        painter.dispose();
      }
      return _LoginBodyAnchor(
        gaps: gaps,
        statusBottomSpace: statusBottomSpace,
        labelOverflow: MediaQuery.textScalerOf(context).scale(12) / 2,
        bottomAligned: width < 600,
        availableHeight:
            (cardHeight -
                    HomeAttendanceActionScope.bodyTopOf(context) -
                    HomeAttendanceActionScope.bottomPaddingOf(context))
                .clamp(0, double.infinity),
        children: [status, ...fields, action],
      );
    },
  );
}

class _LoginBodyAnchor extends MultiChildRenderObjectWidget {
  const _LoginBodyAnchor({
    required this.availableHeight,
    required this.bottomAligned,
    required this.gaps,
    required this.statusBottomSpace,
    required this.labelOverflow,
    required super.children,
  });

  final double availableHeight;
  final bool bottomAligned;
  final List<double> gaps;
  final double statusBottomSpace;
  final double labelOverflow;

  @override
  _RenderLoginBodyAnchor createRenderObject(BuildContext context) =>
      _RenderLoginBodyAnchor(
        availableHeight,
        bottomAligned,
        gaps,
        statusBottomSpace,
        labelOverflow,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderLoginBodyAnchor renderObject,
  ) {
    renderObject.availableHeight = availableHeight;
    renderObject.bottomAligned = bottomAligned;
    renderObject.configureSpacing(gaps, statusBottomSpace, labelOverflow);
  }
}

class _LoginBodyParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderLoginBodyAnchor extends RenderBox
    with
        ContainerRenderObjectMixin<
          RenderBox,
          ContainerBoxParentData<RenderBox>
        >,
        RenderBoxContainerDefaultsMixin<
          RenderBox,
          ContainerBoxParentData<RenderBox>
        > {
  _RenderLoginBodyAnchor(
    this._availableHeight,
    this._bottomAligned,
    this._gaps,
    this._statusBottomSpace,
    this._labelOverflow,
  );

  double _availableHeight;
  bool _bottomAligned;
  List<double> _gaps;
  double _statusBottomSpace;
  double _labelOverflow;

  void configureSpacing(
    List<double> gaps,
    double statusBottomSpace,
    double labelOverflow,
  ) {
    if (listEquals(_gaps, gaps) &&
        _statusBottomSpace == statusBottomSpace &&
        _labelOverflow == labelOverflow) {
      return;
    }
    _gaps = gaps;
    _statusBottomSpace = statusBottomSpace;
    _labelOverflow = labelOverflow;
    markNeedsLayout();
  }

  set bottomAligned(bool value) {
    if (_bottomAligned == value) return;
    _bottomAligned = value;
    markNeedsLayout();
  }

  set availableHeight(double value) {
    if (_availableHeight == value) return;
    _availableHeight = value;
    markNeedsLayout();
  }

  Rect get viewport => Rect.fromLTWH(
    0,
    _bottomAligned ? size.height - _availableHeight : 0,
    size.width,
    _availableHeight,
  );

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! ContainerBoxParentData<RenderBox>) {
      child.parentData = _LoginBodyParentData();
    }
  }

  @override
  void performLayout() {
    final childConstraints = constraints.copyWith(
      minWidth: constraints.hasBoundedWidth
          ? constraints.maxWidth
          : constraints.minWidth,
      minHeight: 0,
      maxHeight: double.infinity,
    );
    var height = _gaps.fold(0.0, (sum, gap) => sum + gap);
    var width = 0.0;
    for (final child in getChildrenAsList()) {
      child.layout(childConstraints, parentUsesSize: true);
      height += child.size.height;
      if (child.size.width > width) width = child.size.width;
    }
    size = constraints.constrain(Size(width, height));
    // Only blank space contracts while the card catches up. Controls and text
    // keep their final size, and measurement always returns the natural height.
    final flexible = _gaps.fold(
      _statusBottomSpace,
      (sum, gap) => sum + (gap - gap.clamp(0.0, _labelOverflow)),
    );
    final compression = flexible == 0
        ? 0.0
        : ((height - _availableHeight) / flexible).clamp(0.0, 1.0);
    var top = viewport.top;
    var index = 0;
    for (final child in getChildrenAsList()) {
      final data = child.parentData! as ContainerBoxParentData<RenderBox>;
      data.offset = Offset(
        0,
        child == lastChild ? viewport.bottom - child.size.height : top,
      );
      top += child.size.height;
      if (index == 0) top -= _statusBottomSpace * compression;
      if (index < _gaps.length) {
        final gap = _gaps[index];
        top += gap - (gap - gap.clamp(0.0, _labelOverflow)) * compression;
      }
      index++;
    }
  }

  Rect _childViewport(RenderBox child) {
    final data = child.parentData! as ContainerBoxParentData<RenderBox>;
    final next = data.nextSibling;
    // InputDecorator paints floating labels slightly above its layout bounds.
    bool field(RenderBox? box) =>
        box != null &&
        (box == childAfter(firstChild!) ||
            box == childAfter(childAfter(firstChild!)!));
    final top = data.offset.dy - (field(child) ? _labelOverflow : 0);
    final bottom = next == null
        ? viewport.bottom
        : (next.parentData! as ContainerBoxParentData<RenderBox>).offset.dy -
              (field(next) ? _labelOverflow : 0);
    return Rect.fromLTRB(
      0,
      top,
      size.width,
      bottom.clamp(top, double.infinity),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    context.pushClipRect(needsCompositing, offset, viewport, (context, offset) {
      for (final child in getChildrenAsList()) {
        context.pushClipRect(
          needsCompositing,
          offset,
          _childViewport(child),
          (context, offset) => context.paintChild(
            child,
            offset +
                (child.parentData! as ContainerBoxParentData<RenderBox>).offset,
          ),
        );
      }
    });
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!viewport.contains(position)) return false;
    for (final child in getChildrenAsList().reversed) {
      if (!_childViewport(child).contains(position)) continue;
      if (result.addWithPaintOffset(
        offset: (child.parentData! as ContainerBoxParentData<RenderBox>).offset,
        position: position,
        hitTest: (result, position) =>
            child.hitTest(result, position: position),
      )) {
        return true;
      }
    }
    return false;
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final offset =
        (child.parentData! as ContainerBoxParentData<RenderBox>).offset;
    transform.translateByDouble(offset.dx, offset.dy, 0, 1);
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
          duration: const Duration(milliseconds: 400),
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
        .chain(
          CurveTween(
            curve: const Interval(0.2, 0.7, curve: Curves.easeInOutCubic),
          ),
        )
        .animate(_controller);
    _outgoing = Tween<double>(begin: currentOpacity, end: 0)
        .chain(
          CurveTween(
            curve: const Interval(0, 0.35, curve: Curves.easeOutCubic),
          ),
        )
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
