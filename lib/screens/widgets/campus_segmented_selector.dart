import 'package:flutter/material.dart';

import '../../core/theme/color.dart';

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
                          ? palette.brandNavy
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(13),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: palette.brandNavy.withValues(
                                  alpha: 0.20,
                                ),
                                blurRadius: 18,
                                spreadRadius: 0.4,
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
                            ? AppColor.hkWhite
                            : palette.textSecondary,
                        fontSize: fontSize,
                        fontWeight: isSelected
                            ? FontWeight.w900
                            : FontWeight.w800,
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
