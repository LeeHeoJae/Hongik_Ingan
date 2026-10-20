import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

/// Checks decoration against painted content without feeding sizes into layout.
class HomeSplashSpace extends StatefulWidget {
  const HomeSplashSpace({super.key, required this.child});

  final Widget child;

  @override
  State<HomeSplashSpace> createState() => _HomeSplashSpaceState();
}

class _HomeSplashSpaceState extends State<HomeSplashSpace> {
  final _geometry = _SplashGeometry();

  @override
  void initState() {
    super.initState();
    _observeFrame();
  }

  void _observeFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Observe frames already requested by layout, scrolling or animation.
      // Do not request continuous frames while the splash is hidden or still.
      for (final guard in _geometry.guards.toList()) {
        guard.checkVisibility();
      }
      _observeFrame();
    });
  }

  @override
  Widget build(BuildContext context) => _SplashScope(
    geometry: _geometry,
    child: _SplashViewport(geometry: _geometry, child: widget.child),
  );
}

class _SplashScope extends InheritedWidget {
  const _SplashScope({required this.geometry, required super.child});

  final _SplashGeometry geometry;

  static _SplashGeometry? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SplashScope>()?.geometry;

  @override
  bool updateShouldNotify(_SplashScope oldWidget) =>
      geometry != oldWidget.geometry;
}

class _SplashViewport extends SingleChildRenderObjectWidget {
  const _SplashViewport({required this.geometry, required super.child});

  final _SplashGeometry geometry;

  @override
  RenderProxyBox createRenderObject(BuildContext context) {
    final box = RenderProxyBox();
    geometry.viewport = box;
    return box;
  }
}

/// Protects glyphs and controls, allowing decoration over empty card padding.
class HomeSplashContent extends SingleChildRenderObjectWidget {
  const HomeSplashContent({super.key, required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _ContentBox(_SplashScope.of(context), scanContents: true);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _ContentBox).geometry = _SplashScope.of(context);
  }
}

/// Protects a whole target, including blank parts of its hit area.
class HomeSplashObstacle extends HomeSplashContent {
  const HomeSplashObstacle({super.key, required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _ContentBox(_SplashScope.of(context), scanContents: false);
}

class HomeSplashGuard extends SingleChildRenderObjectWidget {
  const HomeSplashGuard({
    super.key,
    required this.polygon,
    required this.onVisibilityChanged,
    required super.child,
  });

  /// Maximum painted footprint in this box's coordinates, before pulsing.
  final List<Offset> polygon;
  final ValueChanged<bool> onVisibilityChanged;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _GuardBox(_SplashScope.of(context), polygon, onVisibilityChanged);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    final box = renderObject as _GuardBox;
    box.geometry = _SplashScope.of(context);
    if (!listEquals(box.polygon, polygon)) {
      box.polygon = polygon;
      box.markNeedsPaint();
    }
    box.onVisibilityChanged = onVisibilityChanged;
  }
}

class _ContentBox extends RenderProxyBox {
  _ContentBox(this._geometry, {required this.scanContents});

  final bool scanContents;
  _SplashGeometry? _geometry;

  set geometry(_SplashGeometry? value) {
    if (value == _geometry) return;
    _geometry?.contents.remove(this);
    _geometry = value;
    if (attached) _geometry?.contents.add(this);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _geometry?.contents.add(this);
  }

  @override
  void detach() {
    _geometry?.contents.remove(this);
    super.detach();
  }
}

class _GuardBox extends RenderProxyBox {
  _GuardBox(this._geometry, this.polygon, this.onVisibilityChanged);

  _SplashGeometry? _geometry;
  List<Offset> polygon;
  ValueChanged<bool> onVisibilityChanged;
  bool _visible = true;
  bool _notificationPending = false;

  set geometry(_SplashGeometry? value) {
    if (value == _geometry) return;
    _geometry?.guards.remove(this);
    _geometry = value;
    if (attached) _geometry?.guards.add(this);
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _geometry?.guards.add(this);
  }

  @override
  void detach() {
    _geometry?.guards.remove(this);
    super.detach();
  }

  void checkVisibility({bool painting = false}) {
    if (!attached || !hasSize) return;
    final visible = _geometry?.fits(this) ?? true;
    if (visible == _visible) return;
    _visible = visible;
    markNeedsSemanticsUpdate();
    if (!painting) markNeedsPaint();
    if (_notificationPending) return;
    _notificationPending = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _notificationPending = false;
      if (attached) onVisibilityChanged(_visible);
    });
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    checkVisibility(painting: true);
    if (_visible) super.paint(context, offset);
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    if (_visible) super.visitChildrenForSemantics(visitor);
  }
}

class _SplashGeometry {
  RenderBox? viewport;
  final contents = <_ContentBox>{};
  final guards = <_GuardBox>{};

