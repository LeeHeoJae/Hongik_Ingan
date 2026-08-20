import 'package:flutter/material.dart';
import 'package:hongik_ingan/core/presentation/widgets/app_segmented_selector.dart';
import 'package:hongik_ingan/features/cafeteria_menu/domain/cafeteria_menu.dart';
import 'package:hongik_ingan/features/cafeteria_menu/presentation/cafeteria_menu_display_formatter.dart';

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
    final ordered = CafeteriaMenuDisplayFormatter.orderedCafeterias(cafeterias);
    final selected = ordered.firstWhere(
      (cafeteria) => cafeteria.name == selectedName,
      orElse: () => ordered.first,
    );

    return AppSegmentedSelector<CafeteriaMenu>(
      items: ordered,
      selectedItem: selected,
      labelOf: (cafeteria) =>
          CafeteriaMenuDisplayFormatter.shortCafeteriaName(cafeteria.name),
      onSelected: (cafeteria) => onSelected(cafeteria.name),
      height: compact ? 38 : 43,
      fontSize: compact ? 13 : 14,
    );
  }
}
