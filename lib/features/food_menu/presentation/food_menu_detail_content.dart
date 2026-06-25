import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hongik_ingan/core/theme/color.dart';
import 'package:hongik_ingan/features/campus/presentation/campus_segmented_selector.dart';
import 'package:hongik_ingan/features/campus/presentation/campus_sheet_scaffold.dart';
import 'package:hongik_ingan/features/food_menu/application/food_menu_controller.dart';
import 'package:hongik_ingan/features/food_menu/domain/food_menu.dart';

class FoodMenuDetailContent extends ConsumerWidget {
  const FoodMenuDetailContent({
    super.key,
    this.compact = false,
    this.useAdaptiveGrid = false,
  });

  final bool compact;
  final bool useAdaptiveGrid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(foodMenuControllerProvider);
    final controller = ref.read(foodMenuControllerProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FoodDateSelector(
          dates: state.dates,
          selectedDate: state.selectedDate,
          onSelected: controller.selectDate,
          compact: compact,
        ),
        if (_shouldShowCafeteriaSelector(state)) ...[
          SizedBox(height: compact ? 10 : 14),
          _CafeteriaSelector(
            cafeterias: state.selectedMenu!.cafeterias,
            selectedName: state.selectedCafeteria?.name,
            onSelected: controller.selectCafeteria,
            compact: compact,
          ),
        ],
        SizedBox(height: compact ? 12 : 16),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: _buildContent(context, state, controller),
          ),
        ),
      ],
    );
  }

  bool _shouldShowCafeteriaSelector(FoodMenuState state) {
    final menu = state.selectedMenu;
    return menu != null &&
        menu.status == FoodMenuDayStatus.loaded &&
        menu.cafeterias.length > 1;
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

    final cafeteria = state.selectedCafeteria;
    if (cafeteria == null) {
      return CampusStateMessage(
        key: ValueKey('no-cafeteria-${selectedMenu.date}'),
        icon: Icons.storefront_rounded,
        title: '식당 정보가 없습니다',
        message: '선택한 날짜에 표시할 식당 정보가 없습니다.',
        actionLabel: '새로고침',
        onAction: controller.refresh,
      );
    }

    return ListView(
      key: ValueKey('content-${selectedMenu.date}-${cafeteria.name}'),
      padding: const EdgeInsets.only(bottom: 2),
      children: [
        _CafeteriaMenuSection(
          cafeteria: cafeteria,
          compact: compact,
          useAdaptiveGrid: useAdaptiveGrid,
        ),
      ],
    );
  }
}

class _FoodDateSelector extends StatelessWidget {
  const _FoodDateSelector({
    required this.dates,
    required this.selectedDate,
    required this.onSelected,
    required this.compact,
  });

  final List<DateTime> dates;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final selected = dates.firstWhere(
      (date) => FoodMenuDateRange.isSameDate(date, selectedDate),
      orElse: () => dates.first,
    );

    return CampusSegmentedSelector<DateTime>(
      items: dates,
      selectedItem: selected,
      labelOf: FoodMenuDateRange.weekdayLabel,
      onSelected: onSelected,
      height: compact ? 36 : 42,
      fontSize: compact ? 14 : 15,
    );
  }
}

class _CafeteriaSelector extends StatelessWidget {
  const _CafeteriaSelector({
    required this.cafeterias,
    required this.selectedName,
    required this.onSelected,
    required this.compact,
  });

  final List<CafeteriaMenu> cafeterias;
  final String? selectedName;
  final ValueChanged<String> onSelected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ordered = _orderedCafeterias(cafeterias);
    final selected = ordered.firstWhere(
      (cafeteria) => cafeteria.name == selectedName,
      orElse: () => ordered.first,
    );

    return CampusSegmentedSelector<CafeteriaMenu>(
      items: ordered,
      selectedItem: selected,
      labelOf: (cafeteria) => _shortName(cafeteria.name),
      onSelected: (cafeteria) => onSelected(cafeteria.name),
      height: compact ? 38 : 43,
      fontSize: compact ? 13 : 14,
    );
  }

  List<CafeteriaMenu> _orderedCafeterias(List<CafeteriaMenu> source) {
    final cafeterias = [...source];
    cafeterias.sort((a, b) {
      final aScore = a.name.contains('학생') ? 0 : 1;
      final bScore = b.name.contains('학생') ? 0 : 1;
      return aScore.compareTo(bScore);
    });
    return cafeterias;
  }

  String _shortName(String name) {
    if (name.contains('학생')) {
      return '기숙사 식당';
    }
    if (name.contains('교직원')) {
      return '교직원 식당';
    }
    return name;
  }
}

class _CafeteriaMenuSection extends StatelessWidget {
  const _CafeteriaMenuSection({
    required this.cafeteria,
    required this.compact,
    required this.useAdaptiveGrid,
  });