  bool fits(_GuardBox guard) {
    final root = viewport;
    if (root == null || !root.attached || !root.hasSize) return false;
    final transform = guard.getTransformTo(root);
    final points = guard.polygon
        .map((point) => MatrixUtils.transformPoint(transform, point))
        .toList();
    final viewportRect = Offset.zero & root.size;
    final clip = _ancestorClip(guard, root, viewportRect);
    if (clip == null || points.any((point) => !clip.contains(point))) {
      return false;
    }
    final envelope = _bounds(points).inflate(2);
    final guardAncestors = <RenderObject>{};
    for (
      RenderObject? ancestor = guard;
      ancestor != null;
      ancestor = ancestor.parent
    ) {
      guardAncestors.add(ancestor);
      if (ancestor == root) break;
    }
    for (final content in contents) {
      if (!content.attached || !content.hasSize) continue;
      // The workspace registers detail/summary content below its viewport.
      // Skip those registrations too, but preserve shared page-scroll checks.
      if (_hasSeparateScrollViewport(content, guardAncestors)) continue;
      final contentClip = _ancestorClip(content, root, viewportRect);
      if (contentClip == null) continue;
      final region = MatrixUtils.transformRect(
        content.getTransformTo(root),
        Offset.zero & content.size,
      ).intersect(contentClip);
      if (!envelope.overlaps(region)) continue;
      if (!content.scanContents) {
        if (_intersects(points, region.inflate(2))) return false;
      } else if (_hitsContent(content, root, contentClip, points, envelope)) {
        return false;
      }
    }
    return true;
  }
}

bool _hasSeparateScrollViewport(
  RenderObject content,
  Set<RenderObject> guardAncestors,
) {
  for (
    RenderObject? ancestor = content.parent;
    ancestor != null && !guardAncestors.contains(ancestor);
    ancestor = ancestor.parent
  ) {
    if (ancestor is RenderAbstractViewport) return true;
  }
  return false;
}

bool _hidden(RenderObject object) =>
    (object is RenderOffstage && object.offstage) ||
    (object is RenderOpacity && object.opacity == 0) ||
    (object is RenderAnimatedOpacity && object.opacity.value == 0);

Rect? _ancestorClip(RenderObject object, RenderBox root, Rect clip) {
  RenderObject child = object;
  if (_hidden(child)) return null;
  while (child != root) {
    final parent = child.parent;
    if (parent == null || _hidden(parent)) return null;
    final localClip = parent.describeApproximatePaintClip(child);
    if (localClip != null) {
      clip = clip.intersect(
        MatrixUtils.transformRect(parent.getTransformTo(root), localClip),
      );
    }
    child = parent;
  }
  return clip;
}

bool _hitsContent(
  RenderObject object,
  RenderBox root,
  Rect clip,
  List<Offset> polygon,
  Rect envelope,
) {
  if (_hidden(object)) return false;
  // Internal scrolling must not toggle a stationary header decoration as rows
  // pass underneath it. Ancestor clips still protect the splash's own viewport.
  if (object is RenderAbstractViewport) return false;
  bool hits(Rect rect, {bool allowTextOverlap = false}) {
    final visible = MatrixUtils.transformRect(
      object.getTransformTo(root),
      rect,
    ).intersect(clip);
    // Permit a shallow overlap at text edges, but keep its central glyph area
    // readable. Controls retain their full target and the existing 2px margin.
    final inset = (visible.height * 0.35).clamp(0.0, 8.0);
    final protected = allowTextOverlap
        ? Rect.fromLTRB(
            visible.left,
            visible.top + inset,
            visible.right,
            visible.bottom - inset,
          )
        : visible.inflate(2);
    return !visible.isEmpty &&
        envelope.overlaps(visible) &&
        _intersects(polygon, protected);
  }

  if (object is RenderParagraph && object.hasSize) {
    for (final box in object.getBoxesForSelection(
      TextSelection(
        baseOffset: 0,
        extentOffset: object.text.toPlainText().length,
      ),
    )) {
      if (hits(box.toRect(), allowTextOverlap: true)) return true;
    }
    return false;
  }
  if (object is RenderBox &&
      object.hasSize &&
      (object is RenderEditable ||
          (object is RenderSemanticsAnnotations &&
              (object.properties.button == true ||
                  object.properties.textField == true)))) {
    return hits(Offset.zero & object.size);
  }
  var result = false;
  object.visitChildren((child) {
    if (result) return;
    final localClip = object.describeApproximatePaintClip(child);
    final childClip = localClip == null
        ? clip
        : clip.intersect(
            MatrixUtils.transformRect(object.getTransformTo(root), localClip),
          );
    if (!childClip.isEmpty) {
      result = _hitsContent(child, root, childClip, polygon, envelope);
    }
  });
  return result;
}

Rect _bounds(List<Offset> points) => points
    .map((point) => Rect.fromLTWH(point.dx, point.dy, 0, 0))
    .reduce((a, b) => a.expandToInclude(b));

// Separating-axis test avoids rejecting the empty corners of the rotated AABB.
bool _intersects(List<Offset> polygon, Rect rect) {
  final other = [
    rect.topLeft,
    rect.topRight,
    rect.bottomRight,
    rect.bottomLeft,
  ];
  final axes = [const Offset(1, 0), const Offset(0, 1)];
  for (var index = 0; index < polygon.length; index++) {
    final edge = polygon[(index + 1) % polygon.length] - polygon[index];
    axes.add(Offset(-edge.dy, edge.dx));
  }
  for (final axis in axes) {
    final first = polygon.map((p) => p.dx * axis.dx + p.dy * axis.dy).toList()
      ..sort();
    final second = other.map((p) => p.dx * axis.dx + p.dy * axis.dy).toList()
      ..sort();
    if (first.last <= second.first || second.last <= first.first) return false;
  }
  return true;
}
