import 'dart:async';
import 'package:hongik_ingan/core/haptics/app_haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hongik_ingan/features/seat/application/seat_controller.dart';
import 'package:hongik_ingan/features/seat/domain/seat.dart';
import 'package:hongik_ingan/features/seat/presentation/seat_auto_refresh.dart';
import 'package:hongik_ingan/features/seat/presentation/seat_status_content.dart';
import '../layouts/home_service_workspace.dart';
import 'home_attendance_density.dart';
import 'home_panel_heading.dart';

class HomeSeatPanel extends ConsumerStatefulWidget {
  const HomeSeatPanel({super.key, required this.isPrimary});
  final bool isPrimary;
  @override
  ConsumerState<HomeSeatPanel> createState() => _HomeSeatPanelState();
}

class _HomeSeatPanelState extends ConsumerState<HomeSeatPanel> {
  final Set<SeatLocation> _manualSeatRefreshLocations = {};
  Future<void> _refreshSeatsManually() async {
    final location = ref.read(seatControllerProvider).selectedLocation;
    if (_manualSeatRefreshLocations.contains(location)) return;
    setState(() => _manualSeatRefreshLocations.add(location));
    try {
      await AppHaptics.instance.runAction(
        ref.read(seatControllerProvider.notifier).refresh,
        isCurrent: () =>
            mounted &&
            ref.read(seatControllerProvider).selectedLocation == location,
        hasError: () =>
            ref.read(seatControllerProvider).errors[location] != null,
      );
    } finally {
      if (mounted) {
        setState(() => _manualSeatRefreshLocations.remove(location));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(seatControllerProvider);
    final density = HomeAttendanceDensityScope.of(context);
    final controller = ref.read(seatControllerProvider.notifier);
    final updatedAt = state.status?.updatedAt;
    final showProgress =
        state.isSelectedLocationLoading &&
        (state.status == null ||
            _manualSeatRefreshLocations.contains(state.selectedLocation));
    final seatSubtitle = showProgress
        ? '${state.selectedLocation.label} 좌석을 확인하고 있어요.'
        : updatedAt == null
        ? '건물을 선택해 좌석 현황을 확인해요.'
        : '${state.selectedLocation.label} · ${updatedAt.hour.toString().padLeft(2, '0')}:${updatedAt.minute.toString().padLeft(2, '0')} 기준';
    return SelectionArea(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: density.verticalPadding,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HomePanelHeading(
              service: HomeService.seat,
              title: '열람실 좌석 현황',
              subtitle: seatSubtitle,
              onRefresh: showProgress
                  ? null
                  : () => unawaited(_refreshSeatsManually()),
              isRefreshing: showProgress,
            ),
            SizedBox(height: density.detailHeadingGap),
            SeatAutoRefresh(
              enabled: widget.isPrimary,
              onRefresh: controller.fetchSelectedStatus,
              child: const SeatStatusContent(naturalHeight: true),
            ),
          ],
        ),
      ),
    );
  }
}
