import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:hongik_ingan/core/theme/color.dart';
import 'package:hongik_ingan/features/campus/presentation/campus_segmented_selector.dart';
import 'package:hongik_ingan/features/campus/presentation/campus_sheet_scaffold.dart';
import 'package:hongik_ingan/features/food_menu/application/food_menu_controller.dart';
import 'package:hongik_ingan/features/food_menu/domain/food_menu.dart';

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
    final colorScheme = Theme.of(context).colorScheme;
    final palette =
        Theme.of(context).extension<HongikPalette>() ?? HongikPalette.light;

    return FractionallySizedBox(
      heightFactor: 0.9,
      alignment: Alignment.bottomCenter,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 660),
          child: Material(
            color: colorScheme.surface,
            elevation: 8,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            clipBehavior: Clip.antiAlias,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: colorScheme.onSurface.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    _FoodSheetHeader(
                      selectedDate: state.selectedDate,
                      isRefreshing: state.isLoading && state.menus.isNotEmpty,
                      accentColor: palette.brandNavy,
                      onRefresh: controller.refresh,
                      onClose: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(height: 14),
                    _FoodDateSelector(
                      dates: state.dates,
                      selectedDate: state.selectedDate,
                      onSelected: controller.selectDate,
                    ),
                    if (_shouldShowCafeteriaSelector(state)) ...[
                      const SizedBox(height: 14),
                      _CafeteriaSelector(
                        cafeterias: state.selectedMenu!.cafeterias,
                        selectedName: state.selectedCafeteria?.name,
                        onSelected: controller.selectCafeteria,
                      ),
                    ],
                    const SizedBox(height: 16),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: _buildContent(context, state, controller),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
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
      children: [_CafeteriaMenuSection(cafeteria: cafeteria)],
    );
  }
}

class _FoodSheetHeader extends StatelessWidget {
  const _FoodSheetHeader({
    required this.selectedDate,
    required this.isRefreshing,
    required this.accentColor,
    required this.onRefresh,
    required this.onClose,
  });

  final DateTime selectedDate;
  final bool isRefreshing;
  final Color accentColor;
  final VoidCallback onRefresh;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Container(
          width: 42,
          height: 40,
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(
            Icons.restaurant_menu_rounded,
            color: accentColor,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '오늘의 학식 정보',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${FoodMenuDateRange.monthDayLabel(selectedDate)} (${FoodMenuDateRange.weekdayLabel(selectedDate)}요일)',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.56),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: '새로고침',
          onPressed: isRefreshing ? null : onRefresh,
          style: IconButton.styleFrom(
            foregroundColor: colorScheme.onSurface.withValues(alpha: 0.72),
          ),
          icon: isRefreshing
              ? const SizedBox(
                  width: 19,
                  height: 19,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                )
              : const Icon(Icons.refresh_rounded),
        ),
        IconButton(
          tooltip: '닫기',
          onPressed: onClose,
          style: IconButton.styleFrom(
            foregroundColor: colorScheme.onSurface.withValues(alpha: 0.72),
          ),
          icon: const Icon(Icons.close_rounded),
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
  });

  final List<DateTime> dates;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelected;

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
      height: 42,
      fontSize: 15,
    );
  }
}

class _CafeteriaSelector extends StatelessWidget {
  const _CafeteriaSelector({
    required this.cafeterias,
    required this.selectedName,
    required this.onSelected,
  });

  final List<CafeteriaMenu> cafeterias;
  final String? selectedName;
  final ValueChanged<String> onSelected;

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
  const _CafeteriaMenuSection({required this.cafeteria});

  final CafeteriaMenu cafeteria;

  @override
  Widget build(BuildContext context) {
    final meals = {
      for (final meal in cafeteria.meals)
        if (meal.items.isNotEmpty) meal.type: meal,
    };
    final priceInfo = _compactPriceInfo(cafeteria.priceInfo);

    return Column(
      children: meals.keys
          .map((type) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _MealMenuCard(
                type: type,
                meal: meals[type],
                priceInfo: priceInfo,
              ),
            );
          })
          .toList(growable: false),
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
  const _MealMenuCard({required this.type, required this.priceInfo, this.meal});

  final MealType type;
  final String priceInfo;
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
        color: palette.cardSurfaceMuted,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.cardOutline),
        boxShadow: [
          BoxShadow(
            color: palette.cardShadow.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: mealColor),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(_mealIcon(type), color: mealColor, size: 18),
                        const SizedBox(width: 7),
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
                          Text(
                            priceInfo,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: palette.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    Divider(height: 1, color: palette.cardOutline),
                    const SizedBox(height: 13),
                    if (hasItems)
                      Wrap(
                        spacing: 8,
                        runSpacing: 9,
                        children: meal!.items
                            .map((item) => _MenuChip(label: item))
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
  const _MenuChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette =
        Theme.of(context).extension<HongikPalette>() ?? HongikPalette.light;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
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
