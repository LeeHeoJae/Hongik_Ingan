import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hongik_ingan/core/theme/color.dart';

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
}

typedef HomeServiceDetailBuilder =
    Widget Function(HomeService service, bool isPrimary);
typedef HomeServiceSummaryBuilder =
    HomeServiceSummaryData Function(HomeService service, WidgetRef ref);

class HomeServiceSummaryData {
  const HomeServiceSummaryData({
    required this.status,
    this.secondary,
    this.facts = const [],
  });

  final String status;
  final String? secondary;
  final List<({String label, String value})> facts;
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
  });

  final double availableHeight;
  final HomeServiceDetailBuilder detailBuilder;
  final HomeServiceSummaryBuilder summaryBuilder;
  final ValueChanged<HomeService>? onPrimaryChanged;
  final bool Function(HomeService service)? hasLongContent;
  final bool measureContent;
  final bool dockAuxiliaryBelow;
  final Widget? wideHeader;

  @override
  State<HomeServiceWorkspace> createState() => _HomeServiceWorkspaceState();
}

class _HomeServiceWorkspaceState extends State<HomeServiceWorkspace> {
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
        final width = constraints.maxWidth;
        const gap = 12.0;
        final proposedSideWidth = (width * 0.25).clamp(230.0, 300.0);
        final wide = HomeServiceWorkspace.usesWideLayout(width);
        final docked =
            !wide &&
            widget.dockAuxiliaryBelow &&
            constraints.maxHeight.isFinite;
        final sideWidth = wide ? proposedSideWidth : 0.0;
        final mainWidth = wide ? width - sideWidth - gap : width;
        final auxWidth = wide ? sideWidth : (width - gap) / 2;
        final auxHeight = wide
            ? 0.0
            : 82.0 + math.min(26.0, math.max(0.0, textScale - 1) * 26);
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
        final dockedMainHeight = docked
            ? math.max(0.0, constraints.maxHeight - auxHeight - gap)
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
            ? (wide
                  ? math.min(
                      math.max(
                        measuredHeight,
                        widget.wideHeader == null
                            ? 0.0
                            : _slots[1] == HomeService.attendance
                            ? 444.0
                            : 240.0,
                      ),
                      HomeServiceWorkspace.widePanelHeight(
                            widget.availableHeight,
                          ) -
                          (widget.wideHeader == null ? 0 : 45),
                    )
                  : measuredHeight)
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
            : mainHeight + gap + auxHeight;
        const wideHeaderExtent = 60.0;
        final centeredMainTop = wide && widget.wideHeader != null
            ? wideHeaderExtent + (contentHeight - mainHeight) / 2
            : 0.0;
        final centeredSideTop = wide && widget.wideHeader != null
            ? wideHeaderExtent +
                  (contentHeight - sideHeight - gap - bottomSideHeight) / 2
            : 0.0;
        final workspaceHeight = docked
            ? constraints.maxHeight
            : contentHeight + (wide && widget.wideHeader != null ? 120 : 0);

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
            left: slot == 0 ? 0 : auxWidth + gap,
            top: docked ? dockedMainHeight + gap : 0,
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
                  Positioned(
                    left: mainWidth + gap,
                    top: centeredSideTop - wideHeaderExtent,
                    width: sideWidth,
                    height: 48,
                    child: widget.wideHeader!,
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

  Widget _buildPositionedService({
    required BuildContext context,
    required HomeService service,
    required ({double left, double top, double width, double height}) rect,
    required double mainWidth,
    required double mainHeight,
    required bool compactSummary,
    required bool docked,
    required Duration duration,
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
    final palette =
        Theme.of(context).extension<HongikPalette>() ?? HongikPalette.light;

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
          child: Material(
            key: ValueKey('home-service-${service.name}'),
            color: palette.cardSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: palette.cardOutline),
            ),
            clipBehavior: Clip.antiAlias,
            elevation: isPrimary ? 3 : 0,
            shadowColor: palette.cardShadow,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 0,
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
                          child: widget.measureContent
                              ? SingleChildScrollView(
                                  key: PageStorageKey(
                                    'home-detail-${service.name}',
                                  ),
                                  primary: false,
                                  physics: compactSummary && !docked
                                      ? const NeverScrollableScrollPhysics()
                                      : null,
                                  keyboardDismissBehavior:
                                      ScrollViewKeyboardDismissBehavior.onDrag,
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
                                      child: _ContentSizeReporter(
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
                Positioned.fill(
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
                          label: '${service.title}, ${data.status}, 주 영역으로 이동',
                          onTap: () => _promote(service),
                          child: InkWell(
                            onTap: () => _promote(service),
                            child: ExcludeSemantics(
                              child: !compactSummary
                                  ? SingleChildScrollView(
                                      primary: false,
                                      child: _ContentSizeReporter(
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ContentSizeReporter extends SingleChildRenderObjectWidget {
  const _ContentSizeReporter({required this.onSize, required super.child});
  final ValueChanged<Size> onSize;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _ContentSizeRenderObject(onSize);
  @override
  void updateRenderObject(
    BuildContext context,
    covariant _ContentSizeRenderObject renderObject,
  ) {
    renderObject.onSize = onSize;
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
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(service.icon, color: palette.brandNavy, size: 22),
                  const SizedBox(height: 3),
                  Text(
                    service.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (constraints.maxHeight >= 76 &&
                      constraints.maxWidth >= 160) ...[
                    const SizedBox(height: 2),
                    Text(
                      data.status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: palette.textSecondary,
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
                      color: palette.cardSurfaceMuted,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      service.icon,
                      color: palette.brandNavy,
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
                        fontWeight: FontWeight.w800,
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
                    Text(
                      data.status,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
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
                          Text(
                            fact.label,
                            style: textTheme.bodySmall?.copyWith(
                              color: palette.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
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
