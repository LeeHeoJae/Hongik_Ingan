import 'dart:async';

import 'package:hongik_ingan/core/network/school_request_options.dart';
import 'package:hongik_ingan/core/network/school_transport_provider.dart';
import 'package:hongik_ingan/features/seat/data/seat_service.dart';
import 'package:hongik_ingan/features/seat/domain/seat.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'seat_controller.g.dart';

/// 세 건물의 좌석 상태.
class SeatState {
  SeatState({
    this.selectedLocation = SeatLocation.tBuilding,
    Map<SeatLocation, SeatStatus> statuses = const {},
    Map<SeatLocation, String> errors = const {},
    Set<SeatLocation> loadingLocations = const {},
    Map<SeatLocation, DateTime> fetchedAt = const {},
  }) : statuses = Map.unmodifiable(statuses),
       errors = Map.unmodifiable(errors),
       loadingLocations = Set.unmodifiable(loadingLocations),
       fetchedAt = Map.unmodifiable(fetchedAt);

  final SeatLocation selectedLocation;
  final Map<SeatLocation, SeatStatus> statuses;
  final Map<SeatLocation, String> errors;
  final Set<SeatLocation> loadingLocations;
  final Map<SeatLocation, DateTime> fetchedAt;

  bool get isLoading => loadingLocations.isNotEmpty;

  bool get isSelectedLocationLoading =>
      loadingLocations.contains(selectedLocation);

  SeatStatus? get status => statuses[selectedLocation];

  String? get error => errors[selectedLocation];

  SeatState copyWith({
    SeatLocation? selectedLocation,
    Map<SeatLocation, SeatStatus>? statuses,
    Map<SeatLocation, String>? errors,
    Set<SeatLocation>? loadingLocations,
    Map<SeatLocation, DateTime>? fetchedAt,
  }) {
    return SeatState(
      selectedLocation: selectedLocation ?? this.selectedLocation,
      statuses: statuses ?? this.statuses,
      errors: errors ?? this.errors,
      loadingLocations: loadingLocations ?? this.loadingLocations,
      fetchedAt: fetchedAt ?? this.fetchedAt,
    );
  }
}

@Riverpod(keepAlive: true)
class SeatController extends _$SeatController {
  static const _freshness = Duration(seconds: 5);

  late final SeatService _service;
  final Map<SeatLocation, Future<void>> _inFlight = {};

  @override
  SeatState build() {
    _service = SeatService(ref.watch(schoolTransportProvider));
    return SeatState();
  }

  /// 현재 선택 건물만 조회.
  Future<void> fetchSelectedStatus({bool forceRefresh = false}) {
    return _fetchLocations([
      state.selectedLocation,
    ], forceRefresh: forceRefresh);
  }

  /// 열람실 좌석 현황 불러오기.
  ///
  /// 기본적으로 아직 조회되지 않은 위치만 요청하고,
  /// 이미 진행 중인 위치의 조회가 있다면 해당 요청을 공유한다.
  /// [forceRefresh]가 참이면 모든 위치를 강제로 다시 조회한다.
  Future<void> fetchStatuses({bool forceRefresh = false}) async {
    await _fetchLocations(SeatLocation.values, forceRefresh: forceRefresh);
  }

  Future<void> _fetchLocations(
    Iterable<SeatLocation> locations, {
    required bool forceRefresh,
  }) async {
    final now = DateTime.now();
    final targets = forceRefresh
        ? locations.toList(growable: false)
        : locations
              .where((location) {
                final fetchedAt = state.fetchedAt[location];
                return !state.statuses.containsKey(location) ||
                    fetchedAt == null ||
                    now.difference(fetchedAt) >= _freshness;
              })
              .toList(growable: false);
    if (targets.isEmpty) return;

    final cacheMode = forceRefresh
        ? NetworkCacheMode.revalidate
        : NetworkCacheMode.preferCache;
    await Future.wait(
      targets.map((location) => _fetchLocation(location, cacheMode)),
    );
  }

  Future<void> _fetchLocation(
    SeatLocation location,
    NetworkCacheMode cacheMode,
  ) {
    final existing = _inFlight[location];
    if (existing != null) {
      return existing;
    }

    late final Future<void> operation;
    operation = _performFetch(location, cacheMode).whenComplete(() {
      if (identical(_inFlight[location], operation)) {
        _inFlight.remove(location);
      }
    });
    _inFlight[location] = operation;
    return operation;
  }

  Future<void> _performFetch(
    SeatLocation location,
    NetworkCacheMode cacheMode,
  ) async {
    final loadingLocations = Set<SeatLocation>.of(state.loadingLocations)
      ..add(location);
    final errors = Map<SeatLocation, String>.of(state.errors)..remove(location);
    state = state.copyWith(loadingLocations: loadingLocations, errors: errors);

    try {
      final status = await _service.fetchStatus(location, cacheMode: cacheMode);
      final latestStatuses = Map<SeatLocation, SeatStatus>.of(state.statuses)
        ..[location] = status;
      final latestErrors = Map<SeatLocation, String>.of(state.errors)
        ..remove(location);
      final latestFetchedAt = Map<SeatLocation, DateTime>.of(state.fetchedAt)
        ..[location] = DateTime.now();
      state = state.copyWith(
        statuses: latestStatuses,
        errors: latestErrors,
        fetchedAt: latestFetchedAt,
      );
    } on SeatServiceException catch (error) {
      final latestErrors = Map<SeatLocation, String>.of(state.errors)
        ..[location] = error.message;
      state = state.copyWith(errors: latestErrors);
    } finally {
      final latestLoadingLocations = Set<SeatLocation>.of(
        state.loadingLocations,
      )..remove(location);
      state = state.copyWith(loadingLocations: latestLoadingLocations);
    }
  }

  void selectLocation(SeatLocation location) {
    state = state.copyWith(selectedLocation: location);
    unawaited(fetchSelectedStatus());
  }

  Future<void> refresh() {
    return fetchSelectedStatus(forceRefresh: true);
  }
}
