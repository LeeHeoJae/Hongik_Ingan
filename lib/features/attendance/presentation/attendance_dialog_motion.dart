import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Shared geometry for the surface, its contents and keyboard repositioning.
class AttendanceDialogGeometry {
  AttendanceDialogGeometry(this.controller);

  final AnimationController controller;
  double targetInset = 0;
  double inset = 0;
  double height = 0;
  bool enabled = true;
  bool hold = false;
  bool frozen = false;
}

class AttendanceDialogPlacement extends SingleChildRenderObjectWidget {
  const AttendanceDialogPlacement({
    super.key,
    required this.geometry,
    required this.verticalInset,
    required super.child,
  });

  final AttendanceDialogGeometry geometry;
  final double verticalInset;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderDialogPlacement(geometry, verticalInset);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    final placement = renderObject as _RenderDialogPlacement;
    placement.verticalInset = verticalInset;
    placement.markNeedsLayout();
  }
}

class _RenderDialogPlacement extends RenderShiftedBox {
  _RenderDialogPlacement(this.geometry, this.verticalInset) : super(null);

  final AttendanceDialogGeometry geometry;
  double verticalInset;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    geometry.controller.addListener(markNeedsLayout);
  }

  @override
  void detach() {
    geometry.controller.removeListener(markNeedsLayout);
    super.detach();
  }

  @override
  void performLayout() {
    size = constraints.biggest;
    child!.layout(
      constraints.copyWith(
        minHeight: 0,
        maxHeight: (size.height - geometry.targetInset).clamp(0, size.height),
      ),
      parentUsesSize: true,
    );
    final data = child!.parentData! as BoxParentData;
    data.offset = Offset(
      0,
      ((size.height - geometry.inset - geometry.height) / 2 - verticalInset)
          .clamp(0, double.infinity),
    );
  }
}

class AttendanceDialogFrame extends MultiChildRenderObjectWidget {
  AttendanceDialogFrame({
    super.key,
    required this.geometry,
    required this.padding,
    required this.gap,
    required Widget header,
    required Widget body,
    required Widget action,
  }) : super(children: [header, body, action]);

  final AttendanceDialogGeometry geometry;
  final EdgeInsets padding;
  final double gap;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderDialogFrame(geometry, padding, gap);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderDialogFrame)
      ..padding = padding
      ..gap = gap
      ..markNeedsLayout();
  }
}

class _FrameGeometry {
  const _FrameGeometry(this.height, this.inset, this.padding, this.gap);

  final double height;
  final double inset;
  final EdgeInsets padding;
  final double gap;

  _FrameGeometry lerp(_FrameGeometry other, double t) => _FrameGeometry(
    height + (other.height - height) * t,
    inset + (other.inset - inset) * t,
    EdgeInsets.lerp(padding, other.padding, t)!,
    gap + (other.gap - gap) * t,
  );

  bool sameAs(_FrameGeometry other) =>
      height == other.height &&
      inset == other.inset &&
      padding == other.padding &&
      gap == other.gap;
}

class _DialogFrameParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderDialogFrame extends RenderBox
    with
        ContainerRenderObjectMixin<
          RenderBox,
          ContainerBoxParentData<RenderBox>
        >,
        RenderBoxContainerDefaultsMixin<
          RenderBox,
          ContainerBoxParentData<RenderBox>
        > {
  _RenderDialogFrame(this.geometry, this.padding, this.gap);

  final AttendanceDialogGeometry geometry;
  EdgeInsets padding;
  double gap;
  _FrameGeometry? _from;
  _FrameGeometry? _target;
  bool _pending = false;
  int _generation = 0;

  _FrameGeometry get current => _from!.lerp(
    _target!,
    _pending ? 0 : Curves.easeInOutCubic.transform(geometry.controller.value),
  );

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! ContainerBoxParentData<RenderBox>) {
      child.parentData = _DialogFrameParentData();
    }
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    geometry.controller.addListener(markNeedsLayout);
  }

  @override
  void detach() {
    _generation++;
    _pending = false;
    geometry.controller.removeListener(markNeedsLayout);
    super.detach();
  }

  @override
  void performLayout() {
    final children = getChildrenAsList();
    final header = children[0];
    final body = children[1];
    final action = children[2];
    final innerWidth = (constraints.maxWidth - padding.horizontal).clamp(
      0.0,
      double.infinity,
    );
    final natural = BoxConstraints.tightFor(width: innerWidth);
    for (final child in children) {
      child.layout(natural, parentUsesSize: true);
    }
    final target = _FrameGeometry(
      constraints.constrainHeight(
        padding.vertical +
            header.size.height +
            4 +
            body.size.height +
            gap +
            action.size.height,
      ),
      geometry.targetInset,
      padding,
      gap,
    );
    if (_target == null || !geometry.enabled) {
      _generation++;
      _pending = false;
      _from = _target = target;
    } else if (!geometry.hold && !geometry.frozen && !_target!.sameAs(target)) {
      _from = current;
      _target = target;
      _pending = true;
      final generation = ++_generation;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!attached || generation != _generation || geometry.frozen) return;
        _pending = false;
        geometry.controller.forward(from: 0);
      });
    }
    final frame = current;
    size = constraints.constrain(Size(constraints.maxWidth, frame.height));
    geometry.height = size.height;
    geometry.inset = frame.inset;
    final bodyTop = frame.padding.top + header.size.height + 4;
    final actionTop = size.height - frame.padding.bottom - action.size.height;
    body.layout(
      natural.copyWith(
        maxHeight: (actionTop - frame.gap - bodyTop).clamp(0, double.infinity),
      ),
      parentUsesSize: true,
    );
    (header.parentData! as BoxParentData).offset = Offset(
      frame.padding.left,
      frame.padding.top,
    );
    (body.parentData! as BoxParentData).offset = Offset(
      frame.padding.left,
      bodyTop,
    );
    (action.parentData! as BoxParentData).offset = Offset(
      frame.padding.left,
      actionTop,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final children = getChildrenAsList();
    for (var index = 0; index < children.length; index++) {
      final child = children[index];
      final childOffset = (child.parentData! as BoxParentData).offset;
      if (index == 1) {
        context.pushClipRect(
          needsCompositing,
          offset,
          childOffset & child.size,
          (context, offset) => context.paintChild(child, offset + childOffset),
        );
      } else {
        context.paintChild(child, offset + childOffset);
      }
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  Rect? describeApproximatePaintClip(RenderObject child) =>
      child == childAfter(firstChild!)
      ? (child.parentData! as BoxParentData).offset & (child as RenderBox).size
      : null;

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final offset = (child.parentData! as BoxParentData).offset;
    transform.translateByDouble(offset.dx, offset.dy, 0, 1);
  }
}
