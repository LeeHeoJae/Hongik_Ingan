import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hongik_ingan/core/presentation/app_motion.dart';
import 'package:hongik_ingan/core/theme/color.dart';

import 'home_service_effects.dart';

import '../widgets/home_content_size_reporter.dart';
import '../widgets/home_attendance_action_layout.dart';
import '../widgets/home_attendance_density.dart';
import '../widgets/home_mobile_header.dart';
import '../widgets/home_mobile_layout.dart';

enum HomeService { attendance, seat, menu }

extension HomeServiceLabel on HomeService {
  String get title => switch (this) {
    HomeService.attendance => '로그인·출결',
    HomeService.seat => '열람실',
    HomeService.menu => '학식 메뉴',
  };

  IconData get icon => switch (this) {
    HomeService.attendance => Icons.check_circle_rounded,
    HomeService.seat => Icons.local_library_rounded,
    HomeService.menu => Icons.restaurant_menu_rounded,
  };

  Color iconBackgroundColor(ThemeData theme) {
    return switch (this) {
      HomeService.attendance => theme.colorScheme.primaryContainer,
      HomeService.seat => theme.colorScheme.secondaryContainer,
      HomeService.menu => theme.colorScheme.tertiaryContainer,
    };
  }

  Color iconColor(ThemeData theme) {
    final palette = theme.extension<HongikPalette>() ?? HongikPalette.light;
    final dark = theme.brightness == Brightness.dark;
    return switch (this) {
      HomeService.attendance => palette.brandNavy,
      HomeService.seat =>
        dark ? theme.colorScheme.onSecondaryContainer : palette.seatAvailable,
      HomeService.menu =>
        dark ? theme.colorScheme.onTertiaryContainer : AppColor.wowAutumn,
    };
  }

  Color summaryIconColor(ThemeData theme) {
    final palette = theme.extension<HongikPalette>() ?? HongikPalette.light;
    if (this == HomeService.attendance &&
        theme.brightness == Brightness.light) {
      return palette.brandBlue;
    }
    return iconColor(theme);
  }
}

typedef HomeServiceDetailBuilder = Widget Function(
  HomeService service,
  bool isPrimary,
);
typedef HomeServiceSummaryBuilder = HomeServiceSummaryData Function(
  HomeService service,
  WidgetRef ref,
);

class HomeServiceSummaryData {
  const HomeServiceSummaryData({
    required this.status,
    this.eyebrow,
    this.secondary,
    this.warning,
    this.compactWarning,
    this.attentionKey,
    this.availableSeats,
    this.hasMenuChoices = false,
    this.leadingMenuIndex,
    this.facts = const [],
  });

  final String status;
  final String? eyebrow;
  final String? secondary;
  final String? warning;
  final String? compactWarning;
  final String? attentionKey;
  final int? availableSeats;
  final bool hasMenuChoices;
  final int? leadingMenuIndex;
  final List<({String label, String value})> facts;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HomeServiceSummaryData &&
          status == other.status &&
          eyebrow == other.eyebrow &&
          secondary == other.secondary &&
          warning == other.warning &&
          compactWarning == other.compactWarning &&
          attentionKey == other.attentionKey &&
          availableSeats == other.availableSeats &&
          hasMenuChoices == other.hasMenuChoices &&
          leadingMenuIndex == other.leadingMenuIndex &&
          listEquals(facts, other.facts);

  @override
  int get hashCode => Object.hash(
    status,
    eyebrow,
    secondary,
    warning,
    compactWarning,
    attentionKey,
    availableSeats,
    hasMenuChoices,
    leadingMenuIndex,
    Object.hashAll(facts),
  );
}

class _SummaryStatus extends StatelessWidget {
  const _SummaryStatus({
    required this.service,
    required this.data,
    this.compact = false,
  });

  final HomeService service;
  final HomeServiceSummaryData data;
  final bool compact;

  static TextSpan menuSpan(
    String text,
    int? leadingIndex,
    TextStyle? style,
    Color highlight,
  ) {
    final marker = leadingIndex == 0
        ? 'A안'
        : leadingIndex == 1
        ? 'B안'
        : null;
    final start = marker == null
        ? -1
        : leadingIndex == 0 && text.startsWith(marker)
        ? 0
        : text.indexOf('\n$marker') + 1;
    if (start < 0) return TextSpan(text: text, style: style);
    if (!text.substring(start).startsWith(marker!)) {
      return TextSpan(text: text, style: style);
    }
    final newline = text.indexOf('\n', start);
    final end = newline < 0 ? text.length : newline;
    return TextSpan(
      style: style,
      children: [
        TextSpan(text: text.substring(0, start)),
        TextSpan(
          style: TextStyle(color: highlight),
          children: [
            TextSpan(
              text: marker,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: text.substring(start + marker.length, end)),
          ],
        ),
        TextSpan(text: text.substring(end)),
      ],
    );
  }

