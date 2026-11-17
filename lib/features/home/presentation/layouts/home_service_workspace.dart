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

part 'home_service_summary.dart';
part 'home_service_types.dart';

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
            ? math.max(minimumDetailHeight, measuredHeight)
            : wide
            ? math.max(
                minimumDetailHeight,
                math.min(720.0, widget.viewportHeight - wideHeaderExtent),
              )
            : math.max(320.0, math.min(560.0, widget.availableHeight - 140));
        final viewportContentHeight =
            widget.viewportHeight - (wide ? wideHeaderExtent : auxHeight + gap);
        final fittedWideHeight = wide
            ? widget.reserveWideHeaderSpace
                  ? widget.viewportHeight - wideHeaderExtent
                  : math.min(
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
