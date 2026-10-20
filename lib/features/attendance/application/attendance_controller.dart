import 'dart:async';
import 'dart:io' show HttpDate, HttpException;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hongik_ingan/core/logging/logger.dart';
import 'attendance_data_source.dart';
import 'package:hongik_ingan/features/attendance/application/attendance_history_provider.dart';
import 'package:hongik_ingan/features/attendance/data/attendance_history_repository.dart';
import 'package:hongik_ingan/features/attendance/domain/attendance_overview.dart';
import 'package:hongik_ingan/features/attendance/data/attendance_service.dart';
import 'package:hongik_ingan/features/attendance/domain/attendance_request_record.dart';
import 'package:hongik_ingan/features/attendance/domain/attendance_submission_result.dart';
import 'package:hongik_ingan/features/attendance/domain/lecture.dart';
import 'package:hongik_ingan/features/home/application/home_controller.dart';
import 'package:hongik_ingan/features/home/domain/session_recovery_result.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'attendance_controller.g.dart';

/// 전자출결의 진행 단계.
enum AttendancePhase {
  /// 대기 중
  idle,

  /// 수업 조회 중
  fetchingLecture,

  /// 인증번호 입력 대기 중
  enteringCode,

  /// 위치 확인 중
  locating,

  /// 출석 제출 중
  submitting,
}

/// 전자출결 상태.
///
/// [submissionResult]는 현재 출결 흐름이 끝날 때까지 수업 정보보다 우선 표시한다.
class AttendanceState {
  /// 현재 출석 가능한 수업.
  final Lecture? currentLecture;

  /// 수업 조회 또는 출석 처리의 진행 단계.
  final AttendancePhase phase;

  /// 현재 세션에서 수업 조회 결과를 받은 적이 있는지 여부.
  final bool hasCheckedLecture;

  bool get isBusy => phase != AttendancePhase.idle;

  /// 수업 목록 조회에 실패했을 때 보여줄 메시지.
  final String? error;

  const AttendanceState({
    this.currentLecture,
    this.phase = AttendancePhase.idle,
    this.hasCheckedLecture = false,
    this.error,
    this.sessionExpired = false,
    this.retryNotBefore,
    this.isLectureStale = false,
    this.submissionResult,
  });

  final bool sessionExpired;
  final DateTime? retryNotBefore;
  final bool isLectureStale;
  final AttendanceSubmissionResult? submissionResult;

  bool get hasDisplayLecture =>
      submissionResult == null &&
      currentLecture != null &&
      (error == null ||
          isLectureStale ||
          phase == AttendancePhase.fetchingLecture);

  AttendanceState copyWith({
    Lecture? currentLecture,
    AttendancePhase? phase,
    bool? hasCheckedLecture,
    String? error,
    bool? isLectureStale,
    DateTime? retryNotBefore,
    bool clearSubmissionResult = false,
  }) {
    return AttendanceState(
      currentLecture: currentLecture ?? this.currentLecture,
      phase: phase ?? this.phase,
      hasCheckedLecture: hasCheckedLecture ?? this.hasCheckedLecture,
      error: error,
      sessionExpired: sessionExpired,
      retryNotBefore: retryNotBefore ?? this.retryNotBefore,
      isLectureStale: isLectureStale ?? this.isLectureStale,
      submissionResult: clearSubmissionResult ? null : submissionResult,
    );
  }
}

@Riverpod(name: 'attendanceProvider', keepAlive: true)
class AttendanceController extends _$AttendanceController {
  AttendanceController({
    DateTime Function()? now,
    Future<Position> Function()? locationProvider,
  }) : _now = now ?? DateTime.now,
       _locationProvider = locationProvider;

  static const lectureCacheValidity = Duration(seconds: 15);
  static const ssoRetryDelay = Duration(seconds: 30);
  static const silentRecoveryWindow = Duration(minutes: 1);
  static const locationTimeout = Duration(seconds: 10);
  static const locationPermissionTimeout = Duration(seconds: 30);

