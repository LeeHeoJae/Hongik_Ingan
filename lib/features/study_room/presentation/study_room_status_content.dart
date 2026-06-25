import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hongik_ingan/core/theme/color.dart';
import 'package:hongik_ingan/features/campus/presentation/campus_segmented_selector.dart';
import 'package:hongik_ingan/features/campus/presentation/campus_sheet_scaffold.dart';
import 'package:hongik_ingan/features/study_room/application/study_room_controller.dart';
import 'package:hongik_ingan/features/study_room/domain/study_room.dart';

class StudyRoomStatusContent extends ConsumerWidget {
  const StudyRoomStatusContent({
    super.key,
    this.compact = false,
    this.useGrid = false,
  });

  final bool compact;
  final bool useGrid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(studyRoomControllerProvider);
    final controller = ref.read(studyRoomControllerProvider.notifier);

    return Column(
      children: [
        _StudyRoomLocationSelector(
          selectedLocation: state.selectedLocation,
          onSelected: controller.selectLocation,
          compact: compact,
        ),
        SizedBox(height: compact ? 10 : 16),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: _buildContent(context, state, controller),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(
    BuildContext context,
    StudyRoomState state,
    StudyRoomController controller,
  ) {
    if (state.isLoading && state.status == null) {
      return const CampusLoadingSkeleton(key: ValueKey('loading'));
    }

    if (state.error != null && state.status == null) {
      return CampusStateMessage(
        key: const ValueKey('error'),
        icon: Icons.wifi_off_rounded,
        title: '열람실 현황을 불러오지 못했습니다',
        message: state.error!,
        actionLabel: '다시 시도',
        onAction: () => controller.refresh(),
      );
    }

    final status = state.status;
    final summary = status?.summary;
    if (status == null || summary == null || status.rooms.isEmpty) {
      return CampusStateMessage(
        key: const ValueKey('empty'),
        icon: Icons.event_seat_outlined,
        title: '표시할 좌석 정보가 없습니다',
        message: '열람실 서버에 좌석 데이터가 등록되어 있지 않습니다.',
        actionLabel: '새로고침',
        onAction: () => controller.refresh(),
      );
    }

    return LayoutBuilder(
      key: const ValueKey('content'),
      builder: (context, constraints) {
        final canUseGrid =
            useGrid && constraints.maxWidth >= 520 && status.rooms.length > 1;
        final spacing = compact ? 10.0 : 12.0;
        final itemWidth = canUseGrid
            ? (constraints.maxWidth - spacing) / 2
            : constraints.maxWidth;

        return ListView(
          padding: const EdgeInsets.only(bottom: 4),
          children: [
            _StudyRoomSummaryCard(summary: summary, compact: compact),
            SizedBox(height: compact ? 10 : 14),
            if (canUseGrid)
              Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: status.rooms.map((seat) {
                  return SizedBox(
                    width: itemWidth,
                    child: _StudyRoomSeatCard(seat: seat, compact: compact),
                  );
                }).toList(growable: false),
              )
            else
              ...status.rooms.map((seat) {
                return Padding(
                  padding: EdgeInsets.only(bottom: compact ? 10 : 12),
                  child: _StudyRoomSeatCard(seat: seat, compact: compact),
                );
              }),
          ],
        );
      },
    );
  }
}

class _StudyRoomSummaryCard extends StatelessWidget {
  const _StudyRoomSummaryCard({
    required this.summary,
    required this.compact,
  });

  final StudyRoomSeat summary;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final palette =
        Theme.of(context).extension<HongikPalette>() ?? HongikPalette.light;
    final usageValue = (summary.usageRate / 100).clamp(0.0, 1.0);
    final usageColor = _usageColor(context, summary.usageRate);

