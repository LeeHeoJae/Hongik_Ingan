import 'package:flutter/material.dart';
import 'package:hongik_ingan/core/presentation/widgets/app_segmented_selector.dart';
import 'package:hongik_ingan/features/cafeteria_menu/domain/cafeteria_menu.dart';

class CafeteriaMenuDateSelector extends StatelessWidget {
  const CafeteriaMenuDateSelector({
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

    return AppSegmentedSelector<DateTime>(
      items: dates,
      selectedItem: selected,
      labelOf: MenuDateRange.weekdayLabel,
      onSelected: onSelected,
      height: compact ? 36 : 42,
      fontSize: compact ? 14 : 15,
    );
  }
}
