import 'package:flutter/material.dart';

import 'package:hongik_ingan/core/theme/color.dart';

class AppSegmentedSelector<T> extends StatelessWidget {
  const AppSegmentedSelector({
    super.key,
    required this.items,
    required this.selectedItem,
    required this.labelOf,
    required this.onSelected,
    this.height = 43,
    this.fontSize = 14,
  }) : assert(items.length > 0);

  final List<T> items;
  final T selectedItem;
  final String Function(T item) labelOf;
  final ValueChanged<T> onSelected;
  final double height;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    final selectionColor = isDark
        ? colorScheme.primaryContainer
        : colorScheme.primary;
    final palette =
        Theme.of(context).extension<HongikPalette>() ?? HongikPalette.light;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: palette.cardSurfaceMuted,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.cardOutline),
      ),
      child: Row(
        children: items
            .map((item) {
              final isSelected = item == selectedItem;

              return Expanded(
                child: Semantics(
                  button: true,
                  selected: isSelected,
                  label: labelOf(item),
                  child: InkWell(
                    onTap: () => onSelected(item),
                    borderRadius: BorderRadius.circular(8),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 44),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: AnimatedContainer(
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          constraints: BoxConstraints(minHeight: height - 8),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            // Preserve the hue while fading; transparent black
                            // would darken the intermediate selection colors.
                            color: selectionColor.withValues(
                              alpha: isSelected ? 1 : 0,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: isDark
                                ? null
                                : [
                                    BoxShadow(
                                      color: colorScheme.primary.withValues(
                                        alpha: isSelected ? 0.20 : 0,
                                      ),
                                      blurRadius: 18,
                                      spreadRadius: 0.4,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                          ),
                          child: Text(
                            labelOf(item),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isSelected
                                  ? isDark
                                        ? colorScheme.onPrimaryContainer
                                        : colorScheme.onPrimary
                                  : palette.textSecondary,
                              fontSize: fontSize,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }
}
