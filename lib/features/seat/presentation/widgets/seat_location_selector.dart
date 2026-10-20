import 'package:flutter/material.dart';
import 'package:hongik_ingan/core/presentation/widgets/app_segmented_selector.dart';
import 'package:hongik_ingan/features/seat/domain/seat.dart';

class SeatLocationSelector extends StatelessWidget {
  const SeatLocationSelector({
    super.key,
    required this.selectedLocation,
    required this.onSelected,
  });

  final SeatLocation selectedLocation;
  final ValueChanged<SeatLocation> onSelected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '건물 선택',
      child: AppSegmentedSelector<SeatLocation>(
        items: SeatLocation.values,
        selectedItem: selectedLocation,
        labelOf: (location) => location.label,
        onSelected: onSelected,
        height: 38,
        fontSize: 14,
      ),
    );
  }
}
