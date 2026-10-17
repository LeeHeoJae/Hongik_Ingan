import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../home_splash_messages.dart';
import 'home_splash_space.dart';

// Freeze only decorative motion in tests of unrelated home flows.
final homeSplashAnimationProvider = Provider<bool>((ref) => true);

class HomeSplashBrand extends ConsumerStatefulWidget {
  const HomeSplashBrand({
    super.key,
    this.messages = homeSplashMessages,
    this.hidden = false,
  });

  final List<String> messages;
  final bool hidden;

  @override
  ConsumerState<HomeSplashBrand> createState() => _HomeSplashBrandState();
}

class _HomeSplashBrandState extends ConsumerState<HomeSplashBrand> {
  late List<String> _candidates;
  String? _selected;
  bool _fits = true;

  void _visibilityChanged(bool visible) {
    if (mounted && _fits != visible) setState(() => _fits = visible);
  }

  @override
  void initState() {
    super.initState();
    _reset();
  }

  @override
  void didUpdateWidget(covariant HomeSplashBrand oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.messages, widget.messages)) _reset();
  }

  void _reset() {
    _candidates =
        widget.messages
            .where(
              (text) =>
                  text.trim().isNotEmpty && !text.contains(RegExp(r'[\r\n]')),
            )
            .toList()
          ..shuffle();
    _selected = _candidates.isEmpty ? null : _candidates.first;
  }

  Size _measure(
    BuildContext context,
    String text,
    TextStyle style,
    double width,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
    )..layout(maxWidth: width);
    final size = painter.size;
    painter.dispose();
    return size;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleStyle = theme.textTheme.titleLarge!.copyWith(
      fontWeight: FontWeight.w700,
      color: theme.colorScheme.onSurface,
    );
    final style = theme.textTheme.bodySmall!.copyWith(
      fontFamily: 'Pretendard',
      fontSize: 14,
      height: 1,
      letterSpacing: 0,
      fontWeight: FontWeight.w800,
      color: const Color(0xFFFFFF00),
    );
    final animate = ref.watch(homeSplashAnimationProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        final title = _measure(
          context,
          '홍익인간',
          titleStyle,
          constraints.maxWidth,
        );
        final brandWidth = title.width;
        final brandHeight = title.height;
        // Align the title to the logo's 44px row, not the splash envelope.
        final titleTop = (44 - title.height) / 2;
        final anchor = Offset(
          title.width,
          math.max(0, titleTop) + title.height,
        );
        String? visible;
        Size? padded;
        Rect? envelope;
        Rect? placement;
        final allowed =
            !widget.hidden && MediaQuery.viewInsetsOf(context).bottom == 0;
        if (allowed) {
          final text = _selected;
          if (text != null) {
            final size = _measure(context, text, style, double.infinity);
            final candidate = Size(size.width + 8, size.height + 8);
            final bounds = _splashEnvelope(candidate);
            visible = text;
            padded = candidate;
            envelope = bounds;
            placement = bounds.shift(anchor);
          }
        }
        final height = math.max(48.0, brandHeight);
        return SizedBox(
          height: height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                top: math.max(0, titleTop),
                width: brandWidth,
                child: Text('홍익인간', style: titleStyle),
              ),
              if (visible != null)
                Positioned(
                  key: const ValueKey('home-splash-bounds'),
                  left: placement!.left,
                  top: placement.top,
                  width: placement.width,
                  height: placement.height,
                  child: HomeSplashGuard(
                    polygon: _splashPolygon(
                      padded!,
                    ).map((point) => point - envelope!.topLeft).toList(),
                    onVisibilityChanged: _visibilityChanged,
                    child: IgnorePointer(
                      child: Semantics(
                        label: visible,
                        child: ExcludeSemantics(
                          child: _fits
                              ? RepaintBoundary(
                                  child: _PulsingSplash(
                                    text: visible,
                                    style: style,
                                    size: padded,
                                    anchor: -envelope!.topLeft,
                                    animate: animate,
                                  ),
                                )
                              : const SizedBox.expand(),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

const _angle = -20 * math.pi / 180;

List<Offset> _splashPolygon(Size size) =>
    [
          Offset(-size.width / 2, -4),
          Offset(size.width / 2, -4),
          Offset(size.width / 2, size.height - 4),
          Offset(-size.width / 2, size.height - 4),
        ]
        .map(
          (point) => Offset(
            point.dx * math.cos(_angle) - point.dy * math.sin(_angle),
            point.dx * math.sin(_angle) + point.dy * math.cos(_angle),
          ),
        )
        .toList();

// Bounds relative to the text's top-edge midpoint, excluding the 4px padding.
Rect _splashEnvelope(Size size) {
  final cosine = math.cos(_angle);
  final sine = math.sin(_angle);
  return Rect.fromLTRB(
    -size.width / 2 * cosine + 4 * sine,
    size.width / 2 * sine - 4 * cosine,
    size.width / 2 * cosine - (size.height - 4) * sine,
    -size.width / 2 * sine + (size.height - 4) * cosine,
  );
}

class _PulsingSplash extends StatefulWidget {
  const _PulsingSplash({
    required this.text,
    required this.style,
    required this.size,
    required this.animate,
    required this.anchor,
  });
  final String text;
  final TextStyle style;
  final Size size;
  final bool animate;
  final Offset anchor;

  @override
  State<_PulsingSplash> createState() => _PulsingSplashState();
}

class _PulsingSplashState extends State<_PulsingSplash>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void _updateMotion() {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    final enabled =
        widget.animate &&
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled &&
        (lifecycle == null || lifecycle == AppLifecycleState.resumed);
    if (enabled && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!enabled) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateMotion();
  }

  @override
  void didUpdateWidget(covariant _PulsingSplash oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateMotion();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _updateMotion();

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final outline = Paint()
      ..color = const Color(0xFF252525)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final alignment = Alignment(0, -1 + 8 / widget.size.height);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: widget.anchor.dx - widget.size.width / 2,
          top: widget.anchor.dy - 4,
          width: widget.size.width,
          height: widget.size.height,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) => Transform.rotate(
              angle: _angle,
              alignment: alignment,
              child: Transform.scale(
                alignment: alignment,
                scale:
                    (1.8 -
                        0.1 * math.sin(_controller.value * 2 * math.pi).abs()) /
                    1.8,
                child: child,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Stack(
                children: [
                  Text(
                    widget.text,
                    maxLines: 1,
                    softWrap: false,
                    style: widget.style.copyWith(
                      color: null,
                      foreground: outline,
                    ),
                  ),
                  Text(
                    widget.text,
                    key: const ValueKey('home-splash-text'),
                    maxLines: 1,
                    softWrap: false,
                    style: widget.style.copyWith(
                      shadows: const [
                        Shadow(color: Color(0xFF252525), offset: Offset(1, 1)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