  static TextSpan seatSpan(
    ThemeData theme,
    HomeServiceSummaryData data, {
    required bool compact,
  }) => TextSpan(
    style: theme.textTheme.bodyMedium,
    children: [
      TextSpan(
        text: '${data.availableSeats}',
        style: theme.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: compact ? 24 : 36,
          color: theme.colorScheme.onSurface,
        ),
      ),
      TextSpan(text: '석 남음', style: theme.textTheme.bodyMedium),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (service == HomeService.seat && data.availableSeats != null) {
      return Text.rich(seatSpan(theme, data, compact: compact));
    }
    if (service == HomeService.menu) {
      final lines = data.status.split('\n');
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < lines.length; index++) ...[
            if (index > 0) const SizedBox(height: 10),
            Text.rich(
              TextSpan(
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                  fontWeight: FontWeight.w400,
                  color: data.leadingMenuIndex == index
                      ? theme.colorScheme.primary
                      : null,
                ),
                children: data.leadingMenuIndex == index
                    ? [
                        TextSpan(
                          text: lines[index].substring(0, 2),
                          semanticsLabel:
                              '${lines[index].substring(0, 2)}, 투표 수 우세',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        TextSpan(text: lines[index].substring(2)),
                      ]
                    : [TextSpan(text: lines[index])],
              ),
            ),
          ],
        ],
      );
    }
    return Text(
      data.status,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}

class HomeServiceWorkspace extends ConsumerStatefulWidget {
  static double minimumMobileSummaryHeight(
    BuildContext context,
    HomeService service,
    HomeServiceSummaryData data,
    double width,
  ) => _SummaryContent.minimumHeight(context, service, data, width);

  static bool usesWideLayout(double width) {
    final sideWidth = (width * 0.25).clamp(230.0, 300.0);
    return width - sideWidth - 12 >= 640;
  }

  const HomeServiceWorkspace({
    super.key,
    required this.availableHeight,
    required this.detailBuilder,
    required this.summaryBuilder,
    this.onPrimaryChanged,
    this.wideHeader,
    this.wideHeaderHeight = 48,
    this.reserveWideHeaderSpace = false,
    this.attentionScope,
    required this.viewportHeight,
    this.adaptiveMobileLayout = false,
    this.balanceMobileAttendance = false,
    this.mobileHeaderGap = 16,
    this.onAttendanceHeightChanged,
    this.mobileHeader,
    this.mobileHeaderHeight = 48,
    this.flexibleMobileHeader = false,
    this.attendanceLayoutKey,
    this.mobileLayout,
    this.attendanceHeightReduction,
    this.animateLayout = true,
    this.holdLayout = false,
  });

  final double availableHeight;
  final HomeServiceDetailBuilder detailBuilder;
  final HomeServiceSummaryBuilder summaryBuilder;
  final ValueChanged<HomeService>? onPrimaryChanged;
  final Widget? wideHeader;
  final double wideHeaderHeight;

  /// Keep card centers stable when the header includes secondary content.
  final bool reserveWideHeaderSpace;
  final String? attentionScope;

  /// Height left for the workspace after the page header, footer and padding.
  final double viewportHeight;
  final bool adaptiveMobileLayout;
  final bool balanceMobileAttendance;
  final double mobileHeaderGap;
  final ValueChanged<double>? onAttendanceHeightChanged;
  final Widget? mobileHeader;
  final double mobileHeaderHeight;
  final bool flexibleMobileHeader;
  final bool animateLayout;
  final bool holdLayout;
  final Object? attendanceLayoutKey;
  final HomeMobileLayout? mobileLayout;
  final double Function(HomeAttendanceDensity)? attendanceHeightReduction;

  double _mobileAttendanceReduction(HomeAttendanceDensity density) =>
      attendanceHeightReduction?.call(density) ?? density.heightReduction;

  @override
  ConsumerState<HomeServiceWorkspace> createState() =>
      _HomeServiceWorkspaceState();
}

class _HomeServiceWorkspaceState extends ConsumerState<HomeServiceWorkspace> {
  double _detailPreferredHeight(
    HomeService service,
    double width,
    double textScale,
  ) {
    final extraScale = math.max(0.0, textScale - 1);
    return switch (service) {
      HomeService.seat =>
        width - 32 >= 560 * textScale
            ? 420 + extraScale * 160
            : 660 + extraScale * 320,
      HomeService.menu => 560 + extraScale * 160,
      HomeService.attendance => double.infinity,
    };
  }

  bool _awaitingAttendanceMeasurement = false;
  ({
    double mainHeight,
    double gap,
    double auxHeight,
    double height,
    double headerTop,
    double headerScale,
    double pageTopPadding,
    HomeAttendanceDensity density,
    double extraSpace,
    double summaryCompression,
  })?
  _mobileGeometry;
  final Map<HomeService, double> _contentHeights = {};
  final Map<HomeService, double> _summaryHeights = {};
  Map<HomeService, double>? _heldContentHeights;
  Map<HomeService, double>? _heldSummaryHeights;
  Size? _mobileGeometryViewport;
  double? _mobileGeometryTextScale;
  final List<HomeService> _slots = [
    HomeService.seat,
    HomeService.attendance,
    HomeService.menu,
  ];
  // Keep the incoming primary surface above cards crossing its path.
  Iterable<HomeService> get _paintOrder sync* {
    for (final service in HomeService.values) {
      if (service != _slots[1]) yield service;
    }
    yield _slots[1];
  }

