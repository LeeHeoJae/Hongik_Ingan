import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hongik_ingan/core/network/school_transport_provider.dart';
import 'package:hongik_ingan/features/home/application/home_controller.dart';
import '../data/attendance_overview_service.dart';
import '../domain/attendance_overview.dart';
import 'attendance_controller.dart';

final attendanceOverviewServiceProvider = Provider<AttendanceOverviewService>(
  (ref) => AttendanceOverviewService(ref.watch(schoolTransportProvider)),
);

final attendanceOverviewProvider =
    NotifierProvider.autoDispose<
      AttendanceOverviewController,
      AttendanceOverviewState
    >(AttendanceOverviewController.new);

class AttendanceOverviewState {
  const AttendanceOverviewState({
    this.courses = const AsyncLoading(),
    this.details = const {},
    this.refreshingCourses = false,
    this.refreshingDetails = const {},
  });
  final AsyncValue<List<AttendanceCourse>> courses;
  final Map<String, AsyncValue<SchoolAttendanceDetail>> details;
  final bool refreshingCourses;
  final Set<String> refreshingDetails;

  AttendanceOverviewState copyWith({
    AsyncValue<List<AttendanceCourse>>? courses,
    Map<String, AsyncValue<SchoolAttendanceDetail>>? details,
    bool? refreshingCourses,
    Set<String>? refreshingDetails,
  }) => AttendanceOverviewState(
    courses: courses ?? this.courses,
    details: details ?? this.details,
    refreshingCourses: refreshingCourses ?? this.refreshingCourses,
    refreshingDetails: refreshingDetails ?? this.refreshingDetails,
  );
}

class AttendanceOverviewController extends Notifier<AttendanceOverviewState> {
  String? _userId;
  var _generation = 0;
  Future<void>? _courseRequest;
  final Map<String, Future<void>> _detailRequests = {};

  @override
  AttendanceOverviewState build() {
    _userId = ref.watch(
      homeControllerProvider.select(
        (session) => session.isLoggedIn ? session.userId : null,
      ),
    );
    _generation++;
    _courseRequest = null;
    _detailRequests.clear();
    ref.onDispose(() => _generation++);
    final generation = _generation;
    if (_userId != null) {
      unawaited(
        Future.microtask(() {
          if (_isCurrent(generation)) return loadCourses();
        }),
      );
    }
    return const AttendanceOverviewState();
  }

  bool _isCurrent(int generation) =>
      ref.mounted && generation == _generation && _userId != null;

  Future<T> _fetch<T>(Future<T> Function() request, int generation) async {
    final attendance = ref.read(attendanceProvider.notifier);
    if (attendance.hasActiveSubmission ||
        ref.read(homeControllerProvider).isLoading) {
      throw const AttendanceOverviewException('출결 진행이 끝난 뒤 다시 확인해 주세요.');
    }
    try {
      return await request();
    } on AttendanceOverviewException catch (error) {
      if ((!error.sessionExpired && !error.integrationError) ||
          !_isCurrent(generation) ||
          attendance.hasActiveSubmission) {
        rethrow;
      }
      final recovered = await ref
          .read(homeControllerProvider.notifier)
          .recoverAttendanceSession();
      if (!_isCurrent(generation) ||
          !recovered ||
          attendance.hasActiveSubmission) {
        rethrow;
      }
      return request();
    }
  }

  Future<void> loadCourses({bool refresh = false}) {
    if (_courseRequest != null) return _courseRequest!;
    if (!refresh && state.courses.hasValue) return Future.value();
    final generation = _generation;
    state = state.copyWith(
      courses: state.courses.hasValue ? state.courses : const AsyncLoading(),
      refreshingCourses: true,
    );
    late final Future<void> request;
    request = _loadCourses(generation).whenComplete(() {
      if (_isCurrent(generation) && identical(_courseRequest, request)) {
        _courseRequest = null;
      }
    });
    return _courseRequest = request;
  }

  Future<void> _loadCourses(int generation) async {
    final result = await AsyncValue.guard(
      () => _fetch(
        ref.read(attendanceOverviewServiceProvider).fetchCourses,
        generation,
      ),
    );
    if (!_isCurrent(generation)) return;
    state = state.copyWith(courses: result, refreshingCourses: false);
  }

  Future<void> loadDetail(AttendanceCourse course, {bool refresh = false}) {
    final id = course.key.id;
    if (_detailRequests[id] != null) return _detailRequests[id]!;
    if (!refresh && state.details[id]?.hasValue == true) return Future.value();
    final generation = _generation;
    state = state.copyWith(
      details: {
        ...state.details,
        id: state.details[id]?.hasValue == true
            ? state.details[id]!
            : const AsyncLoading(),
      },
      refreshingDetails: {...state.refreshingDetails, id},
    );
    late final Future<void> request;
    request = _loadDetail(course, generation).whenComplete(() {
      if (_isCurrent(generation) && identical(_detailRequests[id], request)) {
        _detailRequests.remove(id);
      }
    });
    _detailRequests[id] = request;
    return request;
  }

  Future<void> _loadDetail(AttendanceCourse course, int generation) async {
    final result = await AsyncValue.guard(
      () => _fetch(
        () => ref.read(attendanceOverviewServiceProvider).fetchDetail(course),
        generation,
      ),
    );
    if (!_isCurrent(generation)) return;
    state = state.copyWith(
      details: {...state.details, course.key.id: result},
      refreshingDetails: {...state.refreshingDetails}..remove(course.key.id),
    );
  }
}
