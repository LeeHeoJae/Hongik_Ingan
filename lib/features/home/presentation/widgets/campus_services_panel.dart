import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hongik_ingan/features/cafeteria_menu/application/cafeteria_menu_controller.dart';
import 'package:hongik_ingan/features/cafeteria_menu/presentation/cafeteria_menu_content.dart';
import 'package:hongik_ingan/features/home/presentation/widgets/cafeteria_menu_preview.dart';
import 'package:hongik_ingan/features/home/presentation/widgets/campus_service_card.dart';
import 'package:hongik_ingan/features/home/presentation/widgets/panel_entrance_transition.dart';
import 'package:hongik_ingan/features/home/presentation/widgets/seat_status_preview.dart';
import 'package:hongik_ingan/features/seat/application/seat_controller.dart';
import 'package:hongik_ingan/features/seat/domain/seat.dart';
import 'package:hongik_ingan/features/seat/presentation/seat_auto_refresh.dart';
import 'package:hongik_ingan/features/seat/presentation/seat_status_content.dart';

enum _CampusServicesPanelMode { overview, menuDetail, seatDetail }

class CampusServicesPanel extends ConsumerStatefulWidget {
  const CampusServicesPanel({super.key, this.centerVertically = false});

  final bool centerVertically;

  @override
  ConsumerState<CampusServicesPanel> createState() =>
      _CampusServicesPanelState();
}

class _CampusServicesPanelState extends ConsumerState<CampusServicesPanel>
    with SingleTickerProviderStateMixin {
  static const _cardGap = 18.0;
  static const _maxTallPanelHeight = 620.0;
  static const _expandDuration = Duration(milliseconds: 460);
  static const _contentSwitchDuration = Duration(milliseconds: 260);
  static const _expandCurve = Curves.easeInOutCubic;

  late final AnimationController _controller;
  _CampusServicesPanelMode _mode = _CampusServicesPanelMode.overview;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SeatAutoRefresh(
      enabled: _mode != _CampusServicesPanelMode.menuDetail,
      onRefresh: () =>
          ref.read(seatControllerProvider.notifier).fetchSelectedStatus(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxHeight = constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : _maxTallPanelHeight;
          final panelHeight = widget.centerVertically
              ? math.min(maxHeight, _maxTallPanelHeight)
              : maxHeight;

          final panel = SizedBox(
            height: panelHeight,
            child: _buildExpandingPanel(panelHeight),
          );

          if (widget.centerVertically) {
            return Align(alignment: Alignment.center, child: panel);
          }

          return panel;
        },
      ),
    );
  }

  Widget _buildExpandingPanel(double panelHeight) {
    final gapHeight = _mode == _CampusServicesPanelMode.overview
        ? _cardGap
        : 0.0;
    final availableHeight = math.max(0.0, panelHeight - gapHeight);
    final heights = _cardHeights(availableHeight);

    return Column(
      children: [
        _AnimatedServiceSlot(
          height: heights.menu,
          duration: _expandDuration,
          curve: _expandCurve,
          child: _CafeteriaMenuServiceCard(
            controller: _controller,
            isExpanded: _mode == _CampusServicesPanelMode.menuDetail,
            child: _ServiceCardContentSwitcher(
              isExpanded: _mode == _CampusServicesPanelMode.menuDetail,
              duration: _contentSwitchDuration,
              preview: const _CafeteriaMenuPreviewBody(),
              detail: const CafeteriaMenuContent(
                compact: true,
                useAdaptiveGrid: true,
              ),
            ),
            onOpen: () => _toggleMode(_CampusServicesPanelMode.menuDetail),
          ),
        ),
        AnimatedContainer(
          duration: _expandDuration,
          curve: _expandCurve,
          height: gapHeight,
        ),
        _AnimatedServiceSlot(
          height: heights.seat,
          duration: _expandDuration,
          curve: _expandCurve,
          child: _SeatStatusServiceCard(
            controller: _controller,
            isExpanded: _mode == _CampusServicesPanelMode.seatDetail,
            child: _ServiceCardContentSwitcher(
              isExpanded: _mode == _CampusServicesPanelMode.seatDetail,
              duration: _contentSwitchDuration,
              preview: const _SeatPreviewBody(),
              detail: const SeatStatusContent(compact: true, useGrid: true),
            ),
            onOpen: () => _toggleMode(_CampusServicesPanelMode.seatDetail),
          ),
        ),
      ],
    );
  }

  ({double menu, double seat}) _cardHeights(double availableHeight) {
    if (_mode == _CampusServicesPanelMode.menuDetail) {
      return (menu: availableHeight, seat: 0);
    }
    if (_mode == _CampusServicesPanelMode.seatDetail) {
      return (menu: 0, seat: availableHeight);
    }

    final menuRatio = widget.centerVertically ? 280 / 600 : 9 / 17;
    final menuHeight = availableHeight * menuRatio;
    return (menu: menuHeight, seat: availableHeight - menuHeight);
  }

  void _toggleMode(_CampusServicesPanelMode mode) {
    final willExpand = _mode != mode;
    setState(() {
      _mode = _mode == mode ? _CampusServicesPanelMode.overview : mode;
    });
    if (willExpand && mode == _CampusServicesPanelMode.menuDetail) {
      unawaited(
        ref.read(cafeteriaMenuControllerProvider.notifier).fetchMenus(),
      );
    }
  }
}

class _AnimatedServiceSlot extends StatelessWidget {
  const _AnimatedServiceSlot({
    required this.height,
    required this.duration,
    required this.curve,
    required this.child,
  });

