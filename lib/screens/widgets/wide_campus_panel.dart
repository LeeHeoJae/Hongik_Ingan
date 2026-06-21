import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/food_menu_controller.dart';
import '../../controllers/study_room_controller.dart';
import '../../core/theme/color.dart';
import '../../models/food_menu.dart';
import '../../models/study_room.dart';

class WideCampusPanel extends ConsumerStatefulWidget {
  const WideCampusPanel({
    super.key,
    required this.onFoodMenuTap,
    required this.onStudyRoomTap,
    this.useDesktopTallLayout = false,
  });

  final VoidCallback onFoodMenuTap;
  final VoidCallback onStudyRoomTap;
  final bool useDesktopTallLayout;

  @override
  ConsumerState<WideCampusPanel> createState() => _WideCampusPanelState();
}

class _WideCampusPanelState extends ConsumerState<WideCampusPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

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
    final foodState = ref.watch(foodMenuControllerProvider);
    final foodController = ref.read(foodMenuControllerProvider.notifier);
    final studyRoomState = ref.watch(studyRoomControllerProvider);
    final studyRoomController = ref.read(studyRoomControllerProvider.notifier);

    if (widget.useDesktopTallLayout) {
      return Align(
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 280,
              child: _buildFoodCard(foodState, foodController),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 360,
              child: _buildStudyRoomCard(studyRoomState, studyRoomController),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          flex: 4,
          child: _buildFoodCard(foodState, foodController),
        ),
        const SizedBox(height: 18),
        Expanded(
          flex: 5,
          child: _buildStudyRoomCard(studyRoomState, studyRoomController),
        ),
      ],
    );
  }

  Widget _buildFoodCard(
    FoodMenuState foodState,
    FoodMenuController foodController,
  ) {
    return _WidePanelEntrance(
      controller: _controller,
      begin: 0.0,
      end: 0.72,
      child: _CampusInfoCard(
        icon: Icons.restaurant_menu_rounded,
        title: '오늘의 식당 메뉴',
        subtitle: _foodSubtitle(foodState),
        isRefreshing: foodState.isLoading && foodState.menus.isNotEmpty,
        onRefresh: () => unawaited(foodController.refresh()),
        onOpen: widget.onFoodMenuTap,
        child: _FoodMenuPreview(state: foodState),
      ),
    );
  }

  Widget _buildStudyRoomCard(
    StudyRoomState studyRoomState,
    StudyRoomController studyRoomController,
  ) {
    return _WidePanelEntrance(
      controller: _controller,
      begin: 0.14,
      end: 0.92,
      child: _CampusInfoCard(
        icon: Icons.local_library_rounded,
        title: '열람실 좌석 현황',
        subtitle: _studyRoomSubtitle(studyRoomState),
        isRefreshing:
            studyRoomState.isLoading && studyRoomState.statuses.isNotEmpty,
        onRefresh: () => unawaited(studyRoomController.refresh()),
        onOpen: widget.onStudyRoomTap,
        child: _StudyRoomPreview(
          state: studyRoomState,
          onLocationSelected: studyRoomController.selectLocation,
        ),
      ),
    );
  }

  String _foodSubtitle(FoodMenuState state) {
    final cafeteria = state.selectedCafeteria;
    if (cafeteria != null) return cafeteria.name;
    if (state.isLoading) return '메뉴를 불러오는 중';
    return '기숙사 식당 / 교직원 식당';
  }

  String _studyRoomSubtitle(StudyRoomState state) {
    final status = state.status;
    if (status == null) return '학관 / T동 / R동';
    final hour = status.updatedAt.hour.toString().padLeft(2, '0');
    final minute = status.updatedAt.minute.toString().padLeft(2, '0');
    return '${status.location.label} $hour:$minute 기준';
  }
}

class _WidePanelEntrance extends StatelessWidget {
  const _WidePanelEntrance({
    required this.controller,
    required this.begin,
    required this.end,
    required this.child,
  });

  final AnimationController controller;
  final double begin;
  final double end;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: controller,
      curve: Interval(begin, end, curve: Curves.easeOutCubic),
    );

    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

