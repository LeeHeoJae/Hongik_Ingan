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
  }) : statuses = Map.unmodifiable(statuses),
       errors = Map.unmodifiable(errors),
       loadingLocations = Set.unmodifiable(loadingLocations);

  final SeatLocation selectedLocation;
  final Map<SeatLocation, SeatStatus> statuses;
  final Map<SeatLocation, String> errors;
  final Set<SeatLocation> loadingLocations;

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
  }) {
    return SeatState(
      selectedLocation: selectedLocation ?? this.selectedLocation,
      statuses: statuses ?? this.statuses,
      errors: errors ?? this.errors,
      loadingLocations: loadingLocations ?? this.loadingLocations,
    );
  }
}

@Riverpod(keepAlive: true)
class SeatController extends _$SeatController {
  late final SeatService _service;
  final Map<SeatLocation, Future<void>> _inFlight = {};

  @override
  SeatState build() {
    _service = SeatService(ref.watch(schoolTransportProvider));
    return SeatState();
  }

  /// 열람실 좌석 현황 불러오기.
  ///
  /// 기본적으로 아직 조회되지 않은 위치만 요청하고,
  /// 이미 진행 중인 위치의 조회가 있다면 해당 요청을 공유한다.
  /// [forceRefresh]가 참이면 모든 위치를 강제로 다시 조회한다.
  Future<void> fetchStatuses({bool forceRefresh = false}) async {
    final targets = forceRefresh
        ? SeatLocation.values
        : SeatLocation.values
              .where((location) => !state.statuses.containsKey(location))
              .toList(growable: false);
    if (targets.isEmpty) return;

    await Future.wait(targets.map(_fetchLocation));
  }

  Future<void> _fetchLocation(SeatLocation location) {
    final existing = _inFlight[location];
    if (existing != null) {
      return existing;
    }

    late final Future<void> operation;
    operation = _performFetch(location).whenComplete(() {
      if (identical(_inFlight[location], operation)) {
        _inFlight.remove(location);
      }
    });
    _inFlight[location] = operation;
    return operation;
  }

  Future<void> _performFetch(SeatLocation location) async {
    final loadingLocations = Set<SeatLocation>.of(state.loadingLocations)
      ..add(location);
    final errors = Map<SeatLocation, String>.of(state.errors)..remove(location);
    state = state.copyWith(loadingLocations: loadingLocations, errors: errors);

    try {
      final status = await _service.fetchStatus(location);
      final latestStatuses = Map<SeatLocation, SeatStatus>.of(state.statuses)
        ..[location] = status;
      final latestErrors = Map<SeatLocation, String>.of(state.errors)
        ..remove(location);
      state = state.copyWith(statuses: latestStatuses, errors: latestErrors);
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
  }

  Future<void> refresh() {
    return fetchStatuses(forceRefresh: true);
  }
}