  final DateTime Function() _now;
  final Future<Position> Function()? _locationProvider;
  late final AttendanceService _attendanceService;
  Future<void>? _lectureFetchInFlight;
  DateTime? _lastSuccessfulLectureFetchAt;
  DateTime? _transientFailureSince;
  Timer? _recoveryNoticeTimer;
  static const connectionDelayMessage = '학교 연결이 지연되고 있어요. 잠시 후 다시 확인해 주세요.';
  ({Lecture lecture, AttendanceSubmissionResult result})? _unconfirmedAttempt;
  bool _submissionNeedsRecovery = false;
  int _submissionRevision = 0;

  int get submissionRevision => _submissionRevision;
  bool get hasActiveSubmission =>
      state.phase == AttendancePhase.enteringCode ||
      state.phase == AttendancePhase.locating ||
      state.phase == AttendancePhase.submitting;

  Duration get lectureRetryDelay =>
      state.retryNotBefore?.difference(_now()) ?? Duration.zero;

  // 세션의 세대 (로그인할 때마다 증가)
  int _sessionGeneration = 0;
  int _requestSequence = 0;

  @override
  AttendanceState build() {
    _attendanceService = AttendanceService(
      ref.watch(attendanceTransportProvider),
    );
    ref.onDispose(() => _recoveryNoticeTimer?.cancel());
    return const AttendanceState();
  }

  /// 세션 초기화.
  ///
  /// 이전 요청 작업을 무시하도록 한다.
  void resetSession() {
    _sessionGeneration++;
    _lectureFetchInFlight = null;
    _lastSuccessfulLectureFetchAt = null;
    _clearRecoveryNotice();
    _unconfirmedAttempt = null;
    _submissionNeedsRecovery = false;
    state = const AttendanceState();
  }

  /// 세션의 세대가 동일한지 체크.
  bool _isCurrentSession(int generation) =>
      ref.mounted && generation == _sessionGeneration;

  void _clearRecoveryNotice() {
    _recoveryNoticeTimer?.cancel();
    _recoveryNoticeTimer = null;
    _transientFailureSince = null;
  }

  void _startRecoveryNotice() {
    _transientFailureSince ??= _now();
    if (_recoveryNoticeTimer != null) return;
    final remaining =
        silentRecoveryWindow - _now().difference(_transientFailureSince!);
    if (remaining <= Duration.zero) return;
    final generation = _sessionGeneration;
    _recoveryNoticeTimer = Timer(remaining, () {
      _recoveryNoticeTimer = null;
      if (!_isCurrentSession(generation) || _transientFailureSince == null) {
        return;
      }
      state = state.copyWith(error: connectionDelayMessage);
    });
  }

  /// Keep the account and existing data while attendance cannot be verified.
  void markSessionUnverified() {
    if (hasActiveSubmission) return;
    _startRecoveryNotice();
    final retryAt = _now().add(ssoRetryDelay);
    state = state.copyWith(
      isLectureStale: true,
      hasCheckedLecture: true,
      retryNotBefore:
          state.retryNotBefore != null && state.retryNotBefore!.isAfter(retryAt)
          ? state.retryNotBefore
          : retryAt,
      error: _now().difference(_transientFailureSince!) < silentRecoveryWindow
          ? null
          : connectionDelayMessage,
    );
  }

