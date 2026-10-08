import 'package:flutter/material.dart';

/// Measures only the new screen while the old login screen fades away.
class HomeLoginTransition extends StatefulWidget {
  const HomeLoginTransition({
    super.key,
    required this.isLoggedIn,
    required this.child,
  });

  final bool isLoggedIn;
  final Widget child;

  @override
  State<HomeLoginTransition> createState() => _HomeLoginTransitionState();
}

class _HomeLoginTransitionState extends State<HomeLoginTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _incoming;
  late final Animation<double> _outgoing;
  GlobalKey _currentKey = GlobalKey();
  GlobalKey? _previousKey;
  Widget? _previous;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 220),
          value: 1,
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed && _previous != null) {
            setState(() {
              _previous = null;
              _previousKey = null;
            });
          }
        });
    _incoming = _controller.drive(
      CurveTween(curve: const Interval(0.15, 1, curve: Curves.easeOutCubic)),
    );
    _outgoing = ReverseAnimation(
      _controller.drive(
        CurveTween(curve: const Interval(0, 0.35, curve: Curves.easeOutCubic)),
      ),
    );
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

    if (widget.isLoggedIn && !MediaQuery.disableAnimationsOf(context)) {
      _previous = oldWidget.child;
      _previousKey = _currentKey;
      _currentKey = GlobalKey();
      _controller.forward(from: 0);
    } else {
      // Logout removes authenticated content immediately, including mid-fade.
      _finishTransition();
    }
  }

  void _finishTransition() {
    _previous = null;
    _previousKey = null;
    _controller.value = 1;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Stack(
        alignment: Alignment.topLeft,
        children: [
          if (_previous != null)
            Positioned(
              top: 0,
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
          FadeTransition(
            opacity: _incoming,
            child: KeyedSubtree(key: _currentKey, child: widget.child),
          ),
        ],
      ),
    );
  }
}
