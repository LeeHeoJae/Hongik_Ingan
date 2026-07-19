import 'package:flutter/material.dart';
import 'package:hongik_ingan/core/theme/color.dart';
import 'package:hongik_ingan/features/menu/domain/menu.dart';
import 'package:hongik_ingan/features/menu/presentation/menu_display_formatter.dart';

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
    final meals = {
      for (final meal in cafeteria.meals)
        if (meal.items.isNotEmpty) meal.type: meal,
    };
    final priceInfo = MenuDisplayFormatter.compactPriceInfo(
      cafeteria.priceInfo,
    );
    final entries = meals.entries.toList(growable: false);

    return LayoutBuilder(
      builder: (context, constraints) {
        final canUseGrid =
            useAdaptiveGrid &&
            constraints.maxWidth >= 520 &&
            entries.length > 1;
        if (!canUseGrid) {
          return Column(
            children: entries
                .map((entry) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: compact ? 10 : 14),
                    child: _MealMenuCard(
                      type: entry.key,
                      meal: entry.value,
                      priceInfo: priceInfo,
                      compact: compact,
                    ),
                  );
                })
                .toList(growable: false),
          );
        }

        final spacing = compact ? 10.0 : 12.0;
        final itemWidth = (constraints.maxWidth - spacing) / 2;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: entries
              .map((entry) {
                return SizedBox(
                  width: itemWidth,
                  child: _MealMenuCard(
                    type: entry.key,
                    meal: entry.value,
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
                            MenuDisplayFormatter.mealTitle(type, meal?.time),
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
