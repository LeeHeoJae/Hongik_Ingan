import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hongik_ingan/features/food_menu/application/food_menu_controller.dart';
import 'package:hongik_ingan/features/food_menu/presentation/food_menu_detail_content.dart';
import 'package:hongik_ingan/features/home/presentation/widgets/wide_campus_info_card.dart';
import 'package:hongik_ingan/features/home/presentation/widgets/wide_food_menu_preview.dart';
import 'package:hongik_ingan/features/home/presentation/widgets/wide_panel_entrance.dart';
import 'package:hongik_ingan/features/home/presentation/widgets/wide_study_room_preview.dart';
import 'package:hongik_ingan/features/study_room/application/study_room_controller.dart';
import 'package:hongik_ingan/features/study_room/domain/study_room.dart';
import 'package:hongik_ingan/features/study_room/presentation/study_room_status_content.dart';

enum WideCampusPanelMode { overview, foodDetail, studyRoomDetail }

class WideCampusPanel extends ConsumerStatefulWidget {
  const WideCampusPanel({super.key, this.useDesktopTallLayout = false});

  final bool useDesktopTallLayout;

  @override
  ConsumerState<WideCampusPanel> createState() => _WideCampusPanelState();
}

class _WideCampusPanelState extends ConsumerState<WideCampusPanel>
    with SingleTickerProviderStateMixin {
  static const _cardGap = 18.0;
  static const _maxTallPanelHeight = 620.0;
  static const _expandDuration = Duration(milliseconds: 460);
  static const _contentSwitchDuration = Duration(milliseconds: 260);
  static const _expandCurve = Curves.easeInOutCubic;

  late final AnimationController _controller;
  WideCampusPanelMode _mode = WideCampusPanelMode.overview;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 680),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : _maxTallPanelHeight;
        final panelHeight = widget.useDesktopTallLayout
            ? math.min(maxHeight, _maxTallPanelHeight)
            : maxHeight;

        final panel = SizedBox(
          height: panelHeight,
          child: _buildExpandingPanel(panelHeight),
        );

        if (widget.useDesktopTallLayout) {
          return Align(alignment: Alignment.center, child: panel);
        }

        return panel;
      },
    );
  }

  Widget _buildExpandingPanel(double panelHeight) {
    final gapHeight = _mode == WideCampusPanelMode.overview ? _cardGap : 0.0;
    final availableHeight = math.max(0.0, panelHeight - gapHeight);
    final heights = _cardHeights(availableHeight);

    return Column(
      children: [
        _AnimatedCampusSlot(
          height: heights.food,
          duration: _expandDuration,
          curve: _expandCurve,
          child: _FoodCampusCard(
            controller: _controller,
            isExpanded: _mode == WideCampusPanelMode.foodDetail,
            child: _CampusCardContentSwitcher(
              isExpanded: _mode == WideCampusPanelMode.foodDetail,
              duration: _contentSwitchDuration,
              preview: const _FoodPreviewBody(),
              detail: const FoodMenuDetailContent(
                compact: true,
                useAdaptiveGrid: true,
              ),
            ),
            onOpen: () => _toggleMode(WideCampusPanelMode.foodDetail),
          ),
        ),
        AnimatedContainer(
          duration: _expandDuration,
          curve: _expandCurve,
          height: gapHeight,
        ),
        _AnimatedCampusSlot(
          height: heights.studyRoom,
          duration: _expandDuration,
          curve: _expandCurve,
          child: _StudyRoomCampusCard(
            controller: _controller,
            isExpanded: _mode == WideCampusPanelMode.studyRoomDetail,
            child: _CampusCardContentSwitcher(
              isExpanded: _mode == WideCampusPanelMode.studyRoomDetail,
              duration: _contentSwitchDuration,
              preview: const _StudyRoomPreviewBody(),
              detail: const StudyRoomStatusContent(
                compact: true,
                useGrid: true,
              ),
            ),
            onOpen: () => _toggleMode(WideCampusPanelMode.studyRoomDetail),
          ),
        ),
      ],
    );
  }

  ({double food, double studyRoom}) _cardHeights(double availableHeight) {
    if (_mode == WideCampusPanelMode.foodDetail) {
      return (food: availableHeight, studyRoom: 0);
    }
    if (_mode == WideCampusPanelMode.studyRoomDetail) {
      return (food: 0, studyRoom: availableHeight);
    }

    final foodRatio = widget.useDesktopTallLayout ? 280 / 600 : 9 / 17;
    final foodHeight = availableHeight * foodRatio;
    return (food: foodHeight, studyRoom: availableHeight - foodHeight);
  }

  void _toggleMode(WideCampusPanelMode mode) {
    setState(() {
      _mode = _mode == mode ? WideCampusPanelMode.overview : mode;
    });
  }

}