class _CampusInfoCard extends StatelessWidget {
  const _CampusInfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
    required this.onOpen,
    this.onRefresh,
    this.isRefreshing = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;
  final VoidCallback onOpen;
  final VoidCallback? onRefresh;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette =
        Theme.of(context).extension<HongikPalette>() ?? HongikPalette.light;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.055),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: palette.brandNavy.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: palette.brandNavy, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.58),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '새로고침',
                  onPressed: isRefreshing ? null : onRefresh,
                  icon: isRefreshing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        )
                      : const Icon(Icons.refresh_rounded),
                ),
                IconButton(
                  tooltip: '전체 보기',
                  onPressed: onOpen,
                  icon: const Icon(Icons.open_in_full_rounded),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _FoodMenuPreview extends StatelessWidget {
  const _FoodMenuPreview({required this.state});

  final FoodMenuState state;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading && state.menus.isEmpty) {
      return const _PreviewLoading();
    }

    final selectedMenu = state.selectedMenu;
    if (selectedMenu == null) {
      return _PreviewMessage(
        icon: Icons.restaurant_rounded,
        title: '메뉴 정보가 없습니다',
        message: state.error ?? '오늘 표시할 메뉴를 아직 불러오지 못했습니다.',
      );
    }

    if (selectedMenu.status == FoodMenuDayStatus.networkError ||
        selectedMenu.status == FoodMenuDayStatus.parseFailed) {
      return _PreviewMessage(
        icon: Icons.wifi_off_rounded,
        title: '메뉴를 불러오지 못했습니다',
        message: selectedMenu.message ?? '잠시 후 다시 시도해주세요.',
      );
    }

    if (!selectedMenu.hasMenu) {
      return const _PreviewMessage(
        icon: Icons.no_food_rounded,
        title: '등록된 메뉴가 없습니다',
        message: '선택한 날짜의 식당 메뉴가 비어 있습니다.',
      );
    }

    final cafeteria = state.selectedCafeteria;
    if (cafeteria == null) {
      return const _PreviewMessage(
        icon: Icons.storefront_rounded,
        title: '식당 정보가 없습니다',
        message: '표시할 식당을 찾지 못했습니다.',
      );
    }

    final meals = cafeteria.meals
        .where((meal) => meal.items.isNotEmpty)
        .toList(growable: false);

    if (meals.isEmpty) {
      return const _PreviewMessage(
        icon: Icons.no_meals_rounded,
        title: '표시할 메뉴가 없습니다',
        message: '현재 식단 항목이 비어 있습니다.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MetaLine(icon: Icons.storefront_rounded, text: cafeteria.name),
        if (cafeteria.priceInfo.isNotEmpty) ...[
          const SizedBox(height: 6),
          _MetaLine(icon: Icons.payments_outlined, text: cafeteria.priceInfo),
        ],
        const SizedBox(height: 12),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: meals.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              return _MealPreviewRow(meal: meals[index]);
            },
          ),
        ),
      ],
    );
  }
}

class _MealPreviewRow extends StatelessWidget {
  const _MealPreviewRow({required this.meal});

  final MealMenu meal;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final preview = meal.items.take(4).join(', ');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 48,
            child: Text(
              meal.type.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colorScheme.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              preview,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.78),
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StudyRoomPreview extends StatelessWidget {
  const _StudyRoomPreview({
    required this.state,
    required this.onLocationSelected,
  });

  final StudyRoomState state;
  final ValueChanged<StudyRoomLocation> onLocationSelected;

  @override
  Widget build(BuildContext context) {
    final status = state.status;
    final summary = status?.summary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StudyRoomLocationTabs(
          selectedLocation: state.selectedLocation,
          onSelected: onLocationSelected,
        ),
        const SizedBox(height: 12),
        if (state.isLoading && status == null)
          const Expanded(child: _PreviewLoading())
        else if (state.error != null && status == null)
          Expanded(
            child: _PreviewMessage(
              icon: Icons.wifi_off_rounded,
              title: '좌석 현황을 불러오지 못했습니다',
              message: state.error!,
            ),
          )
        else if (status == null || summary == null)
          const Expanded(
            child: _PreviewMessage(
              icon: Icons.event_seat_outlined,
              title: '좌석 정보가 없습니다',
              message: '표시할 열람실 좌석 정보가 없습니다.',
            ),
          )
        else
          Expanded(child: _StudyRoomSnapshot(status: status)),
      ],
    );
  }
}

