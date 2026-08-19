import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:hongik_ingan/core/logging/logger.dart';
import 'package:hongik_ingan/core/network/school_transport_provider.dart';
import 'package:hongik_ingan/features/attendance/data/attendance_service.dart';
import 'package:hongik_ingan/features/attendance/domain/attendance_submission_result.dart';
import 'package:hongik_ingan/features/attendance/domain/lecture.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'attendance_controller.g.dart';

/// 전자 출결 상태.
///
/// [currentLecture]가 있으면 수업 카드가 우선 표시된다.
class AttendanceState {
  /// 현재 출석 가능한 수업.
  final Lecture? currentLecture;

  /// 수업 조회 또는 출석 제출이 진행 중인지 여부.
  final bool isLoading;

  /// 수업 목록 조회에 실패했을 때 보여줄 메시지.
  final String? error;

  const AttendanceState({
    this.currentLecture,
    this.isLoading = false,
    this.error,
  });

  AttendanceState copyWith({
    Lecture? currentLecture,
    bool? isLoading,
    String? error,
  }) {
    return AttendanceState(
      currentLecture: currentLecture ?? this.currentLecture,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

@Riverpod(name: 'attendanceProvider', keepAlive: true)
class AttendanceController extends _$AttendanceController {
  AttendanceController({DateTime Function()? now}) : _now = now ?? DateTime.now;

  static const lectureCacheValidity = Duration(seconds: 15);

  final DateTime Function() _now;
  late final AttendanceService _attendanceService;
  Future<void>? _lectureFetchInFlight;
  DateTime? _lastSuccessfulLectureFetchAt;

  @override
  AttendanceState build() {
    _attendanceService = AttendanceService(ref.watch(schoolTransportProvider));
    return const AttendanceState();
  }

  /// 강의 불러오기.
  Future<void> fetchLecture({bool forceRefresh = false}) {
    final activeRequest = _lectureFetchInFlight;
    if (activeRequest != null) {
      return activeRequest;
    }
    if (!forceRefresh && _hasFreshLectureResult()) {
      return Future.value();
    }

    final request = _fetchLecture();
    _lectureFetchInFlight = request;
    return request.whenComplete(() {
      if (identical(_lectureFetchInFlight, request)) {
        _lectureFetchInFlight = null;
      }
    });
  }

  Future<void> _fetchLecture() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _attendanceService.getActiveLecture();
      switch (result.status) {
        case LectureFetchStatus.success:
          _lastSuccessfulLectureFetchAt = _now();
          state = AttendanceState(
            currentLecture: result.lecture,
            isLoading: false,
          );
          break;
        case LectureFetchStatus.empty:
          _lastSuccessfulLectureFetchAt = _now();
          state = const AttendanceState(currentLecture: null, isLoading: false);
          break;
        case LectureFetchStatus.failure:
          state = AttendanceState(
            currentLecture: null,
            isLoading: false,
            error: result.message,
          );
          break;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '수업 정보를 불러오지 못했어요.');
      logMsg('수업을 불러오는 중 오류가 발생했습니다: $e');
    }
  }

  bool _hasFreshLectureResult() {
    final fetchedAt = _lastSuccessfulLectureFetchAt;
    if (fetchedAt == null || state.error != null) {
      return false;
    }
    final age = _now().difference(fetchedAt);
    return !age.isNegative && age <= lectureCacheValidity;
  }

  Future<Position> getUsersLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('위치 서비스가 꺼져 있어요.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw Exception('출석 확인을 위해 위치 권한이 필요해요.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('위치 권한이 영구적으로 거부됐어요. 브라우저 또는 기기 설정에서 권한을 허용해 주세요.');
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return position;
    } catch (e) {
      logMsg('위치 가져오기 실패: $e');
      throw Exception('위치를 가져오지 못했어요. 기기의 GPS가 켜져 있는지 확인해 주세요.');
    }
  }

  Future<AttendanceSubmissionResult> submitAttendance(
    String authCode,
    Position position,
  ) async {
    if (state.currentLecture == null) {
      return const AttendanceSubmissionResult.failure('현재 진행 중인 수업이 없어요.');
    }
    state = state.copyWith(isLoading: true);
    try {
      final result = await _attendanceService.submitAttendance(
        state.currentLecture!,
        authCode,
        position.latitude.toString(),
        position.longitude.toString(),
      );
      return result;
    } catch (e) {
      return AttendanceSubmissionResult.failure('출석을 제출하지 못했어요: $e');
    } finally {
      state = state.copyWith(isLoading: false);
      fetchLecture(forceRefresh: true);
    }
  }
}