  final CafeteriaMenu cafeteria;
  final bool compact;
  final bool useAdaptiveGrid;

  @override
  Widget build(BuildContext context) {
    final meals = {
      for (final meal in cafeteria.meals)
        if (meal.items.isNotEmpty) meal.type: meal,
    };
    final priceInfo = _compactPriceInfo(cafeteria.priceInfo);
    final entries = meals.entries.toList(growable: false);

    return LayoutBuilder(
      builder: (context, constraints) {
        final canUseGrid =
            useAdaptiveGrid && constraints.maxWidth >= 520 && entries.length > 1;
        if (!canUseGrid) {
          return Column(
            children: entries.map((entry) {
              return Padding(
                padding: EdgeInsets.only(bottom: compact ? 10 : 14),
                child: _MealMenuCard(
                  type: entry.key,
                  meal: entry.value,
                  priceInfo: priceInfo,
                  compact: compact,
                ),
              );
            }).toList(growable: false),
          );
        }

        final spacing = compact ? 10.0 : 12.0;
        final itemWidth = (constraints.maxWidth - spacing) / 2;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: entries.map((entry) {
            return SizedBox(
              width: itemWidth,
              child: _MealMenuCard(
                type: entry.key,
                meal: entry.value,
                priceInfo: priceInfo,
                compact: compact,
              ),
            );
          }).toList(growable: false),
        );
      },
    );
  }

  String _compactPriceInfo(String priceInfo) {
    final studentPrice = RegExp(r'학생\s*([\d,]+원)').firstMatch(priceInfo);
    if (studentPrice != null) {
      return '학생 ${studentPrice.group(1)!}';
    }
    final price = RegExp(r'([\d,]+원)').firstMatch(priceInfo);
    if (price != null) {
      return price.group(1)!;
    }
    return priceInfo;
  }
}

class _MealMenuCard extends StatelessWidget {
  const _MealMenuCard({
    required this.type,
    required this.priceInfo,
    required this.compact,
    this.meal,
  });

  final MealType type;
  final String priceInfo;
  final bool compact;
  final MealMenu? meal;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final palette =
        Theme.of(context).extension<HongikPalette>() ?? HongikPalette.light;
    final mealColor = _mealColor(context, type);
    final hasItems = meal != null && meal!.items.isNotEmpty;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: palette.cardSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.cardOutline),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: mealColor),
            Expanded(
              child: Padding(
                padding: compact
                    ? const EdgeInsets.fromLTRB(14, 12, 12, 12)
                    : const EdgeInsets.fromLTRB(18, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _mealIcon(type),
                          color: mealColor,
                          size: compact ? 17 : 18,
                        ),
                        SizedBox(width: compact ? 6 : 7),
                        Expanded(
                          child: Text(
                            _mealTitle(type, meal?.time),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                        if (priceInfo.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            flex: 0,
                            child: Text(
                              priceInfo,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: palette.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: compact ? 8 : 10),
                    Divider(height: 1, color: palette.cardOutline),
                    SizedBox(height: compact ? 10 : 13),
                    if (hasItems)
                      Wrap(
                        spacing: compact ? 6 : 8,
                        runSpacing: compact ? 7 : 9,
                        children: meal!.items
                            .map((item) {
                              return _MenuChip(label: item, compact: compact);
                            })
                            .toList(growable: false),
                      )
                    else
                      SizedBox(
                        height: 42,
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Text(
                            '${type.label} 정보 없음',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: colorScheme.onSurface.withValues(
                                    alpha: 0.42,
                                  ),
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _mealIcon(MealType type) {
    return switch (type) {
      MealType.breakfast => Icons.wb_twilight_rounded,
      MealType.lunch => Icons.wb_sunny_rounded,
      MealType.dinner => Icons.nightlight_round,
    };
  }

  String _mealTitle(MealType type, String? time) {
    final fallbackTime = switch (type) {
      MealType.breakfast => '8:00~9:00',
      MealType.lunch => '11:30~14:00',
      MealType.dinner => '17:30~18:50',
    };
    final value = time == null || time.isEmpty ? fallbackTime : time;
    return '${type.label} ($value)';
  }
}

class _MenuChip extends StatelessWidget {
  const _MenuChip({required this.label, required this.compact});

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette =
        Theme.of(context).extension<HongikPalette>() ?? HongikPalette.light;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 9 : 11,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: palette.cardSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.cardOutline),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: palette.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

Color _mealColor(BuildContext context, MealType type) {
  final palette =
      Theme.of(context).extension<HongikPalette>() ?? HongikPalette.light;
  return switch (type) {
    MealType.breakfast => palette.warning,
    MealType.lunch => palette.success,
    MealType.dinner => palette.brandBlue,
  };
}