    return Container(
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: palette.cardSurfaceMuted,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.cardOutline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '사용 가능 좌석',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: palette.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '총',
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontSize: compact ? 17 : 20,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                          ),
                          TextSpan(
                            text: '${summary.availableSeats}',
                            style: Theme.of(context).textTheme.displaySmall
                                ?.copyWith(
                                  color: usageColor,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          TextSpan(
                            text: '석 남음',
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontSize: compact ? 16 : 18,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: usageColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '사용률 ${_formatRate(summary.usageRate)}',
                  style: TextStyle(
                    color: usageColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 4 : 5),
          _AnimatedSeatProgress(
            value: usageValue,
            color: usageColor,
            backgroundColor: palette.cardOutline,
            minHeight: compact ? 7 : 8,
          ),
          SizedBox(height: compact ? 7 : 8),
          Wrap(
            spacing: compact ? 8 : 10,
            runSpacing: compact ? 8 : 10,
            children: [
              _MetricPill(
                label: '전체',
                value: '${summary.totalSeats}석',
                compact: compact,
              ),
              _MetricPill(
                label: '사용',
                value: '${summary.usedSeats}석',
                compact: compact,
              ),
              _MetricPill(
                label: '잔여',
                value: '${summary.availableSeats}석',
                compact: compact,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StudyRoomSeatCard extends StatelessWidget {
  const _StudyRoomSeatCard({required this.seat, required this.compact});

  final StudyRoomSeat seat;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final palette = theme.extension<HongikPalette>() ?? HongikPalette.light;

    final usageValue = (seat.usageRate / 100).clamp(0.0, 1.0).toDouble();
    final usageColor = _usageColor(context, seat.usageRate);
    final statusLabel = _statusLabel(seat);

    return Container(
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: palette.cardSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.cardOutline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  seat.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: usageColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: usageColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: FittedBox(
                  alignment: Alignment.centerLeft,
                  fit: BoxFit.scaleDown,
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${seat.availableSeats}',
                          style: TextStyle(
                            color: usageColor,
                            fontSize: compact ? 36 : 44,
                            fontWeight: FontWeight.w900,
                            height: 0.9,
                            letterSpacing: 0,
                          ),
                        ),
                        TextSpan(
                          text: '석 남음',
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: compact ? 15 : 18,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('전체 ${seat.totalSeats}석', style: _metaStyle(context)),
                  const SizedBox(height: 4),
                  Text('사용 ${seat.usedSeats}석', style: _metaStyle(context)),
                ],
              ),
            ],
          ),
          SizedBox(height: compact ? 10 : 14),
          _AnimatedSeatProgress(
            value: usageValue,
            minHeight: compact ? 7 : 8,
            color: usageColor,
            backgroundColor: palette.cardSurfaceMuted,
          ),
          SizedBox(height: compact ? 7 : 8),
          Row(
            children: [
              Text('사용률', style: _metaStyle(context)),
              const SizedBox(width: 6),
              Text(
                _formatRate(seat.usageRate),
                style: TextStyle(
                  color: usageColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const Spacer(),
              Text(
                seat.availableSeats == 0 ? '빈 좌석이 없습니다' : '이용 가능',
                style: TextStyle(
                  color: seat.availableSeats == 0
                      ? palette.seatCrowded
                      : usageColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _statusLabel(StudyRoomSeat seat) {
    if (seat.availableSeats <= 0) {
      return '만석';
    }

    final usageRate = seat.usageRate;

    if (usageRate >= 85) {
      return '혼잡';
    }
    if (usageRate >= 65) {
      return '주의';
    }
    if (usageRate >= 40) {
      return '보통';
    }
    return '여유';
  }

  TextStyle? _metaStyle(BuildContext context) {
    final palette =
        Theme.of(context).extension<HongikPalette>() ?? HongikPalette.light;

    return Theme.of(context).textTheme.bodySmall?.copyWith(
      color: palette.textSecondary,
      fontWeight: FontWeight.w700,
      height: 1.1,
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.label,
    required this.value,
    required this.compact,
  });

  final String label;
  final String value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette =
        Theme.of(context).extension<HongikPalette>() ?? HongikPalette.light;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 7 : 9,
      ),
      decoration: BoxDecoration(
        color: palette.cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.cardOutline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: palette.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _StudyRoomLocationSelector extends StatelessWidget {
  const _StudyRoomLocationSelector({
    required this.selectedLocation,
    required this.onSelected,
    required this.compact,
  });

  final StudyRoomLocation selectedLocation;
  final ValueChanged<StudyRoomLocation> onSelected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return CampusSegmentedSelector<StudyRoomLocation>(
      items: StudyRoomLocation.values,
      selectedItem: selectedLocation,
      labelOf: (location) => location.label,
      onSelected: onSelected,
      height: compact ? 38 : 46,
      fontSize: compact ? 14 : 15,
    );
  }
}

class _AnimatedSeatProgress extends StatelessWidget {
  const _AnimatedSeatProgress({
    required this.value,
    required this.color,
    required this.backgroundColor,
    required this.minHeight,
  });

  final double value;
  final Color color;
  final Color backgroundColor;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, child) {
        return LinearProgressIndicator(
          value: animatedValue,
          minHeight: minHeight,
          borderRadius: BorderRadius.circular(999),
          color: color,
          backgroundColor: backgroundColor,
        );
      },
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
