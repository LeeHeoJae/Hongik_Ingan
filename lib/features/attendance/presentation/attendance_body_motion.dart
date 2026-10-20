import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:hongik_ingan/core/presentation/app_motion.dart';
import 'package:hongik_ingan/core/presentation/widgets/app_animated_switcher.dart';

/// Measures the final body once; only the painted positions interpolate.
class AttendanceBodyMotion extends StatefulWidget {
  const AttendanceBodyMotion({
    super.key,
    required this.child,
    required this.bottomAligned,
    this.enabled = true,
  });

  final Widget child;
  final bool bottomAligned;
  final bool enabled;

  @override
  State<AttendanceBodyMotion> createState() => _AttendanceBodyMotionState();
}

class _AttendanceBodyMotionState extends State<AttendanceBodyMotion>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: AppMotion.layoutDuration,
    value: 1,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled && !MediaQuery.disableAnimationsOf(context);
    return _MotionScope(
      enabled: enabled,
      child: _MotionRoot(
        controller: _controller,
        enabled: enabled,
        bottomAligned: widget.bottomAligned,
        child: widget.child,
      ),
    );
  }
}

/// Keep the part mounted when absent, so its departure can finish without
/// contributing the outgoing content to the new natural height.
class AttendanceMotionPart extends StatelessWidget {
  const AttendanceMotionPart({
    super.key,
    this.child,
    this.contentKey,
    this.fade = true,
  });

  final Widget? child;
  final Object? contentKey;
  final bool fade;

  @override
  Widget build(BuildContext context) {
    final enabled = _MotionScope.maybeOf(context)?.enabled ?? false;
    return _MotionPart(
      child: !fade || !enabled
          ? child ?? const SizedBox.shrink()
          : LayoutBuilder(
              builder: (context, constraints) => AppAnimatedSwitcher(
                duration: AppMotion.layoutDuration,
                switchInCurve: AppMotion.layoutIncomingCurve,
                switchOutCurve: AppMotion.layoutSwitchOutCurve,
                layoutBuilder: AppAnimatedSwitcher.layoutForCurrentChild(
                  constraints.maxWidth,
                ),
                child: child == null
                    ? const SizedBox.shrink(key: ValueKey('absent'))
                    : KeyedSubtree(
                        key: ValueKey(('present', contentKey)),
                        child: child!,
                      ),
              ),
            ),
    );
  }
}

class _MotionScope extends InheritedWidget {
  const _MotionScope({required this.enabled, required super.child});

  final bool enabled;

  static _MotionScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_MotionScope>();

  @override
  bool updateShouldNotify(_MotionScope oldWidget) =>
      enabled != oldWidget.enabled;
}

class _MotionRoot extends SingleChildRenderObjectWidget {
  const _MotionRoot({
    required this.controller,
    required this.enabled,
    required this.bottomAligned,
    required super.child,
  });

  final AnimationController controller;
  final bool enabled;
  final bool bottomAligned;

  @override
  _RenderMotionRoot createRenderObject(BuildContext context) =>
      _RenderMotionRoot(controller, enabled, bottomAligned);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMotionRoot renderObject,
  ) {
    renderObject.configure(enabled, bottomAligned);
  }
}

class _RenderMotionRoot extends RenderProxyBox {
  _RenderMotionRoot(this.controller, this.enabled, this.bottomAligned);

  final AnimationController controller;
  bool enabled;
  bool bottomAligned;
  Size? _lastSize;
  bool _reset = true;
  bool _pending = false;
  int _generation = 0;
  List<_RenderMotionPart> _parts = [];

  double get progress =>
      _pending ? 0 : Curves.easeInOutCubic.transform(controller.value);
  Offset get anchor => bottomAligned ? Offset(0, size.height) : Offset.zero;

  void configure(bool animate, bool bottom) {
    if (enabled == animate && bottomAligned == bottom) return;
    enabled = animate;
    bottomAligned = bottom;
    _reset = true;
    markNeedsLayout();
  }

  void _tick() {
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _reset = true;
    _pending = false;
    controller.addListener(_tick);
  }

  @override
  void detach() {
    controller.removeListener(_tick);
    _generation++;
    super.detach();
  }