class _AnimatedCampusSlot extends StatelessWidget {
  const _AnimatedCampusSlot({
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
        final visibility = ((animatedHeight - _minVisibleChildHeight) /
                _visibilityFadeRange)
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

class _CampusCardContentSwitcher extends StatelessWidget {
  const _CampusCardContentSwitcher({
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

class _FoodPreviewBody extends ConsumerWidget {
  const _FoodPreviewBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foodState = ref.watch(foodMenuControllerProvider);
    return WideFoodMenuPreview(state: foodState);
  }
}

class _StudyRoomPreviewBody extends ConsumerWidget {
  const _StudyRoomPreviewBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studyRoomState = ref.watch(studyRoomControllerProvider);
    final studyRoomController = ref.read(studyRoomControllerProvider.notifier);

    return WideStudyRoomPreview(
      state: studyRoomState,
      onLocationSelected: studyRoomController.selectLocation,
      compact: true,
    );
  }
}

class _FoodCampusCard extends ConsumerWidget {
  const _FoodCampusCard({
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
    final foodState = ref.watch(foodMenuControllerProvider);
    final foodController = ref.read(foodMenuControllerProvider.notifier);

    return WidePanelEntrance(
      controller: controller,
      begin: 0.0,
      end: 0.72,
      child: WideCampusInfoCard(
        icon: Icons.restaurant_menu_rounded,
        title: '오늘의 식당 메뉴',
        subtitle: _foodSubtitle(foodState),
        isRefreshing: foodState.isLoading && foodState.menus.isNotEmpty,
        isExpanded: isExpanded,
        onRefresh: () => unawaited(foodController.refresh()),
        onOpen: onOpen,
        child: child,
      ),
    );
  }

  String _foodSubtitle(FoodMenuState state) {
    final cafeteria = state.selectedCafeteria;
    if (cafeteria != null) return cafeteria.name;
    if (state.isLoading) return '메뉴를 불러오는 중';
    return '기숙사 식당 / 교직원 식당';
  }
}

class _StudyRoomCampusCard extends ConsumerWidget {
  const _StudyRoomCampusCard({
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
    final studyRoomState = ref.watch(studyRoomControllerProvider);
    final studyRoomController = ref.read(studyRoomControllerProvider.notifier);

    return WidePanelEntrance(
      controller: controller,
      begin: 0.14,
      end: 0.92,
      child: WideCampusInfoCard(
        icon: Icons.local_library_rounded,
        title: '열람실 좌석 현황',
        subtitle: _studyRoomSubtitle(studyRoomState),
        isRefreshing:
            studyRoomState.isLoading && studyRoomState.statuses.isNotEmpty,
        isExpanded: isExpanded,
        onRefresh: () => unawaited(studyRoomController.refresh()),
        onOpen: onOpen,
        child: child,
      ),
    );
  }

  String _studyRoomSubtitle(StudyRoomState state) {
    final status = state.status;
    if (status == null) return '학관 / T동 / R동';
    final hour = status.updatedAt.hour.toString().padLeft(2, '0');
    final minute = status.updatedAt.minute.toString().padLeft(2, '0');
    return '${status.location.label} $hour:$minute 기준';
  }
}
