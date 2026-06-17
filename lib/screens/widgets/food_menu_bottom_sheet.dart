import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/food_menu_controller.dart';
import '../../core/theme/color.dart';
import '../../models/food_menu.dart';
import 'campus_sheet_scaffold.dart';

class FoodMenuBottomSheet extends ConsumerStatefulWidget {
  const FoodMenuBottomSheet({super.key});

  @override
  ConsumerState<FoodMenuBottomSheet> createState() =>
      _FoodMenuBottomSheetState();
}

class _FoodMenuBottomSheetState extends ConsumerState<FoodMenuBottomSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(foodMenuControllerProvider.notifier).fetchMenus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(foodMenuControllerProvider);
    final controller = ref.read(foodMenuControllerProvider.notifier);
    final selectedDate = state.selectedDate;

    return CampusSheetScaffold(
      title: '식당 메뉴',
      subtitle:
          '${FoodMenuDateRange.monthDayLabel(selectedDate)} ${FoodMenuDateRange.weekdayLabel(selectedDate)}요일',
      icon: Icons.restaurant_menu_rounded,
      isRefreshing: state.isLoading && state.menus.isNotEmpty,
      onRefresh: () => controller.refresh(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FoodDateSelector(
            dates: state.dates,
            selectedDate: state.selectedDate,
            today: state.baseDate,
            onSelected: controller.selectDate,
          ),
          const SizedBox(height: 18),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _buildContent(context, state, controller),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    FoodMenuState state,
    FoodMenuController controller,
  ) {
    if (state.isLoading && state.menus.isEmpty) {
      return const CampusLoadingSkeleton(key: ValueKey('loading'));
    }

    final selectedMenu = state.selectedMenu;
    if (selectedMenu == null) {
      return CampusStateMessage(
        key: const ValueKey('empty'),
        icon: Icons.restaurant_rounded,
        title: '메뉴를 준비하고 있습니다',
        message: '선택한 날짜의 메뉴 정보를 아직 불러오지 못했습니다.',
        actionLabel: '새로고침',
        onAction: controller.refresh,
      );
    }

    if (selectedMenu.status == FoodMenuDayStatus.networkError) {
      return CampusStateMessage(
        key: ValueKey('network-${selectedMenu.date}'),
        icon: Icons.wifi_off_rounded,
        title: '식당 메뉴를 불러오지 못했습니다',
        message: selectedMenu.message ?? '식당 메뉴 페이지에 연결할 수 없습니다.',
        actionLabel: '다시 시도',
        onAction: controller.refresh,
      );
    }

    if (selectedMenu.status == FoodMenuDayStatus.parseFailed) {
      return CampusStateMessage(
        key: ValueKey('parse-${selectedMenu.date}'),
        icon: Icons.error_outline_rounded,
        title: '메뉴를 읽지 못했습니다',
        message: selectedMenu.message ?? '식당 메뉴 페이지 형식이 변경되었을 수 있습니다.',
        actionLabel: '다시 시도',
        onAction: controller.refresh,
      );
    }

    if (!selectedMenu.hasMenu) {
      final title = selectedMenu.isWeekend ? '운영하지 않는 날입니다' : '등록된 메뉴가 없습니다';
      final message = selectedMenu.isWeekend
          ? '선택한 날짜에는 식당 운영 정보가 없습니다.'
          : '선택한 날짜에 등록된 식단 정보가 없습니다.';
      return CampusStateMessage(
        key: ValueKey('no-menu-${selectedMenu.date}'),
        icon: Icons.no_food_rounded,
        title: title,
        message: message,
        actionLabel: '새로고침',
        onAction: controller.refresh,
      );
    }

    return ListView.separated(
      key: ValueKey('content-${selectedMenu.date}'),
      padding: const EdgeInsets.only(bottom: 4),
      itemCount: selectedMenu.cafeterias.length,
      separatorBuilder: (context, index) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        return _CafeteriaMenuSection(cafeteria: selectedMenu.cafeterias[index]);
      },
    );
  }
}

class _FoodDateSelector extends StatelessWidget {
  const _FoodDateSelector({
    required this.dates,
    required this.selectedDate,
    required this.today,
    required this.onSelected,
  });

  final List<DateTime> dates;
  final DateTime selectedDate;
  final DateTime today;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: dates
            .map((date) {
              final isSelected = FoodMenuDateRange.isSameDate(
                date,
                selectedDate,
              );
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _FoodDateChip(
                  date: date,
                  isSelected: isSelected,
                  isToday: FoodMenuDateRange.isSameDate(date, today),
                  onTap: () => onSelected(date),
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }
}

class _FoodDateChip extends StatelessWidget {
  const _FoodDateChip({
    required this.date,
    required this.isSelected,
    required this.isToday,
    required this.onTap,
  });

  final DateTime date;
  final bool isSelected;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final palette =
        Theme.of(context).extension<HongikPalette>() ?? HongikPalette.light;
    final backgroundColor = isSelected
        ? palette.brandBlue
        : colorScheme.surfaceContainerHighest.withValues(alpha: 0.44);
    final foregroundColor = isSelected ? Colors.white : colorScheme.onSurface;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 78,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? palette.brandBlue : colorScheme.outlineVariant,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${FoodMenuDateRange.weekdayLabel(date)}요일',
              style: TextStyle(
                color: foregroundColor.withValues(alpha: 0.76),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${date.month}.${date.day}',
              style: TextStyle(
                color: foregroundColor,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 16,
              child: isToday
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.18)
                            : palette.brandRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '오늘',
                        style: TextStyle(
                          color: isSelected ? Colors.white : palette.brandRed,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _CafeteriaMenuSection extends StatelessWidget {
  const _CafeteriaMenuSection({required this.cafeteria});

  final CafeteriaMenu cafeteria;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.storefront_rounded, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cafeteria.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (cafeteria.priceInfo.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        cafeteria.priceInfo,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.58),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (cafeteria.meals.isEmpty)
            Text(
              '등록된 식사 정보가 없습니다.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            )
          else
            ...cafeteria.meals.map((meal) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _MealMenuCard(meal: meal),
              );
            }),
        ],
      ),
    );
  }
}

class _MealMenuCard extends StatelessWidget {
  const _MealMenuCard({required this.meal});

  final MealMenu meal;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final mealColor = _mealColor(context, meal.type);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: mealColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  meal.type.label,
                  style: TextStyle(
                    color: mealColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (meal.time.isNotEmpty) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    meal.time,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.58),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          ...meal.items.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(top: 7, right: 9),
                    decoration: BoxDecoration(
                      color: mealColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

Color _mealColor(BuildContext context, MealType type) {
  final palette =
      Theme.of(context).extension<HongikPalette>() ?? HongikPalette.light;
  return switch (type) {
    MealType.breakfast => palette.warning,
    MealType.lunch => palette.brandBlue,
    MealType.dinner => palette.brandRed,
  };
}
