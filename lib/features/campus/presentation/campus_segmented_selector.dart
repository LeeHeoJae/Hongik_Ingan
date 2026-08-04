import 'package:flutter/material.dart';

import 'package:hongik_ingan/core/theme/color.dart';

class CampusSegmentedSelector<T> extends StatelessWidget {
  const CampusSegmentedSelector({
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
    final palette =
        Theme.of(context).extension<HongikPalette>() ?? HongikPalette.light;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: palette.cardSurfaceMuted,
        borderRadius: BorderRadius.circular(16),
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
                    borderRadius: BorderRadius.circular(13),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      height: height,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colorScheme.primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(13),
                        boxShadow:
                            isSelected &&
                                colorScheme.brightness != Brightness.dark
                            ? [
                                BoxShadow(
                                  color: colorScheme.primary.withValues(
                                    alpha:
                                        colorScheme.brightness ==
                                            Brightness.dark
                                        ? 0.08
                                        : 0.20,
                                  ),
                                  blurRadius:
                                      colorScheme.brightness == Brightness.dark
                                      ? 11
                                      : 18,
                                  spreadRadius:
                                      colorScheme.brightness == Brightness.dark
                                      ? 0
                                      : 0.4,
                                  offset: const Offset(0, 5),
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        labelOf(item),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isSelected
                              ? colorScheme.onPrimary
                              : palette.textSecondary,
                          fontSize: fontSize,
                          fontWeight: isSelected
                              ? FontWeight.w900
                              : FontWeight.w800,
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
