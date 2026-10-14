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
    this.quiet = false,
  }) : assert(items.length > 0);

  final List<T> items;
  final T selectedItem;
  final String Function(T item) labelOf;
  final ValueChanged<T> onSelected;
  final double height;
  final double fontSize;
  final bool quiet;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    final selectionColor = quiet || isDark
        ? colorScheme.primaryContainer
        : colorScheme.primary;
    final palette =
        Theme.of(context).extension<HongikPalette>() ?? HongikPalette.light;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: palette.cardSurfaceMuted,
        borderRadius: BorderRadius.circular(10),
        border: quiet ? null : Border.all(color: palette.cardOutline),
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
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(end: isSelected ? 1 : 0),
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          builder: (context, progress, child) => Container(
                            constraints: BoxConstraints(minHeight: height - 8),
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              // Preserve the hue while fading; transparent black
                              // would darken the intermediate selection colors.
                              color: selectionColor.withValues(alpha: progress),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: quiet || isDark
                                  ? null
                                  : [
                                      BoxShadow(
                                        color: colorScheme.primary.withValues(
                                          alpha: progress * 0.20,
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
                                color: _legibleForeground(
                                  Color.alphaBlend(
                                    selectionColor.withValues(alpha: progress),
                                    palette.cardSurfaceMuted,
                                  ),
                                  progress < 0.5
                                      ? palette.textSecondary
                                      : quiet || isDark
                                      ? colorScheme.onPrimaryContainer
                                      : colorScheme.onPrimary,
                                ),
                                fontSize: fontSize,
                                fontWeight: FontWeight.w600,
                              ),
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

Color _legibleForeground(Color background, Color preferred) {
  double contrast(Color foreground) {
    final first = foreground.computeLuminance();
    final second = background.computeLuminance();
    return first > second
        ? (first + 0.05) / (second + 0.05)
        : (second + 0.05) / (first + 0.05);
  }

  if (contrast(preferred) >= 4.5) return preferred;
  // The neutral palette keeps intermediate fills readable in either theme.
  return contrast(AppColor.hkBlack) > contrast(AppColor.hkWhite)
      ? AppColor.hkBlack
      : AppColor.hkWhite;
}
