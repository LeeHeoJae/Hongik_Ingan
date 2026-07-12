import 'package:flutter/material.dart';
import 'package:hongik_ingan/features/campus/presentation/campus_segmented_selector.dart';
import 'package:hongik_ingan/features/seat/domain/seat.dart';

class SeatLocationSelector extends StatelessWidget {
  const SeatLocationSelector({
    super.key,
    required this.selectedLocation,
    required this.onSelected,
    required this.compact,
  });

  final SeatLocation selectedLocation;
  final ValueChanged<SeatLocation> onSelected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return CampusSegmentedSelector<SeatLocation>(
      items: SeatLocation.values,
      selectedItem: selectedLocation,
      labelOf: (location) => location.label,
      onSelected: onSelected,
      height: compact ? 38 : 46,
      fontSize: compact ? 14 : 15,
    );
  }
}
