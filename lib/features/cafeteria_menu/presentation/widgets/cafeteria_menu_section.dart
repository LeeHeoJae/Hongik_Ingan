import 'package:flutter/material.dart';
import 'package:hongik_ingan/core/theme/color.dart';
import 'package:hongik_ingan/features/cafeteria_menu/domain/cafeteria_menu.dart';

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
    final palette =
        Theme.of(context).extension<HongikPalette>() ?? HongikPalette.light;
    final groups = [
      for (final type in MealType.values)
        cafeteria.meals
            .where((meal) => meal.type == type && meal.items.isNotEmpty)
            .toList(growable: false),
    ].where((meals) => meals.isNotEmpty).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (cafeteria.priceInfo.trim().isNotEmpty) ...[
          Text(
            cafeteria.priceInfo.trim(),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: palette.textSecondary),
          ),
          const SizedBox(height: 8),
        ],
        LayoutBuilder(
          builder: (context, constraints) {
            final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
            final hasChoices = groups.any((meals) => meals.length > 1);
            final columns = !useAdaptiveGrid
                ? 1
                : constraints.maxWidth >= 960 * scale
                ? 3
                : !hasChoices && constraints.maxWidth >= 620 * scale
                ? 2
                : 1;
            final gap = compact ? 10.0 : 12.0;
            final columnWidth =
                (constraints.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final meals in groups)
                  SizedBox(
                    width: columns == 3 && meals.length > 1
                        ? columnWidth * 2 + gap
                        : columnWidth,
                    child: _MealSection(
                      meals: meals,
                      compact: compact,
                      useAdaptiveGrid: useAdaptiveGrid,
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _MealSection extends StatelessWidget {
  const _MealSection({
    required this.meals,
    required this.compact,
    required this.useAdaptiveGrid,
  });

  final List<MealMenu> meals;
  final bool compact;
  final bool useAdaptiveGrid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<HongikPalette>() ?? HongikPalette.light;
    final hasChoices = meals.length > 1;
    final sameTime = meals.every((meal) => meal.time == meals.first.time);
    final sharedTime = sameTime ? meals.first.time.trim() : '';
    final title = meals.first.type.label;
    final chooseOne = hasChoices && meals.first.type == MealType.lunch;
    final (icon, accent) = switch (meals.first.type) {
      MealType.breakfast => (Icons.wb_twilight_rounded, palette.warning),
      MealType.lunch => (Icons.wb_sunny_rounded, palette.success),
      MealType.dinner => (Icons.nightlight_round, palette.brandBlue),
    };

    Widget mealContent(int index) {
      return Semantics(
        container: hasChoices,
        label: hasChoices ? '식단 ${index + 1}' : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!sameTime) ...[
              Text(
                meals[index].time.trim().isEmpty
                    ? '운영 시간 미제공'
                    : meals[index].time.trim(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
            ],
            _MealItems(items: meals[index].items),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: BoxDecoration(
        color: palette.cardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.cardOutline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 4,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ExcludeSemantics(
                      child: Icon(icon, size: 17, color: accent),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$title${chooseOne && !sharedTime.contains('택1') ? ' · 택1' : ''}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: palette.brandNavy,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                if (sameTime)
                  Text(
                    sharedTime.isEmpty ? '운영 시간 미제공' : sharedTime,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
              final sideBySide =
                  useAdaptiveGrid &&
                  meals.length == 2 &&
                  constraints.maxWidth >= 600 * scale;
              if (sideBySide) {
                return Stack(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: mealContent(0)),
                        const SizedBox(width: 25),
                        Expanded(child: mealContent(1)),
                      ],
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Center(
                          child: Container(
                            width: 1,
                            color: palette.cardOutline,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var index = 0; index < meals.length; index++) ...[
                    if (index > 0)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Divider(height: 1, color: palette.cardOutline),
                      ),
                    mealContent(index),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MealItems extends StatelessWidget {
  const _MealItems({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    final textScaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns =
            items.length > 1 &&
            constraints.maxWidth >= 280 * textScaler.scale(14) / 14;
        const spacing = 12.0;
        final columnWidth = (constraints.maxWidth - spacing) / 2;

        double itemWidth(String item) {
          if (!twoColumns) return constraints.maxWidth;
          final painter = TextPainter(
            text: TextSpan(text: item, style: style),
            textDirection: Directionality.of(context),
            textScaler: textScaler,
            locale: Localizations.maybeLocaleOf(context),
            maxLines: 2,
          )..layout(maxWidth: columnWidth);
          final needsFullWidth = painter.didExceedMaxLines;
          painter.dispose();
          return needsFullWidth ? constraints.maxWidth : columnWidth;
        }

        return Wrap(
          spacing: spacing,
          runSpacing: 3,
          children: [
            for (final item in items)
              SizedBox(
                width: itemWidth(item),
                child: Text(item, style: style),
              ),
          ],
        );
      },
    );
  }
}
