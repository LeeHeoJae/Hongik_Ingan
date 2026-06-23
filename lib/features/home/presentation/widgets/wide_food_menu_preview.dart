import 'package:flutter/material.dart';
import 'package:hongik_ingan/core/theme/color.dart';
import 'package:hongik_ingan/features/food_menu/application/food_menu_controller.dart';
import 'package:hongik_ingan/features/food_menu/domain/food_menu.dart';
import 'package:hongik_ingan/features/home/presentation/widgets/wide_campus_info_card.dart';

class WideFoodMenuPreview extends StatelessWidget {
  const WideFoodMenuPreview({super.key, required this.state});

  final FoodMenuState state;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading && state.menus.isEmpty) {
      return const WidePreviewLoading();
    }

    final selectedMenu = state.selectedMenu;
    if (selectedMenu == null) {
      return WidePreviewMessage(
        icon: Icons.restaurant_rounded,
        title: '메뉴 정보가 없습니다',
        message: state.error ?? '오늘 표시할 메뉴를 아직 불러오지 못했습니다.',
      );
    }

    if (selectedMenu.status == FoodMenuDayStatus.networkError ||
        selectedMenu.status == FoodMenuDayStatus.parseFailed) {
      return WidePreviewMessage(
        icon: Icons.wifi_off_rounded,
        title: '메뉴를 불러오지 못했습니다',
        message: selectedMenu.message ?? '잠시 후 다시 시도해주세요.',
      );
    }

    if (!selectedMenu.hasMenu) {
      return const WidePreviewMessage(
        icon: Icons.no_food_rounded,
        title: '등록된 메뉴가 없습니다',
        message: '선택한 날짜의 식당 메뉴가 비어 있습니다.',
      );
    }

    final cafeteria = state.selectedCafeteria;
    if (cafeteria == null) {
      return const WidePreviewMessage(
        icon: Icons.storefront_rounded,
        title: '식당 정보가 없습니다',
        message: '표시할 식당을 찾지 못했습니다.',
      );
    }

    final meals = cafeteria.meals
        .where((meal) => meal.items.isNotEmpty)
        .toList(growable: false);

    if (meals.isEmpty) {
      return const WidePreviewMessage(
        icon: Icons.no_meals_rounded,
        title: '표시할 메뉴가 없습니다',
        message: '현재 식단 항목이 비어 있습니다.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WideMetaLine(icon: Icons.storefront_rounded, text: cafeteria.name),
        if (cafeteria.priceInfo.isNotEmpty) ...[
          const SizedBox(height: 6),
          WideMetaLine(
            icon: Icons.payments_outlined,
            text: cafeteria.priceInfo,
          ),
        ],
        const SizedBox(height: 12),
        Expanded(child: _MealPreviewList(meals: meals)),
      ],
    );
  }
}

class _MealPreviewList extends StatefulWidget {
  const _MealPreviewList({required this.meals});

  final List<MealMenu> meals;

  @override
  State<_MealPreviewList> createState() => _MealPreviewListState();
}

class _MealPreviewListState extends State<_MealPreviewList> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showScrollAffordance = widget.meals.length > 2;

    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: showScrollAffordance,
      trackVisibility: showScrollAffordance,
      interactive: true,
      radius: const Radius.circular(999),
      child: ListView.separated(
        controller: _scrollController,
        padding: EdgeInsets.only(right: showScrollAffordance ? 10 : 0),
        itemCount: widget.meals.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          return _MealPreviewRow(meal: widget.meals[index]);
        },
      ),
    );
  }
}

class _MealPreviewRow extends StatelessWidget {
  const _MealPreviewRow({required this.meal});

  final MealMenu meal;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final palette =
        Theme.of(context).extension<HongikPalette>() ?? HongikPalette.light;
    final mealTypeColor = _mealTypeColor(context, meal.type);
    final preview = meal.items.take(4).join(', ');

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 58),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: palette.cardSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: palette.cardOutline),
        ),
        child: Center(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 58),
                child: Text(
                  meal.type.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: mealTypeColor,
                    fontWeight: FontWeight.w900,
                    height: 1.25,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Tooltip(
                  message: preview,
                  child: Text(
                    preview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                      height: 1.28,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Color _mealTypeColor(BuildContext context, MealType type) {
  final palette =
      Theme.of(context).extension<HongikPalette>() ?? HongikPalette.light;
  return switch (type) {
    MealType.breakfast => palette.warning,
    MealType.lunch => palette.success,
    MealType.dinner => palette.brandBlue,
  };
}
