import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hongik_ingan/core/presentation/widgets/content_state_message.dart';
import 'package:hongik_ingan/core/theme/color.dart';
import 'package:hongik_ingan/features/seat/application/seat_controller.dart';
import 'package:hongik_ingan/features/seat/domain/seat.dart';
import 'package:hongik_ingan/features/seat/presentation/widgets/seat_location_selector.dart';
import 'package:hongik_ingan/features/seat/presentation/widgets/seat_status_cards.dart';

class SeatStatusContent extends ConsumerWidget {
  const SeatStatusContent({
    super.key,
    this.compact = false,
    this.useGrid = false,
    this.wideDetail = false,
    this.naturalHeight = false,
  });

  final bool compact;
  final bool useGrid;
  final bool wideDetail;
  final bool naturalHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(seatControllerProvider);
    final controller = ref.read(seatControllerProvider.notifier);
    final status = state.status;
    final summary = status?.summary;
    final hasRooms = summary != null && status!.rooms.isNotEmpty;
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final columns = useGrid && constraints.maxWidth >= 560 * scale ? 2 : 1;
        final roomWidth = (constraints.maxWidth - (columns - 1) * 10) / columns;
        final selector = SizedBox(
          width: constraints.maxWidth.clamp(0, 240),
          child: SeatLocationSelector(
            selectedLocation: state.selectedLocation,
            onSelected: controller.selectLocation,
            compact: true,
          ),
        );
        final content = Column(
          key: hasRooms
              ? const ValueKey('seat-results')
              : const ValueKey('seat-compact-state'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 20,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SelectionContainer.disabled(child: selector),
                if (hasRooms)
                  Text(
                    '건물 전체 ${summary.availableSeats}석 남음',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (!hasRooms)
              SelectionContainer.disabled(
                child: _buildCompactStatus(context, state, controller),
              )
            else ...[
              if (state.error != null) ...[
                SelectionContainer.disabled(
                  child: _SeatRefreshWarning(message: state.error!),
                ),
                const SizedBox(height: 10),
              ],
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final room in status.rooms)
                    SizedBox(
                      width: roomWidth,
                      child: SeatCard(seat: room, compact: true),
                    ),
                ],
              ),
            ],
          ],
        );
        return naturalHeight
            ? content
            : SingleChildScrollView(
                key: const PageStorageKey('seat-detail-scroll'),
                child: content,
              );
      },
    );
  }

  Widget _buildCompactStatus(
    BuildContext context,
    SeatState state,
    SeatController controller,
  ) {
    final isLoading = state.isSelectedLocationLoading && state.status == null;
    final isError = state.error != null && !isLoading;
    final title = isLoading
        ? '좌석 확인 중'
        : isError
        ? '열람실 현황을 불러오지 못했어요'
        : '표시할 좌석 정보가 없어요';
    final message = isLoading
        ? '${state.selectedLocation.label} 좌석을 확인하고 있어요.'
        : isError
        ? state.error!
        : '열람실 서버에 좌석 정보가 등록되어 있지 않아요.';

    return CompactContentStateMessage(
      icon: isError ? Icons.wifi_off_rounded : Icons.event_seat_outlined,
      title: title,
      message: message,
      isLoading: isLoading,
      tone: isError ? ContentStateTone.error : ContentStateTone.neutral,
      actionLabel: isLoading
          ? null
          : isError
          ? '다시 시도'
          : '새로고침',
      onAction: controller.refresh,
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
              '새 좌석 정보를 불러오지 못해 이전 정보를 보여드려요. $message',
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