  final double height;
  final Duration duration;
  final Curve curve;
  final Widget child;
  static const _minVisibleChildHeight = 180.0;
  static const _visibilityFadeRange = 96.0;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: height),
      duration: duration,
      curve: curve,
      child: child,
      builder: (context, animatedHeight, child) {
        final isHidden = animatedHeight < _minVisibleChildHeight;
        final visibility =
            ((animatedHeight - _minVisibleChildHeight) / _visibilityFadeRange)
                .clamp(0.0, 1.0)
                .toDouble();

        return SizedBox(
          height: animatedHeight,
          child: isHidden
              ? const SizedBox.shrink()
              : Opacity(
                  opacity: visibility,
                  child: Transform.translate(
                    offset: Offset(0, 8 * (1 - visibility)),
                    child: child,
                  ),
                ),
        );
      },
    );
  }
}

class _ServiceCardContentSwitcher extends StatelessWidget {
  const _ServiceCardContentSwitcher({
    required this.isExpanded,
    required this.duration,
    required this.preview,
    required this.detail,
  });

  final bool isExpanded;
  final Duration duration;
  final Widget preview;
  final Widget detail;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedSwitcher(
        duration: duration,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        layoutBuilder: (currentChild, previousChildren) {
          return Stack(
            fit: StackFit.expand,
            children: [...previousChildren, ?currentChild],
          );
        },
        transitionBuilder: (child, animation) {
          final offset = Tween<Offset>(
            begin: const Offset(0, 0.025),
            end: Offset.zero,
          ).animate(animation);

          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: offset, child: child),
          );
        },
        child: KeyedSubtree(
          key: ValueKey(isExpanded),
          child: isExpanded ? detail : preview,
        ),
      ),
    );
  }
}

class _CafeteriaMenuPreviewBody extends ConsumerWidget {
  const _CafeteriaMenuPreviewBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menuState = ref.watch(cafeteriaMenuControllerProvider);
    final selectedMenu = menuState.selectedMenu;
    final phase = menuState.menus.isEmpty && menuState.error == null
        ? 'pending'
        : selectedMenu?.status.name ?? 'empty';

    return _PreviewTransition(
      transitionKey: 'menu:$phase',
      child: CafeteriaMenuPreview(state: menuState),
    );
  }
}

class _SeatPreviewBody extends ConsumerWidget {
  const _SeatPreviewBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seatState = ref.watch(seatControllerProvider);
    final seatController = ref.read(seatControllerProvider.notifier);
    final phase = seatState.status != null
        ? 'loaded'
        : seatState.error != null
        ? 'error'
        : 'pending';

    return _PreviewTransition(
      transitionKey: 'seat:${seatState.selectedLocation.name}:$phase',
      child: SeatStatusPreview(
        state: seatState,
        onLocationSelected: seatController.selectLocation,
        compact: true,
      ),
    );
  }
}

class _PreviewTransition extends StatelessWidget {
  const _PreviewTransition({required this.transitionKey, required this.child});

  final Object transitionKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      reverseDuration: const Duration(milliseconds: 140),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          fit: StackFit.expand,
          children: [...previousChildren, ?currentChild],
        );
      },
      transitionBuilder: (child, animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: KeyedSubtree(key: ValueKey(transitionKey), child: child),
    );
  }
}

class _CafeteriaMenuServiceCard extends ConsumerWidget {
  const _CafeteriaMenuServiceCard({
    required this.controller,
    required this.isExpanded,
    required this.child,
    required this.onOpen,
  });

  final AnimationController controller;
  final bool isExpanded;
  final Widget child;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menuState = ref.watch(cafeteriaMenuControllerProvider);
    final menuController = ref.read(cafeteriaMenuControllerProvider.notifier);

    return PanelEntranceTransition(
      controller: controller,
      begin: 0.0,
      end: 0.72,
      child: CampusServiceCard(
        icon: Icons.restaurant_menu_rounded,
        title: '주간 식당 메뉴',
        subtitle: _menuSubtitle(menuState),
        isRefreshing: menuState.isLoading && menuState.menus.isNotEmpty,
        isExpanded: isExpanded,
        onRefresh: () => unawaited(menuController.refresh()),
        onOpen: onOpen,
        child: child,
      ),
    );
  }

  String _menuSubtitle(CafeteriaMenuState state) {
    final cafeteria = state.selectedCafeteria;
    if (cafeteria != null) return cafeteria.name;
    if (state.isLoading) return '메뉴를 불러오는 중';
    return '기숙사 식당 / 교직원 식당';
  }
}

class _SeatStatusServiceCard extends ConsumerWidget {
  const _SeatStatusServiceCard({
    required this.controller,
    required this.isExpanded,
    required this.child,
    required this.onOpen,
  });

  final AnimationController controller;
  final bool isExpanded;
  final Widget child;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seatState = ref.watch(seatControllerProvider);
    final seatController = ref.read(seatControllerProvider.notifier);

    return PanelEntranceTransition(
      controller: controller,
      begin: 0.14,
      end: 0.92,
      child: CampusServiceCard(
        icon: Icons.local_library_rounded,
        title: '열람실 좌석 현황',
        subtitle: _seatSubtitle(seatState),
        isRefreshing: seatState.isLoading && seatState.statuses.isNotEmpty,
        isExpanded: isExpanded,
        onRefresh: () => unawaited(seatController.refresh()),
        onOpen: onOpen,
        child: child,
      ),
    );
  }

  String _seatSubtitle(SeatState state) {
    final status = state.status;
    if (status == null) return '학관 / T동 / R동';
    final hour = status.updatedAt.hour.toString().padLeft(2, '0');
    final minute = status.updatedAt.minute.toString().padLeft(2, '0');
    if (state.error != null) {
      return '${status.location.label} 갱신 실패, $hour:$minute 기준';
    }
    return '${status.location.label} $hour:$minute 기준';
  }
}
