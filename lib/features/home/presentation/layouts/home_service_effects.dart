import 'package:flutter/material.dart';
import 'package:hongik_ingan/core/presentation/app_motion.dart';
import 'package:hongik_ingan/core/theme/color.dart';

import '../widgets/home_attendance_action_layout.dart';

/// Keeps both service subtrees mounted while fading them within the card move.
class HomeServiceContentLayer extends StatefulWidget {
  const HomeServiceContentLayer({
    super.key,
    required this.visible,
    required this.duration,
    required this.child,
    this.contentSize,
  });

  final bool visible;
  final Duration duration;
  final Widget child;
  final Size? contentSize;

  @override
  State<HomeServiceContentLayer> createState() =>
      HomeServiceContentLayerState();
}

class HomeServiceContentLayerState extends State<HomeServiceContentLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: 1,
  );
  late Animation<double> _opacity = AlwaysStoppedAnimation(
    widget.visible ? 1 : 0,
  );
  late Size? _layoutSize = widget.contentSize;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (!widget.visible &&
          _opacity.value == 0 &&
          _layoutSize != widget.contentSize) {
        // Resume offstage measurement at the latest viewport size as soon as
        // the old body is no longer painted, without replaying its fade.
        setState(() => _layoutSize = widget.contentSize);
      }
    });
  }

  void _finish() {
    _layoutSize = widget.contentSize;
    _opacity = AlwaysStoppedAnimation(widget.visible ? 1 : 0);
    _controller.value = 1;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) _finish();
  }

  @override
  void didUpdateWidget(HomeServiceContentLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // An outgoing detail still belongs to its previous primary layout. The
    // next service's height must not change its scale before it has faded out.
    if (widget.visible || _opacity.value == 0) {
      _layoutSize = widget.contentSize;
    }
    _controller.duration = widget.duration;
    if (widget.duration == Duration.zero ||
        MediaQuery.disableAnimationsOf(context)) {
      _finish();
    } else if (oldWidget.visible != widget.visible) {
      // Retarget from the painted opacity when a card changes direction.
      _opacity =
          Tween<double>(begin: _opacity.value, end: widget.visible ? 1 : 0)
              .chain(
                CurveTween(
                  curve: widget.visible
                      ? AppMotion.layoutIncomingCurve
                      : AppMotion.layoutOutgoingCurve,
                ),
              )
              .animate(_controller);
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: !widget.visible,
    child: ExcludeFocus(
      excluding: !widget.visible,
      child: ExcludeSemantics(
        excluding: !widget.visible,
        child: AnimatedBuilder(
          animation: _controller,
          child: _layoutSize == null
              ? widget.child
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final size = _layoutSize!;
                    final widthScale = size.width > 0
                        ? (constraints.maxWidth / size.width).clamp(0.0, 1.0)
                        : 1.0;
                    final cardHeight = HomeAttendanceCardScope.heightOf(
                      context,
                    );
                    // Fit the content to card width only. A card height change
                    // must not scale its text and controls during re-layout.
                    final scale = widthScale;
                    return SizedBox(
                      // Reserve the painted height, not the unscaled layout
                      // height, so bottom anchoring follows the moving card.
                      height: size.height * scale,
                      child: OverflowBox(
                        alignment: Alignment.topLeft,
                        minWidth: size.width,
                        maxWidth: size.width,
                        minHeight: size.height,
                        maxHeight: size.height,
                        child: Transform.scale(
                          alignment: Alignment.topLeft,
                          scale: scale,
                          // The action uses card coordinates before this paint
                          // transform; compensate once to keep its painted
                          // center at the current card's center.
                          child: HomeAttendanceCardScope(
                            height: cardHeight == null || scale == 0
                                ? size.height
                                : cardHeight / scale,
                            availableHeight:
                                HomeAttendanceCardScope.availableHeightOf(
                                  context,
                                ) ??
                                size.height,
                            child: widget.child,
                          ),
                        ),
                      ),
                    );
                  },
                ),
          builder: (context, child) => Offstage(
            offstage: !widget.visible && _opacity.value == 0,
            child: FadeTransition(
              opacity: _opacity,
              alwaysIncludeSemantics: true,
              child: child,
            ),
          ),
        ),
      ),
    ),
  );
}

class HomeServiceAttentionSurface extends StatefulWidget {
  const HomeServiceAttentionSurface({
    super.key,
    required this.serviceName,
    required this.attentionKey,
    required this.attentionScope,
    required this.isPrimary,
    required this.child,
  });

  final String serviceName;
  final String? attentionKey;
  final String? attentionScope;
  final bool isPrimary;
  final Widget child;

  @override
  State<HomeServiceAttentionSurface> createState() =>
      HomeServiceAttentionSurfaceState();
}

class HomeServiceAttentionSurfaceState
    extends State<HomeServiceAttentionSurface>
    with SingleTickerProviderStateMixin {
  final Set<String> _seen = {};
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );
  late final Animation<double> _pulse = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 0.0,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 20,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: 0.0,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 80,
    ),
  ]).animate(_controller);

  bool get _emphasized => widget.attentionKey != null;

  @override
  void initState() {
    super.initState();
    if (widget.attentionKey case final key?) _seen.add(key);
  }

  @override
  void didUpdateWidget(covariant HomeServiceAttentionSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.attentionScope != widget.attentionScope) _seen.clear();
    final key = widget.attentionKey;
    final discovered = key != null && _seen.add(key);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (_emphasized &&
        !widget.isPrimary &&
        discovered &&
        !_controller.isAnimating &&
        !MediaQuery.disableAnimationsOf(context) &&
        (lifecycle == null || lifecycle == AppLifecycleState.resumed)) {
      _controller.forward(from: 0);
    } else if (!_emphasized || widget.isPrimary) {
      _controller.reset();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) _controller.reset();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette =
        Theme.of(context).extension<HongikPalette>() ?? HongikPalette.light;
    final theme = Theme.of(context);
    final light = theme.brightness == Brightness.light;
    final surface = palette.cardSurface;
    return AnimatedBuilder(
      animation: _pulse,
      child: widget.child,
      builder: (context, child) => Material(
        key: ValueKey('home-service-${widget.serviceName}'),
        color: _emphasized && !widget.isPrimary
            ? Color.alphaBlend(
                theme.colorScheme.primary.withValues(
                  alpha: 0.04 + _pulse.value * 0.08,
                ),
                surface,
              )
            : surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: _emphasized
              ? BorderSide(color: theme.colorScheme.primary, width: 2)
              : light
              ? BorderSide.none
              : BorderSide(color: palette.cardOutline),
        ),
        clipBehavior: Clip.antiAlias,
        shadowColor: palette.cardShadow,
        elevation:
            widget.isPrimary && Theme.of(context).brightness == Brightness.light
            ? 1
            : 0,
        child: child,
      ),
    );
  }
}
