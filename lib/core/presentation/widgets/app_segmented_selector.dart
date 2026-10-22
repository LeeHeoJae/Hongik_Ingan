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
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(
          end: items
              .indexOf(selectedItem)
              .clamp(0, items.length - 1)
              .toDouble(),
        ),
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        builder: (context, position, child) {
          final foreground = _legibleForeground(
            selectionColor,
            quiet || isDark
                ? colorScheme.onPrimaryContainer
                : colorScheme.onPrimary,
          );
          Widget label(T item, Color color, String layer) {
            final style = TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
            );
            return Container(
              constraints: BoxConstraints(minHeight: height < 44 ? 44 : height),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: layer == 'selected'
                  ? RichText(
                      key: ValueKey(
                        'segmented-selected-${items.indexOf(item)}',
                      ),
                      textScaler: MediaQuery.textScalerOf(context),
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        text: labelOf(item),
                        style: DefaultTextStyle.of(context).style.merge(style),
                      ),
                    )
                  : ExcludeSemantics(
                      child: Text(
                        labelOf(item),
                        key: ValueKey(
                          'segmented-$layer-${items.indexOf(item)}',
                        ),
                        textAlign: TextAlign.center,
                        style: style,
                      ),
                    ),
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final slotWidth = constraints.maxWidth / items.length;
              final visualPosition =
                  Directionality.of(context) == TextDirection.rtl
                  ? items.length - 1 - position
                  : position;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: slotWidth * visualPosition,
                    top: 4,
                    bottom: 4,
                    width: slotWidth,
                    child: DecoratedBox(
                      key: const ValueKey('app-segmented-selection'),
                      decoration: BoxDecoration(
                        color: selectionColor,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: quiet || isDark
                            ? null
                            : [
                                BoxShadow(
                                  color: colorScheme.primary.withValues(
                                    alpha: 0.20,
                                  ),
                                  blurRadius: 18,
                                  spreadRadius: 0.4,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (final item in items)
                        Expanded(
                          child: Semantics(
                            button: true,
                            selected: item == selectedItem,
                            label: labelOf(item),
                            child: InkWell(
                              enableFeedback: false,
                              onTap: () {
                                onSelected(item);
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: label(
                                item,
                                _legibleForeground(
                                  palette.cardSurfaceMuted,
                                  palette.textSecondary,
                                ),
                                'base',
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  // Two clipped text layers keep glyphs readable on both sides
                  // of the moving, opaque selection surface.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ExcludeSemantics(
                        child: ClipRect(
                          clipper: _SelectionClipper(
                            slotWidth * visualPosition,
                            slotWidth,
                          ),
                          child: Row(
                            children: [
                              for (final item in items)
                                Expanded(
                                  child: label(item, foreground, 'selected'),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _SelectionClipper extends CustomClipper<Rect> {
  const _SelectionClipper(this.left, this.width);
  final double left;
  final double width;

  @override
  Rect getClip(Size size) => Rect.fromLTWH(left, 4, width, size.height - 8);

  @override
  bool shouldReclip(_SelectionClipper oldClipper) =>
      left != oldClipper.left || width != oldClipper.width;
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
