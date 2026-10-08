import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class HomeContentSizeReporter extends SingleChildRenderObjectWidget {
  const HomeContentSizeReporter({
    super.key,
    required this.onSize,
    required super.child,
    this.measurementKey,
  });

  final ValueChanged<Size> onSize;

  /// Resamples new content even when its size is unchanged, preserving children.
  final Object? measurementKey;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _ContentSizeRenderObject(onSize, measurementKey);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderObject renderObject,
  ) {
    final reporter = renderObject as _ContentSizeRenderObject;
    reporter.onSize = onSize;
    reporter.updateMeasurementKey(measurementKey);
  }
}

class _ContentSizeRenderObject extends RenderProxyBox {
  _ContentSizeRenderObject(this.onSize, this._measurementKey);

  ValueChanged<Size> onSize;
  Size? _lastSize;
  Object? _measurementKey;

  void updateMeasurementKey(Object? key) {
    if (_measurementKey == key) return;
    _measurementKey = key;
    _lastSize = null;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    super.performLayout();
    if (_lastSize == size) return;
    _lastSize = size;
    final measured = size;
    final measuredKey = _measurementKey;
    final callback = onSize;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (attached && _measurementKey == measuredKey) callback(measured);
    });
  }
}
