import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'attendance_data_source.dart';
import 'package:hongik_ingan/features/home/application/home_controller.dart';
import '../data/attendance_overview_service.dart';
import '../domain/attendance_overview.dart';
import 'attendance_controller.dart';

final attendanceOverviewServiceProvider = Provider<AttendanceOverviewService>(
  (ref) => AttendanceOverviewService(ref.watch(attendanceTransportProvider)),
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
    this.courseRefreshFailed = false,
  });
  final AsyncValue<List<AttendanceCourse>> courses;
  final Map<String, AsyncValue<SchoolAttendanceDetail>> details;
  final bool refreshingCourses;
  final Set<String> refreshingDetails;
  final bool courseRefreshFailed;

  AttendanceOverviewState copyWith({
    AsyncValue<List<AttendanceCourse>>? courses,
    Map<String, AsyncValue<SchoolAttendanceDetail>>? details,
    bool? refreshingCourses,
    Set<String>? refreshingDetails,
    bool? courseRefreshFailed,
  }) => AttendanceOverviewState(
    courses: courses ?? this.courses,
    details: details ?? this.details,
    refreshingCourses: refreshingCourses ?? this.refreshingCourses,
    refreshingDetails: refreshingDetails ?? this.refreshingDetails,
    courseRefreshFailed: courseRefreshFailed ?? this.courseRefreshFailed,
  );
}

class AttendanceOverviewController extends Notifier<AttendanceOverviewState> {
  String? _userId;
  var _generation = 0;
  Future<void>? _courseRequest;
  final Map<String, _DetailRequest> _detailRequests = {};
  final List<_DetailRequest> _detailQueue = [];
  var _detailRevision = 0;
  var _drainingDetails = false;

  @override
  AttendanceOverviewState build() {
    _userId = ref.watch(
      homeControllerProvider.select(
        (session) => session.isLoggedIn ? session.userId : null,
      ),
    );
    _generation++;
    _courseRequest = null;
    for (final request in _detailQueue) {
      request.completer.complete();
    }
    _detailQueue.clear();
    _detailRequests.clear();
    _drainingDetails = false;
    ref.onDispose(() {
      _generation++;
      for (final request in _detailQueue) {
        request.completer.complete();
      }
      _detailQueue.clear();
    });
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
          !recovered.isRestored ||
          attendance.hasActiveSubmission) {
        rethrow;
      }
      await attendance.fetchLecture(forceRefresh: true);
      if (!_isCurrent(generation) || attendance.hasActiveSubmission) rethrow;
      return request();
    }
  }

  Future<void> loadCourses({bool refresh = false}) {
    if (_courseRequest != null) return _courseRequest!;
    if (!refresh && state.courses.hasValue) return Future.value();
    if (refresh) {
      _detailRevision++;
      for (final request in _detailQueue) {
        request.completer.complete();
      }
      _detailQueue.clear();
      _detailRequests.clear();
    }
    final generation = _generation;
    state = state.copyWith(
      courses: state.courses.hasValue ? state.courses : const AsyncLoading(),
      refreshingCourses: true,
      courseRefreshFailed: false,
      details: refresh ? {} : state.details,
      refreshingDetails: refresh ? {} : state.refreshingDetails,
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
    if (result.hasError && state.courses.hasValue) {
      state = state.copyWith(
        refreshingCourses: false,
        courseRefreshFailed: true,
      );
      return;
    }
    final courses = result.asData?.value;
    final ids = courses?.map((course) => course.key.id).toSet() ?? <String>{};
    state = state.copyWith(
      courses: result,
      refreshingCourses: false,
      details: {
        for (final entry in state.details.entries)
          if (ids.contains(entry.key)) entry.key: entry.value,
      },
    );
    if (courses != null) {
      for (final course in courses) {
        unawaited(_queueDetail(course, background: true));
      }
    }
  }

  Future<void> loadDetail(AttendanceCourse course, {bool refresh = false}) =>
      _queueDetail(course, refresh: refresh);

  Future<void> _queueDetail(
    AttendanceCourse course, {
    bool refresh = false,
    bool background = false,
  }) {
    final id = course.key.id;
    final existing = _detailRequests[id];
    if (existing != null) {
      if (!background && _detailQueue.remove(existing)) {
        _detailQueue.insert(0, existing);
      }
      return existing.completer.future;
    }
    if (!refresh && state.details[id]?.hasValue == true) return Future.value();
    state = state.copyWith(
      details: {
        ...state.details,
        id: state.details[id]?.hasValue == true
            ? state.details[id]!
            : const AsyncLoading(),
      },
      refreshingDetails: {...state.refreshingDetails, id},
    );
    final request = _DetailRequest(course, _generation, _detailRevision);
    _detailRequests[id] = request;
    if (background) {
      _detailQueue.add(request);
    } else {
      _detailQueue.insert(0, request);
    }
    if (!_drainingDetails) {
      _drainingDetails = true;
      unawaited(Future.microtask(() => _drainDetails(_generation)));
    }
    return request.completer.future;
  }

  Future<void> _drainDetails(int generation) async {
    while (_isCurrent(generation) && _detailQueue.isNotEmpty) {
      final request = _detailQueue.removeAt(0);
      await _loadDetail(request);
      if (!request.completer.isCompleted) request.completer.complete();
      final id = request.course.key.id;
      if (_isCurrent(generation) && identical(_detailRequests[id], request)) {
        _detailRequests.remove(id);
      }
    }
    if (_isCurrent(generation)) _drainingDetails = false;
  }

  Future<void> _loadDetail(_DetailRequest request) async {
    final course = request.course;
    final generation = request.generation;
    final result = await AsyncValue.guard(
      () => _fetch(
        () => ref.read(attendanceOverviewServiceProvider).fetchDetail(course),
        generation,
      ),
    );
    if (!_isCurrent(generation) || request.revision != _detailRevision) return;
    state = state.copyWith(
      details: {...state.details, course.key.id: result},
      refreshingDetails: {...state.refreshingDetails}..remove(course.key.id),
    );
    final error = result.asError;
    final cause = error?.error;
    if (cause is AttendanceOverviewException &&
        (cause.sessionExpired || cause.integrationError)) {
      final pending = List<_DetailRequest>.of(_detailQueue);
      _detailQueue.clear();
      final details = {...state.details};
      final refreshing = {...state.refreshingDetails};
      for (final queued in pending) {
        final id = queued.course.key.id;
        details[id] = AsyncError(cause, error!.stackTrace);
        refreshing.remove(id);
        if (identical(_detailRequests[id], queued)) _detailRequests.remove(id);
        queued.completer.complete();
      }
      state = state.copyWith(details: details, refreshingDetails: refreshing);
    }
  }
}

class _DetailRequest {
  _DetailRequest(this.course, this.generation, this.revision);

  final AttendanceCourse course;
  final int generation;
  final int revision;
  final completer = Completer<void>();
}
