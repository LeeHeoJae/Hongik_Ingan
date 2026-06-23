import 'package:flutter/material.dart';
import 'package:hongik_ingan/core/theme/color.dart';
import 'package:hongik_ingan/features/campus/presentation/campus_segmented_selector.dart';
import 'package:hongik_ingan/features/home/presentation/widgets/wide_campus_info_card.dart';
import 'package:hongik_ingan/features/study_room/application/study_room_controller.dart';
import 'package:hongik_ingan/features/study_room/domain/study_room.dart';

class WideStudyRoomPreview extends StatelessWidget {
  const WideStudyRoomPreview({
    super.key,
    required this.state,
    required this.onLocationSelected,
  });

  final StudyRoomState state;
  final ValueChanged<StudyRoomLocation> onLocationSelected;

  @override
  Widget build(BuildContext context) {
    final status = state.status;
    final summary = status?.summary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StudyRoomLocationTabs(
          selectedLocation: state.selectedLocation,
          onSelected: onLocationSelected,
        ),
        const SizedBox(height: 12),
        if (state.isLoading && status == null)
          const Expanded(child: WidePreviewLoading())
        else if (state.error != null && status == null)
          Expanded(
            child: WidePreviewMessage(
              icon: Icons.wifi_off_rounded,
              title: '좌석 현황을 불러오지 못했습니다',
              message: state.error!,
            ),
          )
        else if (status == null || summary == null)
          const Expanded(
            child: WidePreviewMessage(
              icon: Icons.event_seat_outlined,
              title: '좌석 정보가 없습니다',
              message: '표시할 열람실 좌석 정보가 없습니다.',
            ),
          )
        else
          Expanded(child: _StudyRoomSnapshot(status: status)),
      ],
    );
  }
}

class _StudyRoomLocationTabs extends StatelessWidget {
  const _StudyRoomLocationTabs({
    required this.selectedLocation,
    required this.onSelected,
  });

  final StudyRoomLocation selectedLocation;
  final ValueChanged<StudyRoomLocation> onSelected;

  @override
  Widget build(BuildContext context) {
    return CampusSegmentedSelector<StudyRoomLocation>(
      items: StudyRoomLocation.values,
      selectedItem: selectedLocation,
      labelOf: (location) => location.label,
      onSelected: onSelected,
      height: 44,
    );
  }
}

class _StudyRoomSnapshot extends StatelessWidget {
  const _StudyRoomSnapshot({required this.status});

  final StudyRoomStatus status;

  @override
  Widget build(BuildContext context) {
    final rooms = status.rooms;

    if (rooms.isEmpty) {
      return const WidePreviewMessage(
        icon: Icons.event_seat_outlined,
        title: '세부 좌석 정보가 없습니다',
        message: '선택한 열람실의 세부 좌석 목록이 비어 있습니다.',
      );
    }

    return _StudyRoomGrid(rooms: rooms);
  }
}

class _StudyRoomGrid extends StatelessWidget {
  const _StudyRoomGrid({required this.rooms});

  static const double _rowHeight = 70;
  static const double _rowSpacing = 10;
  static const double _columnSpacing = 10;
  static const int _crossAxisCount = 2;
  static const int _maxCardCount = 4;

  final List<StudyRoomSeat> rooms;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxHeight = constraints.maxHeight;

        final canShowTwoRows = maxHeight >= (_rowHeight * 2 + _rowSpacing);
        final canShowOneRow = maxHeight >= _rowHeight;

        final visibleRowCount = canShowTwoRows
            ? 2
            : canShowOneRow
            ? 1
            : 0;

        if (visibleRowCount == 0) {
          return const SizedBox.shrink();
        }

        final visibleCardCount = (visibleRowCount * _crossAxisCount).clamp(
          0,
          _maxCardCount,
        );

        final visibleRooms = rooms.take(visibleCardCount).toList();

        final rows = <List<StudyRoomSeat>>[];

        for (var i = 0; i < visibleRooms.length; i += _crossAxisCount) {
          rows.add(visibleRooms.skip(i).take(_crossAxisCount).toList());
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) ...[
              if (rowIndex > 0) const SizedBox(height: _rowSpacing),
              SizedBox(
                height: _rowHeight,
                child: Row(
                  children: [
                    for (
                      var columnIndex = 0;
                      columnIndex < _crossAxisCount;
                      columnIndex++
                    ) ...[
                      if (columnIndex > 0)
                        const SizedBox(width: _columnSpacing),
                      Expanded(
                        child: columnIndex < rows[rowIndex].length
                            ? _StudyRoomCard(seat: rows[rowIndex][columnIndex])
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _StudyRoomCard extends StatelessWidget {
  const _StudyRoomCard({required this.seat});

  final StudyRoomSeat seat;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final palette =
        Theme.of(context).extension<HongikPalette>() ?? HongikPalette.light;
    final usageColor = _usageColor(context, seat.usageRate);
    final usageValue = (seat.usageRate / 100).clamp(0.0, 1.0).toDouble();

    return Container(
      decoration: BoxDecoration(
        color: palette.cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.cardOutline),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(9, 6, 9, 6),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: Tooltip(
                message: seat.name,
                child: Text(
                  seat.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                  ),
                ),
              ),
            ),

            Positioned(
              left: 0,
              right: 0,
              top: 14,
              bottom: 11,
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${seat.availableSeats}',
                        style: TextStyle(
                          color: usageColor,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          height: 0.9,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          '석 남음',
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            Align(
              alignment: Alignment.bottomCenter,
              child: Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: usageValue,
                      minHeight: 7,
                      borderRadius: BorderRadius.circular(999),
                      color: usageColor,
                      backgroundColor: colorScheme.surfaceContainer,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _formatRate(seat.usageRate),
                    maxLines: 1,
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _usageColor(BuildContext context, double usageRate) {
  final palette =
      Theme.of(context).extension<HongikPalette>() ?? HongikPalette.light;
  if (usageRate >= 85) {
    return palette.seatCrowded;
  }
  if (usageRate >= 65) {
    return palette.warning;
  }
  if (usageRate >= 40) {
    return palette.seatModerate;
  }
  return palette.seatAvailable;
}

String _formatRate(double rate) {
  final normalized = rate.clamp(0, 100);
  if (normalized == normalized.roundToDouble()) {
    return '${normalized.toStringAsFixed(0)}%';
  }
  return '${normalized.toStringAsFixed(1)}%';
}