  /// 강의 불러오기.
  ///
  /// 중복 패킷 전송을 방지한다.
  Future<void> fetchLecture({
    bool forceRefresh = false,
    bool isAutomatic = false,
  }) {
    if (!ref.read(homeControllerProvider).isLoggedIn) return Future.value();
    final activeRequest = _lectureFetchInFlight;
    if (activeRequest != null) {
      return activeRequest;
    }
    if (state.isBusy) return Future.value();
    if (isAutomatic &&
        (state.sessionExpired ||
            (state.retryNotBefore?.isAfter(_now()) ?? false))) {
      return Future.value();
    }
    if (!forceRefresh && _hasFreshLectureResult()) {
      return Future.value();
    }

    final request = _fetchLecture(isAutomatic: isAutomatic);
    _lectureFetchInFlight = request;
    return request.whenComplete(() {
      if (identical(_lectureFetchInFlight, request)) {
        _lectureFetchInFlight = null;
      }
    });
  }

  Future<void> _fetchLecture({required bool isAutomatic}) async {
    final generation = _sessionGeneration;
    final previous = state;
    state = state.copyWith(
      phase: AttendancePhase.fetchingLecture,
      error: previous.isLectureStale ? previous.error : null,
    );

    try {
      final recoveryAlreadyRequested = _submissionNeedsRecovery;
      SessionRecoveryResult? recovery;
      _submissionNeedsRecovery = false;
      if (recoveryAlreadyRequested) {
        recovery = await ref
            .read(homeControllerProvider.notifier)
            .recoverAttendanceSession();
        if (!_isCurrentSession(generation)) return;
      }
      var result = await _attendanceService.getActiveLecture(
        isAutomatic: isAutomatic,
      );
      if (!_isCurrentSession(generation)) return;
      if (result.ssoIntegrationError || result.transient) {
        state = state.copyWith(isLectureStale: true, error: state.error);
        _startRecoveryNotice();
      }
      if (!recoveryAlreadyRequested &&
          (result.sessionExpired || result.ssoIntegrationError)) {
        recovery = await ref
            .read(homeControllerProvider.notifier)
            .recoverAttendanceSession();
        if (!_isCurrentSession(generation)) return;
        if (recovery.isRestored) {
          result = await _attendanceService.getActiveLecture(
            isAutomatic: isAutomatic,
          );
          if (!_isCurrentSession(generation)) return;
        }
      }
      switch (result.status) {
        case LectureFetchStatus.success:
        case LectureFetchStatus.empty:
          _clearRecoveryNotice();
          ref.read(homeControllerProvider.notifier).confirmAttendanceSession();
          _lastSuccessfulLectureFetchAt = _now();
          state = AttendanceState(
            currentLecture: result.lecture,
            hasCheckedLecture: true,
            submissionResult: state.submissionResult,
          );
          break;
        case LectureFetchStatus.failure:
          final transient =
              result.ssoIntegrationError ||
              result.transient ||
              (result.sessionExpired &&
                  recovery == SessionRecoveryResult.temporarilyUnavailable);
          final afterSubmission = previous.submissionResult != null;
          final retainPrevious =
              transient && _lastSuccessfulLectureFetchAt != null;
          if (transient) {
            _startRecoveryNotice();
          } else {
            _clearRecoveryNotice();
          }
          final suppressError =
              transient &&
              _now().difference(_transientFailureSince!) < silentRecoveryWindow;
          final serverRetryAt = _parseRetryAfter(result.retryAfter);
          final cooldown = transient ? _now().add(ssoRetryDelay) : null;
          state = AttendanceState(
            currentLecture: retainPrevious ? previous.currentLecture : null,
            isLectureStale: transient || afterSubmission,
            submissionResult: state.submissionResult,
            error: suppressError
                ? null
                : transient
                ? connectionDelayMessage
                : result.message,
            hasCheckedLecture: true,
            sessionExpired: result.sessionExpired && !transient,
            retryNotBefore: serverRetryAt == null
                ? cooldown
                : cooldown != null && cooldown.isAfter(serverRetryAt)
                ? cooldown
                : serverRetryAt,
          );
          break;
      }
    } catch (e, stack) {
      if (!_isCurrentSession(generation)) return;
      _clearRecoveryNotice();
      state = state.copyWith(
        phase: AttendancePhase.idle,
        hasCheckedLecture: true,
        error: '수업 정보를 불러오지 못했어요.',
      );
      logMsg(
        '수업을 불러오는 중 오류가 발생했습니다: $e',
        level: LogLevel.error,
        error: e,
        stackTrace: stack,
      );
    }
  }