  @override
  void performLayout() {
    super.performLayout();
    final parts = <_RenderMotionPart>[];
    void collect(RenderObject node) {
      if (node is _RenderMotionPart) {
        parts.add(node);
      } else {
        node.visitChildren(collect);
      }
    }

    if (child case final body?) collect(body);
    _parts = parts;
    final reset =
        _reset ||
        !enabled ||
        _lastSize == null ||
        _lastSize!.width != size.width;
    final targets = <_RenderMotionPart, Offset>{
      for (final part in parts)
        part: MatrixUtils.transformPoint(
          part.getTransformTo(this),
          Offset.zero,
        ),
    };
    final changed = parts.any(
      (part) =>
          part.target != null &&
          ((part.target! - (targets[part]! - anchor)).distance > 0.01 ||
              part.targetHeight != part.layoutSize.height),
    );
    final t = progress;
    for (final part in parts) {
      final target = targets[part]! - anchor;
      final painted = part.paintedAnchor(t);
      final paintedHeight = part.paintedHeight(t);
      part
        ..root = this
        ..layoutOffset = targets[part]!;
      if (reset || part.target == null) {
        part
          ..begin = target
          ..target = target
          ..beginHeight = part.layoutSize.height
          ..targetHeight = part.layoutSize.height;
      } else if (changed) {
        part
          ..begin = painted
          ..target = target
          ..beginHeight = paintedHeight
          ..targetHeight = part.layoutSize.height;
      }
    }
    _lastSize = size;
    _reset = false;
    if (reset) {
      _pending = false;
      _generation++;
      controller.stop();
      controller.value = 1;
    } else if (changed) {
      // The size reporter commits the card's target after this layout. Start
      // painting the internal movement with that next frame, not before it.
      _pending = true;
      final generation = ++_generation;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!attached || generation != _generation) return;
        _pending = false;
        controller.forward(from: 0);
      });
    }
  }
}

class _MotionPart extends SingleChildRenderObjectWidget {
  const _MotionPart({required super.child});

  @override
  _RenderMotionPart createRenderObject(BuildContext context) =>
      _RenderMotionPart();
}

class _RenderMotionPart extends RenderProxyBox {
  _RenderMotionRoot? root;
  Offset? begin;
  Offset? target;
  double beginHeight = 0;
  double targetHeight = 0;
  Size layoutSize = Size.zero;
  Offset layoutOffset = Offset.zero;

  @override
  void performLayout() {
    super.performLayout();
    layoutSize = Size(size.width, size.height);
  }

  Offset paintedAnchor(double t) =>
      Offset.lerp(begin, target, t) ?? Offset.zero;

  double paintedHeight(double t) =>
      beginHeight + (targetHeight - beginHeight) * t;

  Offset get translation {
    final motion = root;
    if (motion == null || target == null) return Offset.zero;
    return paintedAnchor(motion.progress) + motion.anchor - layoutOffset;
  }

  double get visibleHeight {
    final motion = root;
    if (motion == null) return size.height;
    final top = layoutOffset.dy + translation.dy;
    final index = motion._parts.indexOf(this);
    for (final next in motion._parts.skip(index + 1)) {
      final horizontalOverlap =
          layoutOffset.dx < next.layoutOffset.dx + next.layoutSize.width &&
          layoutOffset.dx + size.width > next.layoutOffset.dx;
      if (horizontalOverlap && next.layoutOffset.dy >= layoutOffset.dy) {
        return (next.layoutOffset.dy + next.translation.dy - top).clamp(
          0.0,
          double.infinity,
        );
      }
    }
    return paintedHeight(motion.progress);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) return;
    final paintedOffset = offset + translation;
    // Reveal the new block only in the space its moving neighbour has freed.
    // This clips paint, without feeding intermediate heights into measurement.
    context.pushClipRect(
      needsCompositing,
      paintedOffset,
      Rect.fromLTWH(0, 0, size.width, visibleHeight),
      (context, offset) => context.paintChild(child!, offset),
    );
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final height = visibleHeight.clamp(0.0, size.height);
    if (!(translation & Size(size.width, height)).contains(position)) {
      return false;
    }
    if (!hitTestChildren(result, position: position)) return false;
    result.add(BoxHitTestEntry(this, position));
    return true;
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      result.addWithPaintOffset(
        offset: translation,
        position: position,
        hitTest: (result, transformed) =>
            child?.hitTest(result, position: transformed) ?? false,
      );

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final delta = translation;
    transform.translateByDouble(delta.dx, delta.dy, 0, 1);
  }
}
