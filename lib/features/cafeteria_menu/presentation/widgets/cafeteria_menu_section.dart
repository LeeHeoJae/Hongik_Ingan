import 'package:flutter/material.dart';
import 'package:hongik_ingan/core/theme/color.dart';
import 'package:hongik_ingan/features/cafeteria_menu/domain/cafeteria_menu.dart';
import 'package:hongik_ingan/features/cafeteria_menu/presentation/widgets/meal_choice_controls.dart';

class CafeteriaMenuSection extends StatelessWidget {
  const CafeteriaMenuSection({
    super.key,
    required this.cafeteria,
    this.voteDate,
  });

  final CafeteriaMenu cafeteria;
  final DateTime? voteDate;

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
            final columns = constraints.maxWidth >= 960 * scale
                ? 3
                : !hasChoices && constraints.maxWidth >= 620 * scale
                ? 2
                : 1;
            const gap = 10.0;
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
                      voteDate: cafeteria.isDormitory ? voteDate : null,
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
  const _MealSection({required this.meals, this.voteDate});

  final List<MealMenu> meals;
  final DateTime? voteDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<HongikPalette>() ?? HongikPalette.light;
    final hasChoices = meals.length > 1;
    final sameTime = meals.every((meal) => meal.time == meals.first.time);
    final sharedTime = sameTime ? meals.first.time.trim() : '';
    final title = meals.first.type.label;
    final chooseOne = hasChoices && meals.first.type == MealType.lunch;
    final hasVote =
        voteDate != null &&
        meals.first.type == MealType.lunch &&
        meals.length == 2;
    final (icon, accent) = switch (meals.first.type) {
      MealType.breakfast => (Icons.wb_twilight_rounded, palette.warning),
      MealType.lunch => (Icons.wb_sunny_rounded, palette.success),
      MealType.dinner => (Icons.nightlight_round, palette.brandBlue),
    };

    Widget mealContent(MealMenu meal) {
      return Semantics(
        container: hasChoices,
        label: hasChoices && !hasVote && meal.option == null
            ? '식단 ${meals.indexOf(meal) + 1}'
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!sameTime) ...[
              Text(
                meal.time.trim().isEmpty ? '운영 시간 미제공' : meal.time.trim(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
            ],
            _MealItems(items: meal.items),
          ],
        ),
      );
    }

    Widget header(bool closed) {
      final heading = Semantics(
        header: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: ExcludeSemantics(
                child: Icon(icon, size: 17, color: accent),
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text.rich(
                TextSpan(
                  text: title,
                  children: [
                    if (hasVote && closed)
                      TextSpan(
                        text: ' · 투표 마감',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: palette.textSecondary,
                          fontWeight: FontWeight.normal,
                        ),
                      )
                    else if (chooseOne && !sharedTime.contains('택1'))
                      const TextSpan(text: ' · 택1'),
                  ],
                ),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: palette.brandNavy,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
      final time = Text(
        sharedTime.isEmpty ? '운영 시간 미제공' : sharedTime,
        style: theme.textTheme.bodySmall?.copyWith(
          color: palette.textSecondary,
        ),
      );
      if (!hasVote) {
        return Wrap(
          key: const ValueKey('meal-section-header'),
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 4,
          children: [heading, if (sameTime) time],
        );
      }
      return Row(
        key: const ValueKey('meal-section-header'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: heading),
          IconButton(
            onPressed: () => _showVoteInfo(context),
            tooltip: '학식 투표 안내',
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            padding: EdgeInsets.zero,
            style: IconButton.styleFrom(
              minimumSize: const Size(24, 24),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.standard,
            ),
            icon: Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: palette.textSecondary,
              semanticLabel: '학식 투표 안내',
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (sameTime) time,
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.cardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.cardOutline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!hasVote) ...[header(false), const SizedBox(height: 8)],
          if (hasVote)
            MealChoiceControls(
              date: voteDate!,
              meals: meals,
              itemBuilder: mealContent,
              headerBuilder: header,
            )
          else
            MealOptionsLayout(
              children: [for (final meal in meals) mealContent(meal)],
            ),
        ],
      ),
    );
  }

  Future<void> _showVoteInfo(BuildContext context) {
    return showDialog<void>(
      context: context,
      animationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : null,
      builder: (context) {
        final theme = Theme.of(context);
        final palette = theme.extension<HongikPalette>() ?? HongikPalette.light;
        Widget infoRow(IconData icon, String title, String description) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 21, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color: palette.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
        return AlertDialog(
          constraints: const BoxConstraints(maxWidth: 400),
          title: const Text('학식 투표 안내'),
          content: SizedBox(
            width: 352,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  infoRow(
                    Icons.how_to_vote_outlined,
                    '학번을 사용하는 이유',
                    '학번으로 내 선택을 구분해 투표를 변경하거나 취소할 수 있어요.',
                  ),
                  const SizedBox(height: 18),
                  infoRow(
                    Icons.key_outlined,
                    '투표 기록 처리',
                    '학번은 투표 서버에 전달되며, 투표 기록에는 학번 대신 변환된 식별값이 저장돼요.',
                  ),
                ],
              ),
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('확인'),
            ),
          ],
        );
      },
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
