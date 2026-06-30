import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:hongik_ingan/features/seat/data/seat_service.dart';
import 'package:hongik_ingan/features/seat/domain/seat.dart';

part 'seat_controller.g.dart';

class SeatState {
  const SeatState({
    this.selectedLocation = SeatLocation.tBuilding,
    this.isLoading = false,
    this.statuses = const {},
    this.errors = const {},
  });

  final SeatLocation selectedLocation;
  final bool isLoading;
  final Map<SeatLocation, SeatStatus> statuses;
  final Map<SeatLocation, String> errors;

  SeatStatus? get status => statuses[selectedLocation];

  String? get error => errors[selectedLocation];

  SeatState copyWith({
    SeatLocation? selectedLocation,
    bool? isLoading,
    Map<SeatLocation, SeatStatus>? statuses,
    Map<SeatLocation, String>? errors,
  }) {
    return SeatState(
      selectedLocation: selectedLocation ?? this.selectedLocation,
      isLoading: isLoading ?? this.isLoading,
      statuses: statuses ?? this.statuses,
      errors: errors ?? this.errors,
    );
  }
}

@Riverpod(keepAlive: true)
class SeatController extends _$SeatController {
  late final SeatService _service;

  @override
  SeatState build() {
    _service = SeatService();
    return const SeatState();
  }

  Future<void> fetchStatuses({bool forceRefresh = false}) async {
    if (!forceRefresh && state.statuses.isNotEmpty) {
      return;
    }

    state = state.copyWith(isLoading: true, errors: const {});

    final results = await Future.wait(
      SeatLocation.values.map(_fetchLocationSafely),
    );
    final statuses = <SeatLocation, SeatStatus>{};
    final errors = <SeatLocation, String>{};

    for (final result in results) {
      if (result.status != null) {
        statuses[result.location] = result.status!;
      }
      if (result.error != null) {
        errors[result.location] = result.error!;
      }
    }

    state = state.copyWith(
      isLoading: false,
      statuses: statuses,
      errors: errors,
    );
  }

  void selectLocation(SeatLocation location) {
    state = state.copyWith(selectedLocation: location);
  }

  Future<void> refresh() {
    return fetchStatuses(forceRefresh: true);
  }

  Future<_SeatFetchResult> _fetchLocationSafely(
    SeatLocation location,
  ) async {
    try {
      return _SeatFetchResult(
        location: location,
        status: await _service.fetchStatus(location),
      );
    } on SeatServiceException catch (e) {
      return _SeatFetchResult(location: location, error: e.message);
    }
  }
}

class _SeatFetchResult {
  const _SeatFetchResult({
    required this.location,
    this.status,
    this.error,
  });

  final SeatLocation location;
  final SeatStatus? status;
  final String? error;
}
