import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/study_room.dart';
import '../services/study_room_service.dart';

final studyRoomControllerProvider =
    NotifierProvider.autoDispose<StudyRoomController, StudyRoomState>(
      StudyRoomController.new,
    );

const Object _unset = Object();

class StudyRoomState {
  const StudyRoomState({
    this.selectedLocation = StudyRoomLocation.tBuilding,
    this.isLoading = false,
    this.status,
    this.error,
  });

  final StudyRoomLocation selectedLocation;
  final bool isLoading;
  final StudyRoomStatus? status;
  final String? error;

  StudyRoomState copyWith({
    StudyRoomLocation? selectedLocation,
    bool? isLoading,
    Object? status = _unset,
    Object? error = _unset,
  }) {
    return StudyRoomState(
      selectedLocation: selectedLocation ?? this.selectedLocation,
      isLoading: isLoading ?? this.isLoading,
      status: identical(status, _unset)
          ? this.status
          : status as StudyRoomStatus?,
      error: identical(error, _unset) ? this.error : error as String?,
    );
  }
}

class StudyRoomController extends Notifier<StudyRoomState> {
  late final StudyRoomService _service;

  @override
  StudyRoomState build() {
    _service = StudyRoomService();
    return const StudyRoomState();
  }

  Future<void> fetchStatus({StudyRoomLocation? location}) async {
    final targetLocation = location ?? state.selectedLocation;
    final keepStatus = targetLocation == state.selectedLocation;

    state = state.copyWith(
      selectedLocation: targetLocation,
      isLoading: true,
      status: keepStatus ? state.status : null,
      error: null,
    );

    try {
      final status = await _service.fetchStatus(targetLocation);
      if (state.selectedLocation != targetLocation) {
        return;
      }
      state = state.copyWith(isLoading: false, status: status, error: null);
    } on StudyRoomServiceException catch (e) {
      if (state.selectedLocation != targetLocation) {
        return;
      }
      state = state.copyWith(isLoading: false, error: e.message);
    }
  }

  Future<void> selectLocation(StudyRoomLocation location) {
    if (location == state.selectedLocation && state.status != null) {
      return fetchStatus();
    }
    return fetchStatus(location: location);
  }

  Future<void> refresh() {
    return fetchStatus();
  }
}
