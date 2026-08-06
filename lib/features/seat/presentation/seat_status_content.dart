import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hongik_ingan/core/theme/color.dart';
import 'package:hongik_ingan/features/campus/presentation/campus_sheet_scaffold.dart';
import 'package:hongik_ingan/features/seat/application/seat_controller.dart';
import 'package:hongik_ingan/features/seat/presentation/widgets/seat_location_selector.dart';
import 'package:hongik_ingan/features/seat/presentation/widgets/seat_status_cards.dart';

class SeatStatusContent extends ConsumerWidget {
  const SeatStatusContent({
    super.key,
    this.compact = false,
    this.useGrid = false,
  });

  final bool compact;
  final bool useGrid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(seatControllerProvider);
    final controller = ref.read(seatControllerProvider.notifier);

    return Column(
      children: [
        SeatLocationSelector(
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
    SeatState state,
    SeatController controller,
  ) {
    if (state.isSelectedLocationLoading && state.status == null) {
      return const CampusLoadingSkeleton(key: ValueKey('loading'));
    }

    if (state.error != null && state.status == null) {
      return CampusStateMessage(
        key: const ValueKey('error'),
        icon: Icons.wifi_off_rounded,
        title: '열람실 현황을 불러오지 못했습니다',
        message: state.error!,
        tone: CampusStateTone.error,
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
            if (state.error != null) ...[
              _SeatRefreshWarning(message: state.error!),
              SizedBox(height: compact ? 10 : 14),
            ],
            SeatSummaryCard(summary: summary, compact: compact),
            SizedBox(height: compact ? 10 : 14),
            if (canUseGrid)
              Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: status.rooms
                    .map((seat) {
                      return SizedBox(
                        width: itemWidth,
                        child: SeatCard(seat: seat, compact: compact),
                      );
                    })
                    .toList(growable: false),
              )
            else
              ...status.rooms.map((seat) {
                return Padding(
                  padding: EdgeInsets.only(bottom: compact ? 10 : 12),
                  child: SeatCard(seat: seat, compact: compact),
                );
              }),
          ],
        );
      },
    );
  }
}

class _SeatRefreshWarning extends StatelessWidget {
  const _SeatRefreshWarning({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final palette =
        Theme.of(context).extension<HongikPalette>() ?? HongikPalette.light;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: palette.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: palette.warning, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '새 좌석 정보를 불러오지 못해 이전 정보를 표시합니다. $message',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: palette.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
