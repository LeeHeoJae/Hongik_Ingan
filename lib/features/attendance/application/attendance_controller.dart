import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:hongik_ingan/core/logging/logger.dart';
import 'package:hongik_ingan/features/attendance/data/attendance_service.dart';
import 'package:hongik_ingan/features/attendance/domain/lecture.dart';

part 'attendance_controller.g.dart';

class AttendanceState {
  final Lecture? currentLecture;
  final bool isLoading;
  final String? error;
  final String? emptyMessage;

  const AttendanceState({
    this.currentLecture,
    this.isLoading = false,
    this.error,
    this.emptyMessage,
  });

  AttendanceState copyWith({
    Lecture? currentLecture,
    bool? isLoading,
    String? error,
    String? emptyMessage,
  }) {
    return AttendanceState(
      currentLecture: currentLecture ?? this.currentLecture,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      emptyMessage: emptyMessage,
    );
  }
}

@Riverpod(name: 'attendanceProvider', keepAlive: true)
class AttendanceController extends _$AttendanceController {
  final AttendanceService _attendanceService = AttendanceService();

  @override
  AttendanceState build() {
    return const AttendanceState();
  }

  Future<void> fetchLecture({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        state.currentLecture != null &&
        state.error == null &&
        state.emptyMessage == null) {
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _attendanceService.getLectures();
      switch (result.status) {
        case LectureFetchStatus.success:
        case LectureFetchStatus.partial:
          state = AttendanceState(
            currentLecture: result.lectures.first,
            isLoading: false,
          );
          break;
        case LectureFetchStatus.empty:
          state = AttendanceState(
            currentLecture: null,
            isLoading: false,
            emptyMessage: result.message,
          );
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
      logMsg('Error fetching lecture: $e');
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
