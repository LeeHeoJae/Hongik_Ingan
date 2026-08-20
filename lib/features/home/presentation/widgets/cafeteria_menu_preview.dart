import 'package:flutter/material.dart';
import 'package:hongik_ingan/core/theme/color.dart';
import 'package:hongik_ingan/features/cafeteria_menu/application/cafeteria_menu_controller.dart';
import 'package:hongik_ingan/features/cafeteria_menu/domain/cafeteria_menu.dart';
import 'package:hongik_ingan/features/home/presentation/widgets/campus_preview_state.dart';

class CafeteriaMenuPreview extends StatelessWidget {
  const CafeteriaMenuPreview({super.key, required this.state});

  final CafeteriaMenuState state;

  @override
  Widget build(BuildContext context) {
    if (state.menus.isEmpty && state.error == null) {
      return const CampusPreviewLoadingSkeleton();
    }

    final selectedMenu = state.selectedMenu;
    if (selectedMenu == null) {
      return CampusPreviewMessage(
        icon: Icons.restaurant_rounded,
        title: '메뉴 정보가 없어요',
        message: state.error ?? '오늘 표시할 메뉴를 아직 불러오지 못했어요.',
      );
    }

    if (selectedMenu.status == MenuDayStatus.networkError ||
        selectedMenu.status == MenuDayStatus.parseFailed) {
      return CampusPreviewMessage(
        icon: Icons.wifi_off_rounded,
        title: '메뉴를 불러오지 못했어요',
        message: selectedMenu.message ?? '잠시 후 다시 시도해 주세요.',
      );
    }

    if (!selectedMenu.hasMenu) {
      return CampusPreviewMessage(
        icon: Icons.no_food_rounded,
        title: selectedMenu.message == null ? '등록된 메뉴가 없어요' : '운영하지 않는 날이에요',
        message: selectedMenu.message ?? '선택한 날짜의 식당 메뉴가 비어 있어요.',
      );
    }

    final cafeteria = state.selectedCafeteria;
    if (cafeteria == null) {
      return const CampusPreviewMessage(
        icon: Icons.storefront_rounded,
        title: '식당 정보가 없어요',
        message: '표시할 식당을 찾지 못했어요.',
      );
    }

    final meals = cafeteria.meals
        .where((meal) => meal.items.isNotEmpty)
        .toList(growable: false);

    if (meals.isEmpty) {
      return const CampusPreviewMessage(
        icon: Icons.no_meals_rounded,
        title: '표시할 메뉴가 없어요',
        message: '현재 식단 항목이 비어 있어요.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PreviewMetadataRow(
          icon: Icons.storefront_rounded,
          text: cafeteria.name,
        ),
        if (cafeteria.priceInfo.isNotEmpty) ...[
          const SizedBox(height: 6),
          _PreviewMetadataRow(
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

class _PreviewMetadataRow extends StatelessWidget {
  const _PreviewMetadataRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final palette =
        Theme.of(context).extension<HongikPalette>() ?? HongikPalette.light;

    return Row(
      children: [
        Icon(icon, size: 16, color: palette.textSecondary),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: palette.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
