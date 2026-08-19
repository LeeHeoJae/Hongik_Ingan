import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hongik_ingan/features/campus/presentation/campus_sheet_scaffold.dart';
import 'package:hongik_ingan/features/seat/application/seat_controller.dart';
import 'package:hongik_ingan/features/seat/domain/seat.dart';
import 'package:hongik_ingan/features/seat/presentation/seat_auto_refresh.dart';
import 'package:hongik_ingan/features/seat/presentation/seat_status_content.dart';

class SeatStatusBottomSheet extends ConsumerStatefulWidget {
  const SeatStatusBottomSheet({super.key});

  @override
  ConsumerState<SeatStatusBottomSheet> createState() =>
      _SeatStatusBottomSheetState();
}

class _SeatStatusBottomSheetState extends ConsumerState<SeatStatusBottomSheet> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(seatControllerProvider);
    final controller = ref.read(seatControllerProvider.notifier);
    final subtitle = state.status == null
        ? '학관, T동, R동 좌석 현황'
        : '${state.status!.location.label} ${_formatTime(state.status!.updatedAt)} 기준';

    return SeatAutoRefresh(
      onRefresh: controller.fetchSelectedStatus,
      child: CampusSheetScaffold(
        title: '열람실 현황',
        subtitle: subtitle,
        icon: Icons.local_library_rounded,
        isRefreshing: state.isLoading && state.statuses.isNotEmpty,
        onRefresh: controller.refresh,
        child: const SeatStatusContent(),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
