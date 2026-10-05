import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class HomeContentSizeReporter extends SingleChildRenderObjectWidget {
  const HomeContentSizeReporter({
    super.key,
    required this.onSize,
    required super.child,
  });

  final ValueChanged<Size> onSize;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _ContentSizeRenderObject(onSize);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderObject renderObject,
  ) {
    (renderObject as _ContentSizeRenderObject).onSize = onSize;
  }
}

class _ContentSizeRenderObject extends RenderProxyBox {
  _ContentSizeRenderObject(this.onSize);

  ValueChanged<Size> onSize;
  Size? _lastSize;

  @override
  void performLayout() {
    super.performLayout();
    if (_lastSize == size) return;
    _lastSize = size;
    final measured = size;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (attached) onSize(measured);
    });
  }
}
