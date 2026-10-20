import 'dart:math' as math;
import 'package:flutter/foundation.dart' show listEquals;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hongik_ingan/core/theme/color.dart';

import '../widgets/home_content_size_reporter.dart';
import '../widgets/home_attendance_action_layout.dart';
import '../widgets/home_attendance_density.dart';
import '../widgets/home_mobile_header.dart';
import '../widgets/home_mobile_layout.dart';
import '../widgets/home_splash_space.dart';

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

typedef HomeServiceDetailBuilder =
    Widget Function(HomeService service, bool isPrimary);
typedef HomeServiceSummaryBuilder =
    HomeServiceSummaryData Function(HomeService service, WidgetRef ref);

class HomeServiceSummaryData {
  const HomeServiceSummaryData({
    required this.status,
    this.eyebrow,
    this.secondary,
    this.warning,
    this.compactWarning,
    this.attentionKey,
    this.availableSeats,
    this.facts = const [],
  });

  final String status;
  final String? eyebrow;
  final String? secondary;
  final String? warning;
  final String? compactWarning;
  final String? attentionKey;
  final int? availableSeats;
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
            Text(
              lines[index],
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.5,
                fontWeight: FontWeight.w400,
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

  static double widePanelHeight(double availableHeight) =>
      (availableHeight - 160).clamp(320.0, 720.0).toDouble();
  const HomeServiceWorkspace({
    super.key,
    required this.availableHeight,
    required this.detailBuilder,
    required this.summaryBuilder,
    this.onPrimaryChanged,
    this.hasLongContent,
    this.measureContent = false,
    this.dockAuxiliaryBelow = false,
    this.wideHeader,
    this.wideHeaderHeight = 48,
    this.reserveWideHeaderSpace = false,
    this.attentionScope,
    this.viewportHeight,
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
  final bool Function(HomeService service)? hasLongContent;
  final bool measureContent;
  final bool dockAuxiliaryBelow;
  final Widget? wideHeader;
  final double wideHeaderHeight;

  /// Keep card centers stable when the header includes secondary content.
  final bool reserveWideHeaderSpace;
  final String? attentionScope;

  /// Height left for the workspace after the page header, footer and padding.
  final double? viewportHeight;
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
        final stackedRows = !wide && widget.dockAuxiliaryBelow;
        final docked = stackedRows && constraints.maxHeight.isFinite;
        final measuredHeight =
            (_heldContentHeights ?? _contentHeights)[_slots[1]] ?? 280.0;
        final adaptive =
            widget.measureContent && widget.viewportHeight != null && !docked;
        final rowLayout = adaptive && !wide
            ? HomeMobileLayout.fit(
                viewportHeight: widget.viewportHeight!,
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
        final auxWidth = wide
            ? sideWidth
            : stackedRows
            ? width
            : (width - gap) / 2;
        final auxHeight = wide
            ? 0.0
            : rowLayout?.auxiliaryHeight ??
                  HomeMobileLayout.normalAuxiliaryHeight(textScale);
        final auxiliaryExtent = stackedRows ? auxHeight * 2 + gap : auxHeight;
        final hasLongContent = widget.hasLongContent?.call(_slots[1]) ?? false;
        final compactHeight = switch (_slots[1]) {
          HomeService.attendance => 440.0,
          HomeService.seat || HomeService.menu => 380.0,
        };
        final preferredHeight =
            (hasLongContent ? 560.0 : compactHeight) +
            math.min(120.0, math.max(0.0, textScale - 1) * 120);
        final legacyHeight = math.max(
          320.0,
          math.min(preferredHeight, widget.availableHeight - 140),
        );
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

        if (adaptive && wide) {
          final target = stableDetailHeight ? 320.0 : measuredHeight;
          for (final candidate in HomeAttendanceDensity.values) {
            density = candidate;
            if (wideExtent(
                  target -
                      density.reductionFor(attendance: !stableDetailHeight),
                  0,
                ) <=
                widget.viewportHeight!) {
              break;
            }
          }
          final fitted =
              target - density.reductionFor(attendance: !stableDetailHeight);
          if (wideExtent(fitted, 0) > widget.viewportHeight!) {
            // Summaries give up their padding only after primary spacing.
            var low = 0.0;
            var high = 1.0;
            for (var step = 0; step < 16; step++) {
              final middle = (low + high) / 2;
              if (wideExtent(fitted, middle) > widget.viewportHeight!) {
                low = middle;
              } else {
                high = middle;
              }
            }
            summaryCompression = high;
          }
        }
        final minimumDetailHeight = adaptive
            ? HomeMobileLayout.minimumDetailViewportHeight(textScale)
            : 320.0;
        final preferredDetailViewportHeight = wide
            ? widget.viewportHeight == null
                  ? HomeServiceWorkspace.widePanelHeight(
                          widget.availableHeight,
                        ) -
                        (widget.wideHeader == null ? 0 : 45)
                  : math.max(
                      minimumDetailHeight,
                      math.min(
                        720.0,
                        widget.viewportHeight! - wideHeaderExtent,
                      ),
                    )
            : math.max(320.0, math.min(560.0, widget.availableHeight - 140));
        final viewportContentHeight = widget.viewportHeight == null
            ? double.infinity
            : widget.viewportHeight! -
                  (wide ? wideHeaderExtent : auxiliaryExtent + gap);
        final fittedWideHeight = adaptive && wide
            ? math.min(
                widget.viewportHeight!,
                2 * (widget.viewportHeight! - wideHeaderExtent) -
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
        final dockedMainHeight = docked
            ? math.max(0.0, constraints.maxHeight - auxiliaryExtent - gap)
            : 0.0;
        final fitAttendanceHeight =
            docked &&
            widget.measureContent &&
            MediaQuery.sizeOf(context).width < 600 &&
            _slots[1] == HomeService.attendance;
        final mainHeight = docked
            ? fitAttendanceHeight
                  ? math.min(measuredHeight, dockedMainHeight)
                  : dockedMainHeight
            : widget.measureContent
            ? stableDetailHeight
                  ? detailViewportHeight
                  : rowLayout?.mainHeight ??
                        math.max(0.0, measuredHeight - density.heightReduction)
            : legacyHeight;
        final sideHeight = wide
            ? widget.measureContent
                  ? naturalSideHeight - 30 * summaryCompression
                  : (mainHeight - gap) / 2
            : auxHeight;
        final bottomSideHeight = wide
            ? widget.measureContent
                  ? naturalBottomSideHeight - 30 * summaryCompression
                  : mainHeight - gap - sideHeight
            : auxHeight;
        final contentHeight = wide
            ? math.max(mainHeight, sideHeight + gap + bottomSideHeight)
            : mainHeight + gap + auxiliaryExtent;
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
        final workspaceHeight = docked
            ? constraints.maxHeight
            : contentHeight + headerLeading;

        ({double left, double top, double width, double height}) slotRect(
          int slot,
        ) {
          if (slot == 1) {
            return (
              left: 0,
              top: wide
                  ? centeredMainTop
                  : docked
                  ? dockedMainHeight - mainHeight
                  : stackedRows
                  ? 0
                  : auxHeight + gap,
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
            left: stackedRows || slot == 0 ? 0 : auxWidth + gap,
            top: stackedRows
                ? (docked ? dockedMainHeight : mainHeight) +
                      gap +
                      (slot == 0 ? 0 : auxHeight + gap)
                : 0,
            width: auxWidth,
            height: auxHeight,
          );
        }

        final duration = reduceMotion || !widget.animateLayout
            ? Duration.zero
            : const Duration(milliseconds: 400);
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
                    docked: docked,
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
          viewportHeight: widget.viewportHeight ?? widget.availableHeight,
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
        : layout.mainHeight;
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
        : const Duration(milliseconds: 400);
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
                docked: true,
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
    required bool docked,
    required Duration duration,
    HomeAttendanceDensity density = HomeAttendanceDensity.regular,
    double summaryCompression = 0,
  }) {
    final isPrimary = _slots[1] == service;
    Widget buildDetail() =>
        HomeSplashContent(child: widget.detailBuilder(service, isPrimary));
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
            builder: (context, ref, child) => _ServiceAttentionSurface(
              service: service,
              attentionKey: widget.summaryBuilder(service, ref).attentionKey,
              attentionScope: widget.attentionScope,
              isPrimary: isPrimary,
              child: LayoutBuilder(
                builder: (context, panelConstraints) => HomeAttendanceCardScope(
                  height: panelConstraints.maxHeight,
                  availableHeight: math.max(
                    0,
                    (widget.viewportHeight ?? widget.availableHeight) -
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
                  child: _ServiceContentLayer(
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
                              : widget.measureContent &&
                                    service == HomeService.attendance &&
                                    !docked
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
                              : widget.measureContent
                              ? HomeAttendanceDensityScope(
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
                                )
                              : buildDetail(),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: _ServiceContentLayer(
                    key: ValueKey('home-service-${service.name}-summary-layer'),
                    visible: !isPrimary,
                    duration: duration,
                    child: Consumer(
                      builder: (context, ref, child) {
                        final data = widget.summaryBuilder(service, ref);
                        final summary = HomeSplashContent(
                          child: _SummaryContent(
                            service: service,
                            data: data,
                            compact: compactSummary,
                            compression: summaryCompression,
                          ),
                        );
                        return Semantics(
                          button: true,
                          liveRegion: data.attentionKey != null,
                          label: [
                            service.title,
                            if (data.eyebrow != null) data.eyebrow!,
                            data.status,
                            if (data.secondary != null) data.secondary!,
                            if (data.warning != null) data.warning!,
                            '주 영역으로 이동',
                          ].join(', '),
                          onTap: () => _promote(service),
                          child: InkWell(
                            onTap: () => _promote(service),
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
                                                !widget.measureContent ||
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

/// Keeps both service subtrees mounted while fading them within the card move.
class _ServiceContentLayer extends StatefulWidget {
  const _ServiceContentLayer({
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
  State<_ServiceContentLayer> createState() => _ServiceContentLayerState();
}

class _ServiceContentLayerState extends State<_ServiceContentLayer>
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
  void didUpdateWidget(_ServiceContentLayer oldWidget) {
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
                      ? const Interval(0.2, 0.7, curve: Curves.easeInOutCubic)
                      : const Interval(0, 0.35, curve: Curves.easeOutCubic),
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

class _ServiceAttentionSurface extends StatefulWidget {
  const _ServiceAttentionSurface({
    required this.service,
    required this.attentionKey,
    required this.attentionScope,
    required this.isPrimary,
    required this.child,
  });

  final HomeService service;
  final String? attentionKey;
  final String? attentionScope;
  final bool isPrimary;
  final Widget child;

  @override
  State<_ServiceAttentionSurface> createState() =>
      _ServiceAttentionSurfaceState();
}

class _ServiceAttentionSurfaceState extends State<_ServiceAttentionSurface>
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
  void didUpdateWidget(covariant _ServiceAttentionSurface oldWidget) {
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
        key: ValueKey('home-service-${widget.service.name}'),
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
