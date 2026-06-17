import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/study_room_controller.dart';
import '../../core/theme/color.dart';
import '../../models/study_room.dart';
import 'campus_sheet_scaffold.dart';

class StudyRoomStatusBottomSheet extends ConsumerStatefulWidget {
  const StudyRoomStatusBottomSheet({super.key});

  @override
  ConsumerState<StudyRoomStatusBottomSheet> createState() =>
      _StudyRoomStatusBottomSheetState();
}

class _StudyRoomStatusBottomSheetState
    extends ConsumerState<StudyRoomStatusBottomSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(studyRoomControllerProvider.notifier).fetchStatuses();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(studyRoomControllerProvider);
    final controller = ref.read(studyRoomControllerProvider.notifier);
    final subtitle = state.status == null
        ? '학관, T동, R동 좌석 현황'
        : '${state.status!.location.label} ${_formatTime(state.status!.updatedAt)} 기준';

    return CampusSheetScaffold(
      title: '열람실 현황',
      subtitle: subtitle,
      icon: Icons.event_seat_rounded,
      isRefreshing: state.isLoading && state.statuses.isNotEmpty,
      onRefresh: () => controller.refresh(),
      child: Column(
        children: [
          _StudyRoomLocationSelector(
            selectedLocation: state.selectedLocation,
            onSelected: controller.selectLocation,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _buildContent(context, state, controller),
            ),
          ),
        ],
      ),
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

    return ListView(
      key: const ValueKey('content'),
      padding: const EdgeInsets.only(bottom: 4),
      children: [
        _StudyRoomSummaryCard(summary: summary),
        const SizedBox(height: 14),
        ...status.rooms.map((seat) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _StudyRoomSeatCard(seat: seat),
          );
        }),
      ],
    );
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _StudyRoomSummaryCard extends StatelessWidget {
  const _StudyRoomSummaryCard({required this.summary});

  final StudyRoomSeat summary;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final usageValue = (summary.usageRate / 100).clamp(0.0, 1.0);
    final usageColor = _usageColor(context, summary.usageRate);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.75),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
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
                        color: colorScheme.onSurface.withValues(alpha: 0.62),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${summary.availableSeats}',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: usageColor,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
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
          const SizedBox(height: 12),
          _AnimatedSeatProgress(
            value: usageValue,
            color: usageColor,
            backgroundColor: colorScheme.outlineVariant.withValues(alpha: 0.5),
            minHeight: 8,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MetricPill(label: '전체', value: '${summary.totalSeats}석'),
              _MetricPill(label: '사용', value: '${summary.usedSeats}석'),
              _MetricPill(label: '잔여', value: '${summary.availableSeats}석'),
            ],
          ),
        ],
      ),
    );
  }
}

class _StudyRoomSeatCard extends StatelessWidget {
  const _StudyRoomSeatCard({required this.seat});

  final StudyRoomSeat seat;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final usageValue = (seat.usageRate / 100).clamp(0.0, 1.0);
    final usageColor = _usageColor(context, seat.usageRate);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.76),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.035),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
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
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: usageColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  '${seat.availableSeats}석 가능',
                  style: TextStyle(
                    color: usageColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _AnimatedSeatProgress(
            value: usageValue,
            minHeight: 7,
            color: usageColor,
            backgroundColor: colorScheme.surfaceContainerHighest,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('전체 ${seat.totalSeats}석', style: _metaStyle(context)),
              const SizedBox(width: 12),
              Text('사용 ${seat.usedSeats}석', style: _metaStyle(context)),
              const Spacer(),
              Text(
                '사용 ${_formatRate(seat.usageRate)}',
                style: TextStyle(
                  color: usageColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  TextStyle? _metaStyle(BuildContext context) {
    return Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.58),
      fontWeight: FontWeight.w600,
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.56),
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
  });

  final StudyRoomLocation selectedLocation;
  final ValueChanged<StudyRoomLocation> onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final palette =
        Theme.of(context).extension<HongikPalette>() ?? HongikPalette.light;

    return Row(
      children: StudyRoomLocation.values
          .map((location) {
            final selected = location == selectedLocation;

            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: location == StudyRoomLocation.values.last ? 0 : 8,
                ),
                child: InkWell(
                  onTap: () => onSelected(location),
                  borderRadius: BorderRadius.circular(18),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    height: 46,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: selected
                          ? palette.brandNavy
                          : colorScheme.surfaceContainerHighest.withValues(
                              alpha: 0.42,
                            ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: selected
                            ? Colors.transparent
                            : colorScheme.outlineVariant.withValues(
                                alpha: 0.78,
                              ),
                      ),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: palette.brandNavy.withValues(
                                  alpha: 0.22,
                                ),
                                blurRadius: 14,
                                offset: const Offset(0, 5),
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        location.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected
                              ? Colors.white
                              : colorScheme.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          })
          .toList(growable: false),
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
    return palette.brandRed;
  }
  if (usageRate >= 65) {
    return palette.warning;
  }
  if (usageRate >= 40) {
    return palette.brandBlue;
  }
  return palette.success;
}

String _formatRate(double rate) {
  final normalized = rate.clamp(0, 100);
  if (normalized == normalized.roundToDouble()) {
    return '${normalized.toStringAsFixed(0)}%';
  }
  return '${normalized.toStringAsFixed(1)}%';
}
