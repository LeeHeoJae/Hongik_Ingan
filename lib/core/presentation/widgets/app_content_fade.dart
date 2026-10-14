import 'package:flutter/material.dart';

/// Fades the current content without retaining an old layout or child subtree.
class AppContentFade extends StatefulWidget {
  const AppContentFade({
    super.key,
    required this.changeKey,
    required this.child,
    this.animateInitially = false,
    this.duration = const Duration(milliseconds: 180),
  });

  final Object? changeKey;
  final Widget child;
  final bool animateInitially;
  final Duration duration;

  @override
  State<AppContentFade> createState() => _AppContentFadeState();
}

class _AppContentFadeState extends State<AppContentFade>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: widget.animateInitially ? 0 : 1,
  );
  late final Animation<double> _opacity = _controller.drive(
    CurveTween(curve: Curves.easeOutCubic),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else if (!_controller.isCompleted && !_controller.isAnimating) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(AppContentFade oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.duration = widget.duration;
    if (oldWidget.changeKey == widget.changeKey) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else if (!_controller.isAnimating) {
      // Rapid selections keep progressing instead of flashing back to zero.
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      FadeTransition(opacity: _opacity, child: widget.child);
}
