import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/logger.dart';
import '../models/lecture.dart';
import '../services/attendance_service.dart';

part 'attendance_controller.g.dart';

class AttendanceState {
  final Lecture? currentLecture;
  final bool isLoading;
  final String? error;
  final String? emptyMessage;

  AttendanceState({
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

@Riverpod(name: 'attendanceProvider')
class AttendanceController extends _$AttendanceController {
  final AttendanceService _attendanceService = AttendanceService();

  @override
  AttendanceState build() {
    return AttendanceState();
  }

  Future<void> fetchLecture() async {
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
    var permissionStatus = await Permission.locationWhenInUse.request();
    if (permissionStatus.isDenied || permissionStatus.isPermanentlyDenied) {
      throw Exception('출석 체크를 위해 위치 권한이 필요합니다.');
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
      fetchLecture();
    }
  }
}
