import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/study_room.dart';
import '../services/study_room_service.dart';

part 'study_room_controller.g.dart';

class StudyRoomState {
  const StudyRoomState({
    this.selectedLocation = StudyRoomLocation.tBuilding,
    this.isLoading = false,
    this.statuses = const {},
    this.errors = const {},
  });

  final StudyRoomLocation selectedLocation;
  final bool isLoading;
  final Map<StudyRoomLocation, StudyRoomStatus> statuses;
  final Map<StudyRoomLocation, String> errors;

  StudyRoomStatus? get status => statuses[selectedLocation];

  String? get error => errors[selectedLocation];

  StudyRoomState copyWith({
    StudyRoomLocation? selectedLocation,
    bool? isLoading,
    Map<StudyRoomLocation, StudyRoomStatus>? statuses,
    Map<StudyRoomLocation, String>? errors,
  }) {
    return StudyRoomState(
      selectedLocation: selectedLocation ?? this.selectedLocation,
      isLoading: isLoading ?? this.isLoading,
      statuses: statuses ?? this.statuses,
      errors: errors ?? this.errors,
    );
  }
}

@Riverpod(keepAlive: true)
class StudyRoomController extends _$StudyRoomController {
  late final StudyRoomService _service;

  @override
  StudyRoomState build() {
    _service = StudyRoomService();
    return const StudyRoomState();
  }

  Future<void> fetchStatuses({bool forceRefresh = false}) async {
    if (!forceRefresh && state.statuses.isNotEmpty) {
      return;
    }

    state = state.copyWith(isLoading: true, errors: const {});

    final results = await Future.wait(
      StudyRoomLocation.values.map(_fetchLocationSafely),
    );
    final statuses = <StudyRoomLocation, StudyRoomStatus>{};
    final errors = <StudyRoomLocation, String>{};

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

  void selectLocation(StudyRoomLocation location) {
    state = state.copyWith(selectedLocation: location);
  }

  Future<void> refresh() {
    return fetchStatuses(forceRefresh: true);
  }

  Future<_StudyRoomFetchResult> _fetchLocationSafely(
    StudyRoomLocation location,
  ) async {
    try {
      return _StudyRoomFetchResult(
        location: location,
        status: await _service.fetchStatus(location),
      );
    } on StudyRoomServiceException catch (e) {
      return _StudyRoomFetchResult(location: location, error: e.message);
    }
  }
}

class _StudyRoomFetchResult {
  const _StudyRoomFetchResult({
    required this.location,
    this.status,
    this.error,
  });

  final StudyRoomLocation location;
  final StudyRoomStatus? status;
  final String? error;
}