  /// End only this flow's notice without discarding a newer lecture query.
  void finishAttendanceFlow(int revision) {
    if (!ref.mounted ||
        revision != _submissionRevision ||
        state.submissionResult == null) {
      return;
    }
    state = state.copyWith(error: state.error, clearSubmissionResult: true);
    if (ref.read(homeControllerProvider).loginStatus == LoginStatus.expired) {
      unawaited(
        ref.read(homeControllerProvider.notifier).requestSessionLogin(),
      );
    }
  }

  Future<void> refreshLectureForInput() async {
    final generation = _sessionGeneration;
    await fetchLecture(forceRefresh: true);
    if (!_isCurrentSession(generation) ||
        state.isBusy ||
        state.error != null ||
        state.isLectureStale ||
        !state.hasCheckedLecture) {
      return;
    }
    state = AttendanceState(
      currentLecture: state.currentLecture,
      hasCheckedLecture: true,
    );
  }

  DateTime? _parseRetryAfter(String? value) {
    if (value == null) return null;
    final now = _now();
    final seconds = int.tryParse(value.trim());
    if (seconds != null) {
      return seconds > 0 ? now.add(Duration(seconds: seconds)) : null;
    }
    try {
      final date = HttpDate.parse(value);
      return date.isAfter(now) ? date : null;
    } on HttpException {
      return null;
    } on FormatException {
      return null;
    }
  }

  bool _hasFreshLectureResult() {
    final fetchedAt = _lastSuccessfulLectureFetchAt;
    if (fetchedAt == null || state.error != null || state.isLectureStale) {
      return false;
    }
    final age = _now().difference(fetchedAt);
    return !age.isNegative && age <= lectureCacheValidity;
  }

  /// 사용자의 현재 위치 좌표를 불러옴.
  Future<Position> getUsersLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled().timeout(
      locationTimeout,
      onTimeout: _throwLocationTimeout,
    );
    if (!serviceEnabled) {
      throw Exception('위치 서비스가 꺼져 있어요.');
    }

