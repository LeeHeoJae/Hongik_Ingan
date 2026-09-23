import 'dart:math' as math;

import 'package:flutter/material.dart';
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
  const HomeServiceWorkspace({
    super.key,
    required this.availableHeight,
    required this.detailBuilder,
    required this.summaryBuilder,
    this.onPrimaryChanged,
  });

  final double availableHeight;
  final HomeServiceDetailBuilder detailBuilder;
  final HomeServiceSummaryBuilder summaryBuilder;
  final ValueChanged<HomeService>? onPrimaryChanged;

  @override
  State<HomeServiceWorkspace> createState() => _HomeServiceWorkspaceState();
}

class _HomeServiceWorkspaceState extends State<HomeServiceWorkspace> {
  final List<HomeService> _slots = [
    HomeService.seat,
    HomeService.attendance,
    HomeService.menu,
  ];

  void _promote(HomeService service) {
    final selectedSlot = _slots.indexOf(service);
    if (selectedSlot == 1) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _slots[selectedSlot] = _slots[1];
      _slots[1] = service;
    });
    widget.onPrimaryChanged?.call(service);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final wide = width >= 850;
        const gap = 12.0;
        final sideWidth = wide ? (width * 0.25).clamp(220.0, 300.0) : 0.0;
        final mainWidth = wide ? width - sideWidth - gap : width;
        final auxWidth = wide ? sideWidth : (width - gap) / 2;
        final auxHeight = wide
            ? 0.0
            : 82.0 + math.min(26.0, math.max(0.0, textScale - 1) * 26);
        final mainHeight = wide
            ? (widget.availableHeight - 112).clamp(520.0, 760.0)
            : math.max(
                430.0 + math.min(160.0, math.max(0.0, textScale - 1) * 120),
                math.min(620.0, widget.availableHeight - 112 - auxHeight),
              );
        final workspaceHeight = wide
            ? mainHeight
            : mainHeight + gap + auxHeight;
        final sideHeight = wide ? (workspaceHeight - gap) / 2 : auxHeight;

        ({double left, double top, double width, double height}) slotRect(
          int slot,
        ) {
          if (slot == 1) {
            return (left: 0, top: 0, width: mainWidth, height: mainHeight);
          }
          if (wide) {
            return (
              left: mainWidth + gap,
              top: slot == 0 ? 0 : sideHeight + gap,
              width: sideWidth,
              height: sideHeight,
            );
          }
          return (
            left: slot == 0 ? 0 : auxWidth + gap,
            top: mainHeight + gap,
            width: auxWidth,
            height: auxHeight,
          );
        }

        return SizedBox(
          height: workspaceHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (final service in HomeService.values)
                _buildPositionedService(
                  context: context,
                  service: service,
                  rect: slotRect(_slots.indexOf(service)),
                  mainWidth: mainWidth,
                  mainHeight: mainHeight,
                  compactSummary: !wide,
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 400),
                ),
            ],
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
    required Duration duration,
  }) {
    final isPrimary = _slots[1] == service;
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
                    child: widget.detailBuilder(service, isPrimary),
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
                    return Semantics(
                      button: true,
                      label: '${service.title}, ${data.status}, 주 영역으로 이동',
                      onTap: () => _promote(service),
                      child: InkWell(
                        onTap: () => _promote(service),
                        child: ExcludeSemantics(
                          child: _SummaryContent(
                            service: service,
                            data: data,
                            compact: compactSummary,
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

        return SingleChildScrollView(
          padding: const EdgeInsets.all(17),
          child: Column(
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
              const SizedBox(height: 15),
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
              if (data.facts.isNotEmpty) ...[
                const SizedBox(height: 13),
                Divider(height: 1, color: palette.cardOutline),
                const SizedBox(height: 12),
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
            ],
          ),
        );
      },
    );
  }
}
