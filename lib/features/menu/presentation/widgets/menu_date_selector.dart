import 'package:flutter/material.dart';
import 'package:hongik_ingan/features/campus/presentation/campus_segmented_selector.dart';
import 'package:hongik_ingan/features/menu/domain/menu.dart';

class MenuDateSelector extends StatelessWidget {
  const MenuDateSelector({
    super.key,
    required this.dates,
    required this.selectedDate,
    required this.onSelected,
    required this.compact,
  });

  final List<DateTime> dates;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final selected = dates.firstWhere(
      (date) => MenuDateRange.isSameDate(date, selectedDate),
      orElse: () => dates.first,
    );

    return CampusSegmentedSelector<DateTime>(
      items: dates,
      selectedItem: selected,
      labelOf: MenuDateRange.weekdayLabel,
      onSelected: onSelected,
      height: compact ? 36 : 42,
      fontSize: compact ? 14 : 15,
    );
  }
}