    var permission = await Geolocator.checkPermission().timeout(
      locationTimeout,
      onTimeout: _throwLocationTimeout,
    );
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission().timeout(
        locationPermissionTimeout,
        onTimeout: () => throw Exception(
          '위치 권한 확인 시간이 초과됐어요. 브라우저 또는 기기에서 위치 권한을 허용한 뒤 다시 시도해 주세요.',
        ),
      );
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
          timeLimit: locationTimeout,
        ),
      ).timeout(locationTimeout);
      return position;
    } on TimeoutException {
      _throwLocationTimeout();
    } catch (e, stack) {
      logMsg(
        '위치 가져오기 실패: $e',
        level: LogLevel.warning,
        error: e,
        stackTrace: stack,
      );
      throw Exception('위치를 가져오지 못했어요. 기기의 GPS가 켜져 있는지 확인해 주세요.');
    }
  }

  Never _throwLocationTimeout() {
    throw Exception('위치 확인 시간이 초과됐어요. 위치 서비스를 확인한 뒤 다시 시도해 주세요.');
  }

  /// 출석 번호를 제출.
  ///
  /// [requestAuthCode]를 제출한다.
  /// [canContinue]로 로그아웃, 계정 전환, 화면 종료 여부를 확인한다.
  Future<AttendanceSubmissionResult?> performAttendance({
    required Future<String?> Function() requestAuthCode,
    required bool Function() canContinue,
    String? userId,
    Future<bool> Function(AttendanceSubmissionResult previousResult)?
    confirmUnconfirmedRetry,
  }) async {
    if (state.isBusy ||
        state.submissionResult != null ||
        state.error != null ||
        state.isLectureStale ||
        state.currentLecture == null ||
        !canContinue()) {
      return null;
    }
    final lecture = state.currentLecture!;
    final generation = _sessionGeneration;
    _submissionRevision++;
    var submitted = false;
    AttendanceRequestRecord? record;
    AttendanceHistoryRepository? history;
    state = state.copyWith(phase: AttendancePhase.enteringCode);
    try {
      final previousAttempt = _unconfirmedAttempt;
      if (previousAttempt != null &&
          previousAttempt.lecture.name == lecture.name &&
          previousAttempt.lecture.time == lecture.time &&
          mapEquals(
            previousAttempt.lecture.attendanceParams,
            lecture.attendanceParams,
          )) {
        final confirmed =
            await confirmUnconfirmedRetry?.call(previousAttempt.result) ??
            false;
        if (!_isCurrentSession(generation) || !canContinue() || !confirmed) {
          return null;
        }
      }
      final authCode = await requestAuthCode();
      if (!_isCurrentSession(generation) ||
          !canContinue() ||
          authCode == null ||
          authCode.isEmpty) {
        return null;
      }
      state = state.copyWith(phase: AttendancePhase.locating);
      final position =
          await (_locationProvider ??
              ref
                  .read(attendanceDataSourceOverrideProvider)
                  ?.locationProvider ??
              getUsersLocation)();
      if (!_isCurrentSession(generation) || !canContinue()) return null;
      state = state.copyWith(phase: AttendancePhase.submitting);
      submitted = true;
      if (userId != null &&
          userId.isNotEmpty &&
          lecture.attendanceParams.isNotEmpty) {
        final requestedAt = _now().toUtc();
        record = AttendanceRequestRecord(
          id: '${requestedAt.microsecondsSinceEpoch}-${_requestSequence++}',
          lectureName: lecture.name,
          requestedAt: requestedAt,
          authCode: authCode,
          courseKey: AttendanceCourseKey.fromParams(lecture.attendanceParams),
        );
        final repository = ref.read(attendanceHistoryRepositoryProvider);
        history = repository;
        unawaited(_saveRecord(repository, userId, record));
      }
      final result = await _attendanceService.submitAttendance(
        lecture,
        authCode,
        position.latitude.toString(),
        position.longitude.toString(),
      );
      if (_isCurrentSession(generation)) {
        _lastSuccessfulLectureFetchAt = null;
        _clearRecoveryNotice();
        state = AttendanceState(
          phase: AttendancePhase.submitting,
          hasCheckedLecture: true,
          isLectureStale: true,
          submissionResult: result,
        );
        _submissionNeedsRecovery = result.needsSessionRecovery;
        _unconfirmedAttempt = result.isUnconfirmed
            ? (lecture: lecture, result: result)
            : null;
      }
      if (history != null && record != null && userId != null) {
        unawaited(_saveRecord(history, userId, record.withResult(result)));
      }
      return _isCurrentSession(generation) && canContinue() ? result : null;
    } catch (_) {
      if (!_isCurrentSession(generation)) return null;
      rethrow;
    } finally {
      if (_isCurrentSession(generation)) {
        state = state.copyWith(phase: AttendancePhase.idle);
        if (submitted && canContinue()) {
          unawaited(fetchLecture(forceRefresh: true));
        }
      }
    }
  }

  Future<void> _saveRecord(
    AttendanceHistoryRepository history,
    String userId,
    AttendanceRequestRecord record,
  ) async {
    try {
      await history.save(userId, record);
    } catch (e, stack) {
      logMsg(
        '출결 요청 기록을 저장하지 못했어요.',
        level: LogLevel.error,
        error: e,
        stackTrace: stack,
      );
    } finally {
      if (ref.mounted) ref.invalidate(attendanceHistoryProvider(userId));
    }
  }
}