class _StudyRoomLocationTabs extends StatelessWidget {
  const _StudyRoomLocationTabs({
    required this.selectedLocation,
    required this.onSelected,
  });

  final StudyRoomLocation selectedLocation;
  final ValueChanged<StudyRoomLocation> onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final palette =
        Theme.of(context).extension<HongikPalette>() ?? HongikPalette.light;

    return Row(
      children: StudyRoomLocation.values
          .map((location) {
            final selected = selectedLocation == location;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: location == StudyRoomLocation.values.last ? 0 : 8,
                ),
                child: InkWell(
                  onTap: () => onSelected(location),
                  borderRadius: BorderRadius.circular(14),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? palette.brandNavy
                          : colorScheme.surfaceContainerHighest.withValues(
                              alpha: 0.42,
                            ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      location.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? Colors.white : colorScheme.onSurface,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            );
          })
          .toList(growable: false),
    );
  }
}

class _StudyRoomSnapshot extends StatelessWidget {
  const _StudyRoomSnapshot({required this.status});

  final StudyRoomStatus status;

  @override
  Widget build(BuildContext context) {
    final rooms = status.rooms;

    if (rooms.isEmpty) {
      return const _PreviewMessage(
        icon: Icons.event_seat_outlined,
        title: '세부 좌석 정보가 없습니다',
        message: '선택한 열람실의 세부 좌석 목록이 비어 있습니다.',
      );
    }

    return _StudyRoomRoomGrid(rooms: rooms);
  }
}

class _StudyRoomRoomGrid extends StatelessWidget {
  const _StudyRoomRoomGrid({required this.rooms});

  final List<StudyRoomSeat> rooms;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 560
            ? 3
            : constraints.maxWidth >= 360
            ? 2
            : 1;

        return Scrollbar(
          child: GridView.builder(
            padding: EdgeInsets.zero,
            itemCount: rooms.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 9,
              mainAxisSpacing: 9,
              mainAxisExtent: 68,
            ),
            itemBuilder: (context, index) {
              return _StudyRoomRoomCard(seat: rooms[index]);
            },
          ),
        );
      },
    );
  }
}

class _StudyRoomRoomCard extends StatelessWidget {
  const _StudyRoomRoomCard({required this.seat});

  final StudyRoomSeat seat;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final usageColor = _usageColor(context, seat.usageRate);
    final usageValue = (seat.usageRate / 100).clamp(0.0, 1.0).toDouble();

    return Container(
      padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  seat.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${seat.availableSeats}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: usageColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ],
          ),
          const Spacer(),
          LinearProgressIndicator(
            value: usageValue,
            minHeight: 5,
            borderRadius: BorderRadius.circular(999),
            color: usageColor,
            backgroundColor: colorScheme.surface,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  '잔여 ${seat.availableSeats}/${seat.totalSeats}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colorScheme.onSurface.withValues(alpha: 0.58),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                _formatRate(seat.usageRate),
                style: TextStyle(
                  color: usageColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: colorScheme.onSurface.withValues(alpha: 0.56),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.62),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _PreviewLoading extends StatelessWidget {
  const _PreviewLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _PreviewMessage extends StatelessWidget {
  const _PreviewMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 34,
              color: colorScheme.primary.withValues(alpha: 0.86),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.58),
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _usageColor(BuildContext context, double usageRate) {
  final palette =
      Theme.of(context).extension<HongikPalette>() ?? HongikPalette.light;
  if (usageRate >= 85) {
    return palette.brandRed;
  }
  if (usageRate >= 65) {
    return palette.warning;
  }
  if (usageRate >= 40) {
    return palette.brandBlue;
  }
  return palette.success;
}

String _formatRate(double rate) {
  final normalized = rate.clamp(0, 100);
  if (normalized == normalized.roundToDouble()) {
    return '${normalized.toStringAsFixed(0)}%';
  }
  return '${normalized.toStringAsFixed(1)}%';
}
