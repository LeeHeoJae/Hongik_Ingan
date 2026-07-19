import 'package:flutter/material.dart';
import 'package:hongik_ingan/features/campus/presentation/campus_segmented_selector.dart';
import 'package:hongik_ingan/features/menu/domain/menu.dart';
import 'package:hongik_ingan/features/menu/presentation/menu_display_formatter.dart';

class CafeteriaSelector extends StatelessWidget {
  const CafeteriaSelector({
    super.key,
    required this.cafeterias,
    required this.selectedName,
    required this.onSelected,
    required this.compact,
  });

  final List<CafeteriaMenu> cafeterias;
  final String? selectedName;
  final ValueChanged<String> onSelected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ordered = MenuDisplayFormatter.orderedCafeterias(cafeterias);
    final selected = ordered.firstWhere(
      (cafeteria) => cafeteria.name == selectedName,
      orElse: () => ordered.first,
    );

    return CampusSegmentedSelector<CafeteriaMenu>(
      items: ordered,
      selectedItem: selected,
      labelOf: (cafeteria) =>
          MenuDisplayFormatter.shortCafeteriaName(cafeteria.name),
      onSelected: (cafeteria) => onSelected(cafeteria.name),
      height: compact ? 38 : 43,
      fontSize: compact ? 13 : 14,
    );
  }
}
