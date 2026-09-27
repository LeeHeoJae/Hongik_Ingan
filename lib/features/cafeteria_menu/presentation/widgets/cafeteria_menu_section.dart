import 'package:flutter/material.dart';
import 'package:hongik_ingan/core/theme/color.dart';
import 'package:hongik_ingan/features/cafeteria_menu/domain/cafeteria_menu.dart';
import 'package:hongik_ingan/features/cafeteria_menu/presentation/cafeteria_menu_display_formatter.dart';

class CafeteriaMenuSection extends StatelessWidget {
  const CafeteriaMenuSection({
    super.key,
    required this.cafeteria,
    required this.compact,
    required this.useAdaptiveGrid,
  });

  final CafeteriaMenu cafeteria;
  final bool compact;
  final bool useAdaptiveGrid;

  @override
  Widget build(BuildContext context) {
    final meals = cafeteria.meals
        .where((meal) => meal.items.isNotEmpty)
        .toList(growable: false);
    final priceInfo = CafeteriaMenuDisplayFormatter.compactPriceInfo(
      cafeteria.priceInfo,
    );
    final lunchChoices = meals
        .where((meal) => meal.type == MealType.lunch)
        .toList(growable: false);

    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
        if (lunchChoices.length > 1) {
          final firstLunchIndex = meals.indexWhere(
            (meal) => meal.type == MealType.lunch,
          );
          return Column(
            children: [
              for (var index = 0; index < meals.length; index++)
                if (meals[index].type != MealType.lunch ||
                    index == firstLunchIndex)
                  Padding(
                    padding: EdgeInsets.only(bottom: compact ? 10 : 14),
                    child: _MealMenuCard(
                      type: meals[index].type,
                      meal: meals[index],
                      choices: meals[index].type == MealType.lunch
                          ? lunchChoices
                          : null,
                      priceInfo: priceInfo,
                      compact: compact,
                    ),
                  ),
            ],
          );
        }
        final canUseGrid =
            useAdaptiveGrid &&
            constraints.maxWidth >= 560 * scale &&
            meals.length > 1;
        if (!canUseGrid) {
          return Column(
            children: meals
                .map((meal) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: compact ? 10 : 14),
                    child: _MealMenuCard(
                      type: meal.type,
                      meal: meal,
                      priceInfo: priceInfo,
                      compact: compact,
                    ),
                  );
                })
                .toList(growable: false),
          );
        }

        final spacing = compact ? 10.0 : 12.0;
        final columns = constraints.maxWidth >= 840 * scale && meals.length >= 3
            ? 3
            : 2;
        final itemWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: meals
              .map((meal) {
                return SizedBox(
                  width: itemWidth,
                  child: _MealMenuCard(
                    type: meal.type,
                    meal: meal,
                    priceInfo: priceInfo,
                    compact: compact,
                  ),
                );
              })
              .toList(growable: false),
        );
      },
    );
  }
}

class _MealMenuCard extends StatelessWidget {
  const _MealMenuCard({
    required this.type,
    required this.priceInfo,
    required this.compact,
    this.meal,
    this.choices,
  });

  final MealType type;
  final String priceInfo;
  final bool compact;
  final MealMenu? meal;
  final List<MealMenu>? choices;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final palette =
        Theme.of(context).extension<HongikPalette>() ?? HongikPalette.light;
    final mealColor = _mealColor(context, type);
    final hasItems = meal != null && meal!.items.isNotEmpty;
    final title = CafeteriaMenuDisplayFormatter.mealTitle(type, meal?.time);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: palette.cardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.cardOutline),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: SizedBox(width: 4, child: ColoredBox(color: mealColor)),
          ),
          Padding(
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
                        '$title${choices != null && !title.contains('택1') ? ' · 택1' : ''}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
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
                if (choices != null)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final scale =
                          MediaQuery.textScalerOf(context).scale(14) / 14;
                      final spacing = compact ? 8.0 : 10.0;
                      final sideBySide = constraints.maxWidth >= 540 * scale;
                      final choiceWidth = sideBySide
                          ? (constraints.maxWidth - spacing) / 2
                          : constraints.maxWidth;
                      return Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        children: [
                          for (final choice in choices!)
                            SizedBox(
                              width: choiceWidth,
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: palette.cardSurfaceMuted,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: palette.cardOutline,
                                  ),
                                ),
                                child: _MealItems(items: choice.items),
                              ),
                            ),
                        ],
                      );
                    },
                  )
                else if (hasItems)
                  _MealItems(items: meal!.items)
                else
                  SizedBox(
                    height: 42,
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Text(
                        '${type.label} 정보 없음',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.42),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
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
}

class _MealItems extends StatelessWidget {
  const _MealItems({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final twoColumns = constraints.maxWidth >= 220 * scale;
        const spacing = 8.0;
        final itemWidth = twoColumns
            ? (constraints.maxWidth - spacing) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: spacing,
          runSpacing: 3,
          children: [
            for (final item in items)
              SizedBox(
                width: itemWidth,
                child: Text(
                  item,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
          ],
        );
      },
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
