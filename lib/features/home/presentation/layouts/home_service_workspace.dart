import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hongik_ingan/core/theme/color.dart';

import '../widgets/home_content_size_reporter.dart';
import '../widgets/home_attendance_action_layout.dart';
import '../widgets/home_attendance_density.dart';
import '../widgets/home_mobile_header.dart';

enum HomeService { attendance, seat, menu }

extension HomeServiceLabel on HomeService {
  String get title => switch (this) {
    HomeService.attendance => '로그인·출결',
    HomeService.seat => '열람실',
    HomeService.menu => '학식 메뉴',
  };

  IconData get icon => switch (this) {
    HomeService.attendance => Icons.check_circle_outline_rounded,
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
    if (theme.brightness == Brightness.light) {
      return palette.brandNavy;
    }
    return switch (this) {
      HomeService.attendance => palette.brandNavy,
      HomeService.seat => theme.colorScheme.onSecondaryContainer,
      HomeService.menu => theme.colorScheme.onTertiaryContainer,
    };
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (service == HomeService.seat && data.availableSeats != null) {
      return Text.rich(
        TextSpan(
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
        ),
      );
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

class HomeServiceWorkspace extends StatefulWidget {
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
  final Object? attendanceLayoutKey;

  @override
  State<HomeServiceWorkspace> createState() => _HomeServiceWorkspaceState();
}

class _HomeServiceWorkspaceState extends State<HomeServiceWorkspace> {
  bool _awaitingAttendanceMeasurement = false;
  ({
    double mainHeight,
    double gap,
    double auxHeight,
    double height,
    double headerTop,
    double headerScale,
  })?
  _mobileGeometry;
  final Map<HomeService, double> _contentHeights = {};
  final Map<HomeService, double> _summaryHeights = {};
  final List<HomeService> _slots = [
    HomeService.seat,
    HomeService.attendance,
    HomeService.menu,
  ];
  final Map<HomeService, FocusNode> _detailFocusNodes = {
    for (final service in HomeService.values)
      service: FocusNode(debugLabel: '${service.name} detail'),
  };

  @override
  void didUpdateWidget(covariant HomeServiceWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
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
          return _buildMobileWorkspace(context, constraints, textScale);
        }
        final width = constraints.maxWidth;
        const gap = 12.0;
        final proposedSideWidth = (width * 0.25).clamp(230.0, 300.0);
        final wide = HomeServiceWorkspace.usesWideLayout(width);
        final stackedRows = !wide && widget.dockAuxiliaryBelow;
        final docked = stackedRows && constraints.maxHeight.isFinite;
        final sideWidth = wide ? proposedSideWidth : 0.0;
        final mainWidth = wide ? width - sideWidth - gap : width;
        final auxWidth = wide
            ? sideWidth
            : stackedRows
            ? width
            : (width - gap) / 2;
        final auxHeight = wide
            ? 0.0
            : 108.0 + math.min(64.0, math.max(0.0, textScale - 1) * 64);
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
        final measuredHeight = _contentHeights[_slots[1]] ?? 280.0;
        final stableDetailHeight = _slots[1] != HomeService.attendance;
        final wideHeaderExtent = widget.wideHeader == null
            ? 0.0
            : widget.wideHeaderHeight + gap;
        final preferredDetailViewportHeight = wide
            ? widget.viewportHeight == null
                  ? HomeServiceWorkspace.widePanelHeight(
                          widget.availableHeight,
                        ) -
                        (widget.wideHeader == null ? 0 : 45)
                  : math.max(
                      320.0,
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
        final detailViewportHeight = math.min(
          preferredDetailViewportHeight,
          math.max(320.0, viewportContentHeight),
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
                  : measuredHeight
            : legacyHeight;
        final sideHeight = wide
            ? widget.measureContent
                  ? _summaryHeights[_slots[0]] ?? 200.0
                  : (mainHeight - gap) / 2
            : auxHeight;
        final bottomSideHeight = wide
            ? widget.measureContent
                  ? _summaryHeights[_slots[2]] ?? 200.0
                  : mainHeight - gap - sideHeight
            : auxHeight;
        final contentHeight = wide
            ? math.max(mainHeight, sideHeight + gap + bottomSideHeight)
            : mainHeight + gap + auxiliaryExtent;
        // Only reserve space above the cards when the actual side header needs it.
        final headerLeading = wide && widget.wideHeader != null
            ? math.max(
                0.0,
                wideHeaderExtent -
                    (contentHeight - sideHeight - gap - bottomSideHeight) / 2,
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

        final duration = reduceMotion
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
                for (final service in HomeService.values)
                  _buildPositionedService(
                    context: context,
                    service: service,
                    rect: slotRect(_slots.indexOf(service)),
                    mainWidth: mainWidth,
                    mainHeight: mainHeight,
                    compactSummary: !wide,
                    docked: docked,
                    duration: duration,
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
    });
    widget.onAttendanceHeightChanged?.call(height);
  }

  Widget _buildMobileWorkspace(
    BuildContext context,
    BoxConstraints constraints,
    double textScale,
  ) {
    final viewport = math.max(
      0.0,
      widget.viewportHeight ?? widget.availableHeight,
    );
    final width = constraints.maxWidth;
    final normalAuxHeight =
        108.0 + math.min(64.0, math.max(0.0, textScale - 1) * 64);
    final minimumMainHeight = _slots[1] == HomeService.attendance
        ? _contentHeights[HomeService.attendance] ?? 280.0
        : 320.0;
    var density = HomeAttendanceDensity.regular;
    var gap = 12.0;
    var auxHeight = normalAuxHeight;

    if (minimumMainHeight + auxHeight + gap > viewport) {
      density = HomeAttendanceDensity.compact;
      gap = 8;
      if (minimumMainHeight - density.heightReduction + auxHeight + gap >
          viewport) {
        density = HomeAttendanceDensity.tight;
        // Preserve enough room for scaled labels and warning messages.
        auxHeight = 80.0 + math.min(92.0, math.max(0.0, textScale - 1) * 92);
      }
    }
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
              .clamp(
                0.0,
                Theme.of(context).brightness == Brightness.dark ? 96.0 : 192.0,
              )
              .toDouble()
        : 0.0;
    final mainHeight = _slots[1] == HomeService.attendance
        ? math.max(
            0.0,
            minimumMainHeight - density.heightReduction + extraSpace,
          )
        : math.max(320.0, viewport - auxiliaryExtent - gap);
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
    final headerTop = widget.flexibleMobileHeader
        ? math.max(
            0.0,
            (headerExtent +
                    leadingSpace -
                    widget.mobileHeaderHeight * headerScale) /
                2,
          )
        : 0.0;
    // Wait for the incoming content's natural size before starting a new
    // transition. A stale size must not become an intermediate animation target.
    if (!_awaitingAttendanceMeasurement || _mobileGeometry == null) {
      _mobileGeometry = (
        mainHeight: mainHeight,
        gap: gap,
        auxHeight: auxHeight,
        height: height,
        headerTop: headerTop,
        headerScale: headerScale,
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
        top: headerExtent + targetAuxiliaryTop,
        width: auxWidth,
        height: geometry.auxHeight,
      );
    }

    return SizedBox(
      height: geometry.height + headerExtent,
      child: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: Stack(
          children: [
            for (final service in HomeService.values)
              _buildPositionedService(
                context: context,
                service: service,
                rect: rect(_slots.indexOf(service)),
                mainWidth: width,
                mainHeight: mainHeight,
                compactSummary: true,
                docked: true,
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 400),
                density: density,
                attendanceExtraSpace: extraSpace,
              ),
            if (widget.mobileHeader != null)
              Positioned.fill(
                child: FocusTraversalOrder(
                  order: const NumericFocusOrder(-1),
                  child: Semantics(
                    sortKey: const OrdinalSortKey(-1),
                    child: HomeMobileHeader(
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
    required bool compactSummary,
    required bool docked,
    required Duration duration,
    HomeAttendanceDensity density = HomeAttendanceDensity.regular,
  }) {
    final isPrimary = _slots[1] == service;
    final alignAttendanceBottom =
        service == HomeService.attendance &&
        MediaQuery.sizeOf(context).width < 600;
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
                  top: 0,
                  child: ExcludeFocus(
                    excluding: !isPrimary,
                    child: Offstage(
                      offstage: !isPrimary,
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
                                      measurementKey:
                                          widget.attendanceLayoutKey,
                                      // Compare every density against the same
                                      // natural height to avoid fit oscillation.
                                      onSize: (size) => _reportMobileAttendance(
                                        size.height +
                                            density.heightReduction -
                                            attendanceExtraSpace,
                                      ),
                                      child: HomeAttendanceDensityScope(
                                        density: density,
                                        extraSpace: attendanceExtraSpace,
                                        child: widget.detailBuilder(
                                          service,
                                          isPrimary,
                                        ),
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
                                      measurementKey:
                                          widget.attendanceLayoutKey,
                                      onSize: (size) {
                                        if (!mounted ||
                                            ((_contentHeights[service] ?? -1) -
                                                        size.height)
                                                    .abs() <
                                                0.5) {
                                          return;
                                        }
                                        setState(
                                          () => _contentHeights[service] =
                                              size.height,
                                        );
                                        widget.onAttendanceHeightChanged?.call(
                                          size.height,
                                        );
                                      },
                                      child: widget.detailBuilder(
                                        service,
                                        isPrimary,
                                      ),
                                    ),
                                  )
                                : widget.measureContent
                                ? SingleChildScrollView(
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
                                          child: widget.detailBuilder(
                                            service,
                                            isPrimary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                : widget.detailBuilder(service, isPrimary),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: ExcludeFocus(
                    excluding: isPrimary,
                    child: Offstage(
                      offstage: isPrimary,
                      child: Consumer(
                        builder: (context, ref, child) {
                          final data = widget.summaryBuilder(service, ref);
                          final summary = _SummaryContent(
                            service: service,
                            data: data,
                            compact: compactSummary,
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
                                child: !compactSummary
                                    ? SingleChildScrollView(
                                        primary: false,
                                        child: HomeContentSizeReporter(
                                          onSize: (size) {
                                            if (!mounted ||
                                                !widget.measureContent ||
                                                isPrimary ||
                                                (_summaryHeights[service] !=
                                                        null &&
                                                    (_summaryHeights[service]! -
                                                                size.height)
                                                            .abs() <
                                                        0.5)) {
                                              return;
                                            }
                                            setState(
                                              () => _summaryHeights[service] =
                                                  size.height,
                                            );
                                          },
                                          child: summary,
                                        ),
                                      )
                                    : summary,
                              ),
                            ),
                          );
                        },
                      ),
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
    duration: const Duration(seconds: 1),
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

  bool get _emphasized => !widget.isPrimary && widget.attentionKey != null;

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
        discovered &&
        !_controller.isAnimating &&
        !MediaQuery.disableAnimationsOf(context) &&
        (lifecycle == null || lifecycle == AppLifecycleState.resumed)) {
      _controller.forward(from: 0);
    } else if (!_emphasized) {
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
        color: _emphasized
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
  });

  final HomeService service;
  final HomeServiceSummaryData data;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette =
        Theme.of(context).extension<HongikPalette>() ?? HongikPalette.light;
    final textTheme = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (compact || constraints.maxWidth < 205) {
          final scaler = MediaQuery.textScalerOf(context);
          final titleHeight = math.max(18.0, scaler.scale(14) * 1.25);
          final showEyebrow = data.eyebrow != null && data.warning == null;
          final labelHeight = !showEyebrow ? 0.0 : scaler.scale(12) * 1.3 + 3;
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
            warningHeight = math.max(16.0, painter.height) + 4;
            painter.dispose();
          }
          final statusLines = constraints.maxHeight.isFinite
              ? ((constraints.maxHeight -
                            20 -
                            titleHeight -
                            labelHeight -
                            warningHeight) /
                        (scaler.scale(13) * 1.4))
                    .floor()
                    .clamp(1, 4)
              : 4;
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                        color: service.iconColor(Theme.of(context)),
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
                    const SizedBox(height: 3),
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
                  const SizedBox(height: 4),
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
                    const SizedBox(height: 4),
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
          padding: const EdgeInsets.all(17),
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
                padding: const EdgeInsets.symmetric(vertical: 10),
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
