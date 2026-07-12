import 'package:hongik_ingan/core/network/school_transport_provider.dart';
import 'package:hongik_ingan/features/seat/data/seat_service.dart';
import 'package:hongik_ingan/features/seat/domain/seat.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'seat_controller.g.dart';

/// 세 건물의 좌석 상태.
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
  Future<void>? _fetchInProgress;

  @override
  SeatState build() {
    _service = SeatService(ref.watch(schoolTransportProvider));
    return const SeatState();
  }

  /// 열람실 좌석 현황 불러오기.
  ///
  /// 기본적으로 아직 조회되지 않은 위치만 요청하고,
  /// 이미 진행중인 조회가 있다면 마저 한다.
  /// [forceRefresh]가 참이면 모든 위치를 강제로 다시 조회한다.
  Future<void> fetchStatuses({bool forceRefresh = false}) async {
    final progress = _fetchInProgress;
    if (progress != null) return progress;

    final targets = forceRefresh
        ? SeatLocation.values
        : SeatLocation.values
              .where((location) => !state.statuses.containsKey(location))
              .toList(growable: false);
    if (targets.isEmpty) return;

    final operation = _fetchLocations(targets, clearExisting: forceRefresh);
    _fetchInProgress = operation;

    try {
      await operation;
    } finally {
      if (identical(_fetchInProgress, operation)) {
        _fetchInProgress = null;
      }
    }
  }

  /// 지정된 위치의 좌석 현황을 병렬로 조회, 반영.
  ///
  /// [clearExisting]이 참이면 기존 조회 결과를 무시하고 새로 교체한다.
  Future<void> _fetchLocations(
    Iterable<SeatLocation> locations, {
    required bool clearExisting,
  }) async {
    final statuses = clearExisting
        ? <SeatLocation, SeatStatus>{}
        : Map<SeatLocation, SeatStatus>.of(state.statuses);
    final errors = clearExisting
        ? <SeatLocation, String>{}
        : Map<SeatLocation, String>.of(state.errors);
    for (final location in locations) {
      errors.remove(location);
    }

    state = state.copyWith(isLoading: true, errors: errors);

    final results = await Future.wait(locations.map(_fetchLocationSafely));
    for (final result in results) {
      final status = result.status;
      final error = result.error;
      if (status != null) {
        statuses[result.location] = status;
        errors.remove(result.location);
      }
      if (error != null) {
        errors[result.location] = error;
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

  /// 한 위치의 좌석 현황을 조회.
  Future<_SeatFetchResult> _fetchLocationSafely(SeatLocation location) async {
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
  const _SeatFetchResult({required this.location, this.status, this.error});

  final SeatLocation location;
  final SeatStatus? status;
  final String? error;
}
