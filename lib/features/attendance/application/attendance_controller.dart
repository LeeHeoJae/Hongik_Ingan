import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:hongik_ingan/core/logging/logger.dart';
import 'package:hongik_ingan/core/network/school_transport_provider.dart';
import 'package:hongik_ingan/features/attendance/data/attendance_service.dart';
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
  late final AttendanceService _attendanceService;

  @override
  AttendanceState build() {
    _attendanceService = AttendanceService(ref.watch(schoolTransportProvider));
    return const AttendanceState();
  }

  /// 강의 불러오기.
  Future<void> fetchLecture({bool forceRefresh = false}) async {
    if (!forceRefresh && state.currentLecture != null && state.error == null) {
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _attendanceService.getActiveLecture();
      switch (result.status) {
        case LectureFetchStatus.success:
          state = AttendanceState(
            currentLecture: result.lecture,
            isLoading: false,
          );
          break;
        case LectureFetchStatus.empty:
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
      state = state.copyWith(isLoading: false, error: '수업 정보를 불러오는 데 실패했습니다.');
      logMsg('강의를 불러오는데 오류가 발생했습니다.: $e');
    }
  }

  Future<Position> getUsersLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('위치 서비스가 비활성화되어 있습니다.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw Exception('출석 체크를 위해 위치 권한이 필요합니다.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('위치 권한이 영구적으로 거부되었습니다. 브라우저 또는 기기 설정에서 권한을 허용해주세요.');
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
      throw Exception('위치를 가져오는 데 실패했습니다. 기기의 GPS를 확인해주세요.');
    }
  }

  Future<String> submitAttendance(String authCode, Position position) async {
    if (state.currentLecture == null) {
      return '현재 진행 중인 수업이 없습니다.';
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
      return '출석 제출에 실패했습니다: $e';
    } finally {
      state = state.copyWith(isLoading: false);
      fetchLecture(forceRefresh: true);
    }
  }
}