  final Map<HomeService, FocusNode> _detailFocusNodes = {
    for (final service in HomeService.values)
      service: FocusNode(debugLabel: '${service.name} detail'),
  };

  @override
  void didUpdateWidget(covariant HomeServiceWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.holdLayout && !oldWidget.holdLayout) {
      _heldContentHeights = Map.of(_contentHeights);
      _heldSummaryHeights = Map.of(_summaryHeights);
    } else if (!widget.holdLayout) {
      _heldContentHeights = null;
      _heldSummaryHeights = null;
    }
    if (widget.attendanceLayoutKey != oldWidget.attendanceLayoutKey) {
      _awaitingAttendanceMeasurement = true;
    }
  }

  @override
  void dispose() {
    for (final node in _detailFocusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  void _promote(HomeService service) {
    final selectedSlot = _slots.indexOf(service);
    if (selectedSlot == 1) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _slots[selectedSlot] = _slots[1];
      _slots[1] = service;
    });
    widget.onPrimaryChanged?.call(service);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _detailFocusNodes[service]?.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (widget.adaptiveMobileLayout) {
          return Consumer(
            builder: (context, ref, _) =>
                _buildMobileWorkspace(context, constraints, textScale, ref),
          );
        }
        final width = constraints.maxWidth;
        var gap = 12.0;
        final proposedSideWidth = (width * 0.25).clamp(230.0, 300.0);
        final wide = HomeServiceWorkspace.usesWideLayout(width);
        final measuredHeight =
            (_heldContentHeights ?? _contentHeights)[_slots[1]] ?? 280.0;
        final rowLayout = !wide
            ? HomeMobileLayout.fit(
                viewportHeight: widget.viewportHeight,
                minimumMainHeight: _slots[1] == HomeService.attendance
                    ? measuredHeight
                    : 320,
                attendanceIsPrimary: _slots[1] == HomeService.attendance,
                textScale: textScale,
                minimumAuxiliaryHeight: [
                  for (final service in [_slots[0], _slots[2]])
                    _SummaryContent.minimumHeight(
                      context,
                      service,
                      widget.summaryBuilder(service, ref),
                      (width - 12) / 2,
                    ),
                ].reduce(math.max),
              )
            : null;
        gap = rowLayout?.gap ?? gap;
        var density = rowLayout?.density ?? HomeAttendanceDensity.regular;
        var summaryCompression = rowLayout?.summaryCompression ?? 0.0;
        final sideWidth = wide ? proposedSideWidth : 0.0;
        final mainWidth = wide ? width - sideWidth - gap : width;
        final auxWidth = wide ? sideWidth : (width - gap) / 2;
        final auxHeight = wide
            ? 0.0
            : rowLayout?.auxiliaryHeight ??
                  HomeMobileLayout.normalAuxiliaryHeight(textScale);
        final stableDetailHeight = _slots[1] != HomeService.attendance;
        final wideHeaderExtent = widget.wideHeader == null
            ? 0.0
            : widget.wideHeaderHeight + gap;
        final summaryHeights = _heldSummaryHeights ?? _summaryHeights;
        final naturalSideHeight = summaryHeights[_slots[0]] ?? 200.0;
        final naturalBottomSideHeight = summaryHeights[_slots[2]] ?? 200.0;
        double wideExtent(double main, double compression) {
          final side =
              naturalSideHeight +
              naturalBottomSideHeight +
              gap -
              60 * compression;
          final content = math.max(main, side);
          if (widget.reserveWideHeaderSpace) return content + wideHeaderExtent;
          return content +
              math.max(0.0, wideHeaderExtent - (content - side) / 2);
        }

        if (wide) {
          final target = stableDetailHeight
              ? HomeMobileLayout.minimumDetailViewportHeight(textScale)
              : measuredHeight;
          if (!stableDetailHeight) {
            for (final candidate in HomeAttendanceDensity.values) {
              density = candidate;
              if (wideExtent(target - density.heightReduction, 0) <=
                  widget.viewportHeight) {
                break;
              }
            }
          }
          final fitted =
              target - (stableDetailHeight ? 0 : density.heightReduction);
          if (wideExtent(fitted, 0) > widget.viewportHeight) {
            // Summaries give up their padding only after primary spacing.
            var low = 0.0;
            var high = 1.0;
            for (var step = 0; step < 16; step++) {
              final middle = (low + high) / 2;
              if (wideExtent(fitted, middle) > widget.viewportHeight) {
                low = middle;
              } else {
                high = middle;
              }
            }
            summaryCompression = high;
          }
        }
        final minimumDetailHeight =
            HomeMobileLayout.minimumDetailViewportHeight(textScale);
        final preferredDetailViewportHeight = stableDetailHeight
            ? _detailPreferredHeight(_slots[1], mainWidth, textScale)
            : wide
            ? math.max(
                minimumDetailHeight,
                math.min(720.0, widget.viewportHeight - wideHeaderExtent),
              )
            : math.max(320.0, math.min(560.0, widget.availableHeight - 140));
        final viewportContentHeight =
            widget.viewportHeight - (wide ? wideHeaderExtent : auxHeight + gap);
        final fittedWideHeight = wide
            ? math.min(
                widget.viewportHeight,
                2 * (widget.viewportHeight - wideHeaderExtent) -
                    naturalSideHeight -
                    naturalBottomSideHeight -
                    gap +
                    60 * summaryCompression,
              )
            : viewportContentHeight;
        final detailViewportHeight = math.min(
          preferredDetailViewportHeight,
          math.max(
            minimumDetailHeight,
            wide
                ? fittedWideHeight
                : rowLayout?.mainHeight ?? viewportContentHeight,
          ),
        );
        final uncappedMainHeight = stableDetailHeight
            ? detailViewportHeight
            : rowLayout?.mainHeight ??
                  math.max(0.0, measuredHeight - density.heightReduction);
        final mainHeight = uncappedMainHeight;
        final sideHeight = wide
            ? naturalSideHeight - 30 * summaryCompression
            : auxHeight;
        final bottomSideHeight = wide
            ? naturalBottomSideHeight - 30 * summaryCompression
            : auxHeight;
        final contentHeight = wide
            ? math.max(mainHeight, sideHeight + gap + bottomSideHeight)
            : mainHeight + gap + auxHeight;
        // A tall decorative header reserves a stable band so changes in main
        // content height cannot move the cards' shared center.
        final headerLeading = wide && widget.wideHeader != null
            ? widget.reserveWideHeaderSpace
                  ? wideHeaderExtent
                  : math.max(
                      0.0,
                      wideHeaderExtent -
                          (contentHeight -
                                  sideHeight -
                                  gap -
                                  bottomSideHeight) /
                              2,
                    )
            : 0.0;
        final centeredMainTop = wide && widget.wideHeader != null
            ? headerLeading + (contentHeight - mainHeight) / 2
            : 0.0;
        final centeredSideTop = wide && widget.wideHeader != null
            ? headerLeading +
                  (contentHeight - sideHeight - gap - bottomSideHeight) / 2
            : 0.0;
        final workspaceHeight = contentHeight + headerLeading;

        ({double left, double top, double width, double height}) slotRect(
          int slot,
        ) {
          if (slot == 1) {
            return (
              left: 0,
              top: wide ? centeredMainTop : auxHeight + gap,
              width: mainWidth,
              height: mainHeight,
            );
          }
          if (wide) {
            return (
              left: mainWidth + gap,
              top: centeredSideTop + (slot == 0 ? 0 : sideHeight + gap),
              width: sideWidth,
              height: slot == 0 ? sideHeight : bottomSideHeight,
            );
          }
          return (
            left: slot == 0 ? 0 : auxWidth + gap,
            top: 0,
            width: auxWidth,
            height: auxHeight,
          );
        }

        final duration = reduceMotion || !widget.animateLayout
            ? Duration.zero
            : AppMotion.layoutDuration;
        return TweenAnimationBuilder<double>(
          tween: Tween<double>(end: workspaceHeight),
          duration: duration,
          curve: Curves.easeInOutCubic,
          builder: (context, animatedHeight, child) => SizedBox(
            width: double.infinity,
            height: animatedHeight,
            child: child,
          ),
          child: FocusTraversalGroup(
            policy: OrderedTraversalPolicy(),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (final service in _paintOrder)
                  _buildPositionedService(
                    context: context,
                    service: service,
                    rect: slotRect(_slots.indexOf(service)),
                    mainWidth: mainWidth,
                    mainHeight: mainHeight,
                    summarySize: Size(
                      auxWidth,
                      wide
                          ? _slots.indexOf(service) == 2
                                ? bottomSideHeight
                                : sideHeight
                          : auxHeight,
                    ),
                    compactSummary: !wide,
                    duration: duration,
                    density: density,
                    summaryCompression: summaryCompression,
                  ),
                // Paint splash overflow above card surfaces without moving the header.
                if (wide && widget.wideHeader != null)
                  AnimatedPositioned(
                    key: const ValueKey('home-wide-header'),
                    duration: duration,
                    curve: Curves.easeInOutCubic,
                    left: mainWidth + gap,
                    top: centeredSideTop - wideHeaderExtent,
                    width: sideWidth,
                    height: widget.wideHeaderHeight,
                    child: OverflowBox(
                      alignment: Alignment.topLeft,
                      minHeight: 0,
                      maxHeight: double.infinity,
                      child: widget.wideHeader!,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _reportMobileAttendance(double height) {
    if (!mounted ||
        (!_awaitingAttendanceMeasurement &&
            ((_contentHeights[HomeService.attendance] ?? -1) - height).abs() <
                0.5)) {
      return;
    }
    setState(() {
      _awaitingAttendanceMeasurement = false;
      _contentHeights[HomeService.attendance] = height;
      if (_heldContentHeights != null &&
          ((_heldContentHeights![HomeService.attendance] ?? -1) - height)
                  .abs() >=
              0.5) {
        _heldContentHeights![HomeService.attendance] = height;
        _mobileGeometry = null;
      }
    });
    widget.onAttendanceHeightChanged?.call(height);
  }

  Widget _buildMobileWorkspace(
    BuildContext context,
    BoxConstraints constraints,
    double textScale,
    WidgetRef ref,
  ) {
    final width = constraints.maxWidth;
    final minimumMainHeight = _slots[1] == HomeService.attendance
        ? (_heldContentHeights ?? _contentHeights)[HomeService.attendance] ??
              280.0
        : 320.0;
    final layout =
        widget.mobileLayout ??
        HomeMobileLayout.fit(
          viewportHeight: widget.viewportHeight,
          attendanceHeightReduction: widget.attendanceHeightReduction,
          minimumMainHeight: minimumMainHeight,
          attendanceIsPrimary: _slots[1] == HomeService.attendance,
          textScale: textScale,
          minimumAuxiliaryHeight: [
            for (final service in [_slots[0], _slots[2]])
              HomeServiceWorkspace.minimumMobileSummaryHeight(
                context,
                service,
                widget.summaryBuilder(service, ref),
                math.max(0.0, (width - 12) / 2),
              ),
          ].reduce(math.max),
        );
    final viewport = layout.viewportHeight;
    final density = layout.density;
    final gap = layout.gap;
    final auxHeight = layout.auxiliaryHeight;
    final auxiliaryExtent = auxHeight;
    // The viewport already excludes the header gap. Reserve the rest of a
    // proportional 64–96px separation and cap growth on unusually tall screens.
    final topSpace = math.max(
      0.0,
      (widget.availableHeight * 0.1).clamp(64.0, 96.0) - widget.mobileHeaderGap,
    );
    final extraSpace =
        widget.balanceMobileAttendance &&
            _slots[1] == HomeService.attendance &&
            density == HomeAttendanceDensity.regular
        ? (viewport - minimumMainHeight - auxiliaryExtent - gap - topSpace)
              .clamp(0.0, 96.0)
              .toDouble()
        : 0.0;
    final mainHeight = _slots[1] == HomeService.attendance
        ? math.max(
            0.0,
            minimumMainHeight -
                widget._mobileAttendanceReduction(density) +
                extraSpace,
          )
        : math.min(
            layout.mainHeight,
            _detailPreferredHeight(_slots[1], width, textScale),
          );
    final height = math.max(viewport, mainHeight + gap + auxiliaryExtent);
    final auxiliaryTop = height - auxiliaryExtent;
    final leadingSpace = math.max(0.0, auxiliaryTop - gap - mainHeight);
    final headerExtent = widget.mobileHeader == null
        ? 0.0
        : widget.mobileHeaderHeight + widget.mobileHeaderGap;
    final headerScale = widget.flexibleMobileHeader && textScale <= 1.2
        ? 1.0 +
              ((leadingSpace - 96) / 160).clamp(0.0, 0.3) *
                  ((width + 32 - 320) / 70).clamp(0.0, 1.0)
        : 1.0;
    final pageTopPadding = layout.topPadding;
    // Reserve the header-to-card gap below the header, outside its centering area.
    final headerTop =
        pageTopPadding +
        (widget.flexibleMobileHeader
            ? math.max(
                0.0,
                (widget.mobileHeaderHeight +
                        leadingSpace -
                        widget.mobileHeaderHeight * headerScale) /
                    2,
              )
            : 0.0);
    // Wait for the incoming content's natural size before starting a new
    // transition. A stale size must not become an intermediate animation target.
    final geometryViewport = Size(width, widget.availableHeight);
    if ((!widget.holdLayout && !_awaitingAttendanceMeasurement) ||
        _mobileGeometry == null ||
        _mobileGeometryViewport != geometryViewport ||
        _mobileGeometryTextScale != textScale) {
      _mobileGeometryViewport = geometryViewport;
      _mobileGeometryTextScale = textScale;
      _mobileGeometry = (
        mainHeight: mainHeight,
        gap: gap,
        auxHeight: auxHeight,
        height: height,
        headerTop: headerTop,
        headerScale: headerScale,
        pageTopPadding: pageTopPadding,
        density: density,
        extraSpace: extraSpace,
        summaryCompression: layout.summaryCompression,
      );
    }
    final geometry = _mobileGeometry!;
    final auxWidth = (width - geometry.gap) / 2;
    final targetAuxiliaryTop = geometry.height - geometry.auxHeight;

    ({double left, double top, double width, double height}) rect(int slot) {
      if (slot == 1) {
        return (
          left: 0,
          top:
              geometry.pageTopPadding +
              headerExtent +
              targetAuxiliaryTop -
              geometry.gap -
              geometry.mainHeight,
          width: width,
          height: geometry.mainHeight,
        );
      }
      return (
        left: slot == 0 ? 0 : auxWidth + geometry.gap,
        top: geometry.pageTopPadding + headerExtent + targetAuxiliaryTop,
        width: auxWidth,
        height: geometry.auxHeight,
      );
    }

    final duration =
        !widget.animateLayout || MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : AppMotion.layoutDuration;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(
        end: geometry.pageTopPadding + geometry.height + headerExtent,
      ),
      duration: duration,
      curve: Curves.easeInOutCubic,
      builder: (context, animatedHeight, child) =>
          SizedBox(height: animatedHeight, child: child),
      child: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: Stack(
          children: [
            for (final service in _paintOrder)
              _buildPositionedService(
                context: context,
                service: service,
                rect: rect(_slots.indexOf(service)),
                mainWidth: width,
                mainHeight: widget.holdLayout
                    ? geometry.mainHeight
                    : mainHeight,
                summarySize: Size(auxWidth, geometry.auxHeight),
                compactSummary: true,
                duration: duration,
                density: widget.holdLayout ? geometry.density : density,
                attendanceExtraSpace: widget.holdLayout
                    ? geometry.extraSpace
                    : extraSpace,
                summaryCompression: widget.holdLayout
                    ? geometry.summaryCompression
                    : layout.summaryCompression,
              ),
            if (widget.mobileHeader != null)
              Positioned.fill(
                child: FocusTraversalOrder(
                  order: const NumericFocusOrder(-1),
                  child: Semantics(
                    sortKey: const OrdinalSortKey(-1),
                    child: HomeMobileHeader(
                      animate: widget.animateLayout,
                      top: geometry.headerTop,
                      scale: geometry.headerScale,
                      width: width,
                      child: widget.mobileHeader!,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPositionedService({
    double attendanceExtraSpace = 0,
    required BuildContext context,
    required HomeService service,
    required ({double left, double top, double width, double height}) rect,
    required double mainWidth,
    required double mainHeight,
    required Size summarySize,
    required bool compactSummary,
    required Duration duration,
    HomeAttendanceDensity density = HomeAttendanceDensity.regular,
    double summaryCompression = 0,
  }) {
    final isPrimary = _slots[1] == service;
    // Service content must not change the header splash's visibility, whether
    // the service uses an internal viewport or its natural content height.
    Widget buildDetail() => widget.detailBuilder(service, isPrimary);
    final alignAttendanceBottom =
        service == HomeService.attendance &&
        MediaQuery.sizeOf(context).width < 600;
    final anchorMobileAttendance =
        widget.adaptiveMobileLayout && service == HomeService.attendance;
    final slot = _slots.indexOf(service);
    final traversalOrder = isPrimary
        ? 0.0
        : slot == 0
        ? 1.0
        : 2.0;
    return AnimatedPositioned(
      key: ValueKey(service),
      duration: duration,
      curve: Curves.easeInOutCubic,
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: FocusTraversalOrder(
        order: NumericFocusOrder(traversalOrder),
        child: Semantics(
          sortKey: OrdinalSortKey(traversalOrder),
          child: Consumer(
            builder: (context, ref, child) => HomeServiceAttentionSurface(
              serviceName: service.name,
              attentionKey: widget.summaryBuilder(service, ref).attentionKey,
              attentionScope: widget.attentionScope,
              isPrimary: isPrimary,
              child: LayoutBuilder(
                builder: (context, panelConstraints) => HomeAttendanceCardScope(
                  height: panelConstraints.maxHeight,
                  availableHeight: math.max(
                    0,
                    widget.viewportHeight -
                        (widget.wideHeader == null
                            ? 0
                            : widget.wideHeaderHeight + 12),
                  ),
                  child: child!,
                ),
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: anchorMobileAttendance ? null : 0,
                  right: 0,
                  bottom: anchorMobileAttendance ? 0 : null,
                  child: HomeServiceContentLayer(
                    key: ValueKey('home-service-${service.name}-detail-layer'),
                    visible: isPrimary,
                    duration: duration,
                    contentSize: Size(mainWidth, mainHeight),
                    child: SizedBox(
                      width: mainWidth,
                      height: mainHeight,
                      child: TickerMode(
                        enabled: isPrimary,
                        child: Focus(
                          key: ValueKey(
                            'home-service-${service.name}-detail-focus',
                          ),
                          focusNode: _detailFocusNodes[service],
                          skipTraversal: true,
                          includeSemantics: false,
                          child:
                              widget.adaptiveMobileLayout &&
                                  service == HomeService.attendance
                              ? OverflowBox(
                                  alignment: Alignment.bottomLeft,
                                  minHeight: 0,
                                  maxHeight: double.infinity,
                                  child: HomeContentSizeReporter(
                                    measurementKey: widget.attendanceLayoutKey,
                                    // Compare every density against the same
                                    // natural height to avoid fit oscillation.
                                    onSize: (size) => _reportMobileAttendance(
                                      size.height +
                                          widget._mobileAttendanceReduction(
                                            density,
                                          ) -
                                          attendanceExtraSpace,
                                    ),
                                    child: HomeAttendanceDensityScope(
                                      density: density,
                                      extraSpace: attendanceExtraSpace,
                                      child: buildDetail(),
                                    ),
                                  ),
                                )
                              : service == HomeService.attendance
                              ? OverflowBox(
                                  alignment: Alignment.topLeft,
                                  minHeight: 0,
                                  maxHeight: double.infinity,
                                  child: HomeContentSizeReporter(
                                    measurementKey: widget.attendanceLayoutKey,
                                    onSize: (size) {
                                      final naturalHeight =
                                          size.height + density.heightReduction;
                                      if (!mounted ||
                                          ((_contentHeights[service] ?? -1) -
                                                      naturalHeight)
                                                  .abs() <
                                              0.5) {
                                        return;
                                      }
                                      setState(() {
                                        _contentHeights[service] =
                                            naturalHeight;
                                        _heldContentHeights?[service] =
                                            naturalHeight;
                                      });
                                      widget.onAttendanceHeightChanged?.call(
                                        naturalHeight,
                                      );
                                    },
                                    child: HomeAttendanceDensityScope(
                                      density: density,
                                      child: buildDetail(),
                                    ),
                                  ),
                                )
                              : HomeAttendanceDensityScope(
                                  density: density,
                                  child: SingleChildScrollView(
                                    key: PageStorageKey(
                                      'home-detail-${service.name}',
                                    ),
                                    primary: false,
                                    keyboardDismissBehavior:
                                        ScrollViewKeyboardDismissBehavior
                                            .onDrag,
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        minHeight:
                                            compactSummary &&
                                                !alignAttendanceBottom
                                            ? 0
                                            : mainHeight,
                                      ),
                                      child: Align(
                                        alignment: alignAttendanceBottom
                                            ? Alignment.bottomLeft
                                            : Alignment.topLeft,
                                        child: HomeContentSizeReporter(
                                          onSize: (size) {
                                            if (!mounted ||
                                                (_contentHeights[service] !=
                                                        null &&
                                                    (_contentHeights[service]! -
                                                                size.height)
                                                            .abs() <
                                                        0.5)) {
                                              return;
                                            }
                                            setState(
                                              () => _contentHeights[service] =
                                                  size.height,
                                            );
                                          },
                                          child: buildDetail(),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: HomeServiceContentLayer(
                    key: ValueKey('home-service-${service.name}-summary-layer'),
                    visible: !isPrimary,
                    duration: duration,
                    child: Consumer(
                      builder: (context, ref, child) {
                        final data = widget.summaryBuilder(service, ref);
                        final summary = _SummaryContent(
                          service: service,
                          data: data,
                          compact: compactSummary,
                          compression: summaryCompression,
                        );
                        return Semantics(
                          button: true,
                          liveRegion: data.attentionKey != null,
                          label: [
                            service.title,
                            if (data.eyebrow != null) data.eyebrow!,
                            data.status,
                            if (data.leadingMenuIndex != null)
                              '${data.leadingMenuIndex == 0 ? 'A안' : 'B안'} 투표 수 우세',
                            if (data.secondary != null) data.secondary!,
                            if (data.warning != null) data.warning!,
                            '주 영역으로 이동',
                          ].join(', '),
                          onTap: () => _promote(service),
                          child: InkWell(
                            onTap: () => _promote(service),
                            enableFeedback: false,
                            child: ExcludeSemantics(
                              child: OverflowBox(
                                alignment: Alignment.topLeft,
                                minWidth: summarySize.width,
                                maxWidth: summarySize.width,
                                minHeight: summarySize.height,
                                maxHeight: summarySize.height,
                                child: !compactSummary
                                    ? SingleChildScrollView(
                                        primary: false,
                                        child: HomeContentSizeReporter(
                                          // Measure at the final auxiliary
                                          // width, including while offstage.
                                          // Intermediate animation widths
                                          // must not retarget the transition.
                                          measurementKey: (
                                            summarySize.width,
                                            summaryCompression,
                                          ),
                                          onSize: (size) {
                                            final naturalHeight =
                                                size.height +
                                                30 * summaryCompression;
                                            if (!mounted ||
                                                (_summaryHeights[service] !=
                                                        null &&
                                                    (_summaryHeights[service]! -
                                                                naturalHeight)
                                                            .abs() <
                                                        0.5)) {
                                              return;
                                            }
                                            setState(
                                              () => _summaryHeights[service] =
                                                  naturalHeight,
                                            );
                                          },
                                          child: summary,
                                        ),
                                      )
                                    : summary,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryContent extends StatelessWidget {
  const _SummaryContent({
    required this.service,
    required this.data,
    required this.compact,
    this.compression = 0,
  });

  final HomeService service;
  final HomeServiceSummaryData data;
  final bool compact;
  final double compression;

  static double minimumHeight(
    BuildContext context,
    HomeService service,
    HomeServiceSummaryData data,
    double width,
  ) {
    final theme = Theme.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    const spacing = HomeSummarySpacing(1);
    double measure(InlineSpan text, double maxWidth) {
      final painter = TextPainter(
        text: text,
        textDirection: Directionality.of(context),
        textScaler: scaler,
      )..layout(maxWidth: math.max(1.0, maxWidth));
      final height = painter.height;
      painter.dispose();
      return height;
    }

    final titleHeight = math.max(18.0, scaler.scale(14) * 1.25);
    final labelHeight = data.eyebrow != null && data.warning == null
        ? scaler.scale(12) * 1.3 + spacing.labelGap
        : 0.0;
    final statusHeight =
        service == HomeService.seat && data.availableSeats != null
        ? measure(
            _SummaryStatus.seatSpan(theme, data, compact: true),
            width - 20,
          )
        : scaler.scale(13) * 1.4;
    final warningHeight = data.warning == null
        ? 0.0
        : spacing.contentGap +
              math.max(
                16.0,
                measure(
                  TextSpan(
                    text: data.compactWarning ?? data.warning,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  width - 41,
                ),
              );
    return (2 * spacing.verticalPadding +
            titleHeight +
            labelHeight +
            spacing.contentGap +
            statusHeight +
            warningHeight)
        .ceilToDouble();
  }

  @override
  Widget build(BuildContext context) {
    final palette =
        Theme.of(context).extension<HongikPalette>() ?? HongikPalette.light;
    final textTheme = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (compact || constraints.maxWidth < 205) {
          final spacing = HomeSummarySpacing(compression);
          final scaler = MediaQuery.textScalerOf(context);
          final titleHeight = math.max(18.0, scaler.scale(14) * 1.25);
          final showEyebrow = data.eyebrow != null && data.warning == null;
          final labelHeight = !showEyebrow
              ? 0.0
              : scaler.scale(12) * 1.3 + spacing.labelGap;
          final warningText = data.compactWarning ?? data.warning;
          final warningStyle = (textTheme.bodySmall ?? const TextStyle())
              .copyWith(
                fontSize: 12,
                height: 1.3,
                color: palette.warning,
                fontWeight: FontWeight.w600,
              );
          var warningHeight = 0.0;
          if (data.warning != null) {
            final painter = TextPainter(
              text: TextSpan(text: warningText, style: warningStyle),
              textDirection: Directionality.of(context),
              textScaler: scaler,
            )..layout(maxWidth: math.max(0.0, constraints.maxWidth - 41));
            warningHeight = math.max(16.0, painter.height) + spacing.contentGap;
            painter.dispose();
          }
          final statusLines = constraints.maxHeight.isFinite
              ? ((constraints.maxHeight -
                            2 * spacing.verticalPadding -
                            spacing.contentGap -
                            titleHeight -
                            labelHeight -
                            warningHeight) /
                        (scaler.scale(13) * 1.4))
                    .floor()
                    .clamp(1, 4)
              : 4;
          return Center(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 10,
                vertical: spacing.verticalPadding,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        data.attentionKey != null
                            ? Icons.check_circle_rounded
                            : service.icon,
                        color: service.summaryIconColor(Theme.of(context)),
                        size: 18,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          service.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.labelLarge?.copyWith(
                            fontSize: 14,
                            height: 1.25,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: palette.textSecondary,
                        size: 16,
                      ),
                    ],
                  ),
                  if (showEyebrow) ...[
                    SizedBox(height: spacing.labelGap),
                    Text(
                      data.eyebrow!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        height: 1.3,
                        color: data.attentionKey != null
                            ? palette.brandNavy
                            : palette.textSecondary,
                        fontWeight: data.attentionKey != null
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                  SizedBox(height: spacing.contentGap),
                  Flexible(
                    child:
                        service == HomeService.seat &&
                            data.availableSeats != null
                        ? _SummaryStatus(
                            service: service,
                            data: data,
                            compact: true,
                          )
                        : service == HomeService.menu &&
                              data.leadingMenuIndex != null
                        ? Text.rich(
                            _SummaryStatus.menuSpan(
                              data.secondary == null
                                  ? data.status
                                  : '${data.status} · ${data.secondary}',
                              data.leadingMenuIndex,
                              textTheme.bodySmall?.copyWith(
                                fontSize: 13,
                                height: 1.4,
                                fontWeight: FontWeight.w600,
                              ),
                              Theme.of(context).colorScheme.primary,
                            ),
                            maxLines: statusLines,
                            overflow: TextOverflow.ellipsis,
                          )
                        : Text(
                            data.secondary == null
                                ? data.status
                                : '${data.status} · ${data.secondary}',
                            maxLines: statusLines,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(
                              fontSize: 13,
                              height: 1.4,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                  if (data.warning != null) ...[
                    SizedBox(height: spacing.contentGap),
                    Tooltip(
                      message: warningText == data.warning ? '' : data.warning!,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 16,
                            color: palette.warning,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(warningText!, style: warningStyle),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 17,
            vertical: 17 - 9 * compression,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: service.iconBackgroundColor(Theme.of(context)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      data.attentionKey != null
                          ? Icons.check_circle_rounded
                          : service.icon,
                      color: service.iconColor(Theme.of(context)),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      service.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: palette.textSecondary,
                  ),
                ],
              ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 10 - 6 * compression),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (data.eyebrow != null) ...[
                      Text(
                        data.eyebrow!,
                        style: textTheme.bodySmall?.copyWith(
                          color: data.attentionKey != null
                              ? palette.brandNavy
                              : palette.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    _SummaryStatus(service: service, data: data),
                    if (data.secondary != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        data.secondary!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: palette.textSecondary,
                        ),
                      ),
                    ],
                    if (data.warning != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 16,
                            color: palette.warning,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              data.warning!,
                              style: textTheme.bodySmall?.copyWith(
                                color: palette.warning,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (data.facts.isNotEmpty)
                Column(
                  children: [
                    Divider(height: 1, color: palette.cardOutline),
                    const SizedBox(height: 9),
                    for (final fact in data.facts) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              fact.label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodySmall?.copyWith(
                                color: palette.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: Text(
                              fact.value,
                              textAlign: TextAlign.end,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                    ],
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}
