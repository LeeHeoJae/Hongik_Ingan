import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hongik_ingan/core/app_config.dart';
import 'package:hongik_ingan/core/logging/logger.dart';
import 'package:hongik_ingan/core/network/school_transport.dart';
import 'package:hongik_ingan/core/network/school_transport_provider.dart';
import 'package:hongik_ingan/core/user_dao.dart';
import 'package:hongik_ingan/features/attendance/application/attendance_controller.dart';
import 'package:hongik_ingan/features/home/data/auth_service.dart';
import 'package:hongik_ingan/features/home/domain/session_status.dart';
import 'package:hongik_ingan/features/home/domain/login_result.dart';
import 'package:hongik_ingan/features/home/domain/session_recovery_result.dart';
import 'package:hongik_ingan/features/update/check_update.dart';
import 'package:hongik_ingan/features/update/domain/update_check_result.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'home_controller.g.dart';

enum LoginStatus {
  required,
  checkingSession,
  loggingIn,
  automaticLogin,
  recoveringSession,
  failed,
  expired,
  verificationFailed,
}

@immutable
class HomeState {
  const HomeState({
    this.isLoggedIn = false,
    this.loginStatus = LoginStatus.required,
    this.statusMessage = '서비스를 이용하려면 로그인해 주세요.',
    this.rememberMe = false,
    this.autoLogin = false,
    this.userId,
    this.recoveryPhase = SessionRecoveryPhase.idle,
    this.updateCheck = const UpdateCheckResult.idle(),
  });

  bool get isLoading => switch (loginStatus) {
    LoginStatus.checkingSession ||
    LoginStatus.loggingIn ||
    LoginStatus.automaticLogin ||
    LoginStatus.recoveringSession => true,
    _ => false,
  };

  final bool isLoggedIn;
  final LoginStatus loginStatus;
  final String statusMessage;
  final bool rememberMe;
  final bool autoLogin;
  final String? userId;
  final SessionRecoveryPhase recoveryPhase;
  final UpdateCheckResult updateCheck;

  HomeState copyWith({
    bool? isLoggedIn,
    LoginStatus? loginStatus,
    String? statusMessage,
    bool? rememberMe,
    bool? autoLogin,
    String? userId,
    SessionRecoveryPhase? recoveryPhase,
    UpdateCheckResult? updateCheck,
  }) {
    return HomeState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      loginStatus: loginStatus ?? this.loginStatus,
      statusMessage: statusMessage ?? this.statusMessage,
      rememberMe: rememberMe ?? this.rememberMe,
      autoLogin: autoLogin ?? this.autoLogin,
      userId: userId ?? this.userId,
      recoveryPhase: recoveryPhase ?? this.recoveryPhase,
      updateCheck: updateCheck ?? this.updateCheck,
    );
  }
}

@Riverpod(keepAlive: true)
class HomeController extends _$HomeController {
  HomeController({
    AppConfig? appConfig,
    UserDao? userDao,
    Future<UpdateCheckResult> Function()? updateChecker,
    DateTime Function()? now,
  }) : _appConfig = appConfig ?? AppConfig(),
       _userDao = userDao ?? UserDao(),
       _checkUpdate = updateChecker ?? checkUpdate,
       _now = now ?? DateTime.now;

  late final SchoolTransport _transport;
  late final AuthService _authService;
  final AppConfig _appConfig;
  final UserDao _userDao;
  final Future<UpdateCheckResult> Function() _checkUpdate;
  final DateTime Function() _now;
  Timer? _updateInfoTimer;
  var _updateInfoStarted = false;
  int _authGeneration = 0;
  Future<SessionRecoveryResult>? _sessionRecoveryInFlight;
  Future<void> _credentialOperations = Future.value();
  int _credentialRevision = 0;
  (String, String)? _sessionCredentials;
  int _automaticReloginAttempts = 0;
  DateTime? _automaticReloginRetryAt;
  static const automaticReloginRetryInterval = Duration(seconds: 60);

  DateTime? get automaticReloginRetryAt => _automaticReloginRetryAt;

  void _resetAutomaticRelogin() {
    _automaticReloginAttempts = 0;
    _automaticReloginRetryAt = null;
  }

  @override
  HomeState build() {
    _transport = ref.watch(schoolTransportProvider);
    _authService = AuthService(_transport);
    ref.onDispose(() {
      _updateInfoTimer?.cancel();
      _sessionCredentials = null;
    });
    // 로그인 여부나 사용자 ID가 변경되면 출결 상태 초기화
    listenSelf((previous, next) {
      if (previous != null &&
          (previous.isLoggedIn != next.isLoggedIn ||
              previous.userId != next.userId)) {
        if (!next.isLoggedIn ||
            _sessionCredentials?.$1.toUpperCase() !=
                next.userId?.toUpperCase()) {
          _sessionCredentials = null;
        }
        if (!next.isLoggedIn || previous.userId != next.userId) {
          _resetAutomaticRelogin();
        }
        ref.read(attendanceProvider.notifier).resetSession();
      }
    });

    return HomeState(
      rememberMe: _appConfig.rememberMe,
      autoLogin: _appConfig.autoLogin,
      userId: _appConfig.savedId,
    );
  }

  Future<(String?, String?)> initializeApp() async {
    await _appConfig.init();
    if (!ref.mounted) return (null, null);
    state = state.copyWith(
      rememberMe: _appConfig.rememberMe,
      autoLogin: _appConfig.autoLogin,
      userId: _appConfig.savedId,
    );

    return (_appConfig.savedId, _appConfig.savedPw);
  }

  Future<void> restoreInitialSession(String id, String pw) async {
    if (!ref.mounted) return;
    if (state.autoLogin) {
      await restoreSessionOrLogin(id, pw);
    } else {
      scheduleUpdateCheck();
    }
  }

  /// 앱 시작 시 저장된 인증 정보를 이용해 초기 로그인 상태를 결정.
  Future<void> restoreSessionOrLogin(String id, String pw) async {
    _sessionRecoveryInFlight = null;
    _sessionCredentials = null;
    _resetAutomaticRelogin();
    final generation = ++_authGeneration;
    state = state.copyWith(
      loginStatus: LoginStatus.checkingSession,
      statusMessage: '저장된 로그인 정보를 확인하고 있어요.',
      recoveryPhase: SessionRecoveryPhase.idle,
      userId: id.isEmpty ? state.userId : id,
    );
    final hasCookies = await _transport.hasAuthSession();
    if (!ref.mounted || generation != _authGeneration) return;
    if (hasCookies) {
      final status = await _authService.checkSessionStatus();
      if (!ref.mounted || generation != _authGeneration) return;
      switch (status) {
        case SessionStatus.valid:
          state = state.copyWith(
            isLoggedIn: true,
            loginStatus: LoginStatus.required,
            statusMessage: '저장된 세션으로 로그인했어요.',
            userId: id.isEmpty ? state.userId : id,
          );
          _prefetchLecture();
          scheduleUpdateCheck(delay: const Duration(seconds: 2));
          return;
        case SessionStatus.expired:
        case SessionStatus.integrationError:
          final recovered = await _shareSessionRecovery(
            _recoverAttendanceSession(
              resumeCredentials: (id, pw),
              startingUp: true,
            ),
          );
          if (!ref.mounted || generation != _authGeneration) return;
          if (recovered.isRestored || _automaticReloginRetryAt != null) {
            // Keep the saved account context while a transport retry is pending.
            state = state.copyWith(
              isLoggedIn: true,
              loginStatus: LoginStatus.required,
            );
            ref
                .read(attendanceProvider.notifier)
                .markSessionUnverified(
                  retryNotBefore: _automaticReloginRetryAt,
                );
            if (recovered.isRestored) _prefetchLecture();
            scheduleUpdateCheck(delay: const Duration(seconds: 2));
            return;
          }
          final expiredWithoutCredentials =
              status == SessionStatus.expired &&
              state.recoveryPhase ==
                  SessionRecoveryPhase.credentialsUnavailable;
          if (expiredWithoutCredentials) await _transport.clearAuthSession();
          if (!ref.mounted || generation != _authGeneration) return;
          state = state.copyWith(
            isLoggedIn: false,
            loginStatus: expiredWithoutCredentials
                ? LoginStatus.expired
                : LoginStatus.verificationFailed,
            statusMessage: state.recoveryPhase.message ?? '학교 연결을 복구하지 못했어요.',
          );
          return;
        case SessionStatus.unknown:
          state = state.copyWith(
            isLoggedIn: false,
            loginStatus: LoginStatus.verificationFailed,
            statusMessage: '로그인 상태를 확인하지 못했어요. 네트워크 연결을 확인해 주세요.',
          );
          return;
      }
    }
    if (!ref.mounted || generation != _authGeneration) return;

    if (state.rememberMe && id.isNotEmpty && pw.isNotEmpty) {
      await _login(id, pw, automatic: true);
      return;
    }

    state = state.copyWith(
      isLoggedIn: false,
      loginStatus: hasCookies ? LoginStatus.expired : LoginStatus.required,
      statusMessage: hasCookies
          ? '세션이 만료됐어요. 다시 로그인해 주세요.'
          : '서비스를 이용하려면 로그인해 주세요.',
    );
    scheduleUpdateCheck();
  }

  /// 업데이트 체크를 스케줄링.
  ///
  /// 로그인에 비해 중요도가 낮기 때문에 로그인 중에는 업데이트 체크를 뒤로 미룬다.
  void scheduleUpdateCheck({Duration delay = const Duration(seconds: 8)}) {
    if (kIsWeb || _updateInfoStarted) return;

    _updateInfoTimer?.cancel();
    _updateInfoTimer = Timer(delay, () {
      unawaited(fetchUpdateInfo());
    });
  }

  /// 업데이트 체크.
  Future<void> fetchUpdateInfo({bool userInitiated = false}) async {
    if (kIsWeb || state.updateCheck.status == UpdateCheckStatus.checking) {
      return;
    }
    if (state.isLoading && !userInitiated) {
      scheduleUpdateCheck(delay: const Duration(seconds: 4));
      return;
    }

    _updateInfoStarted = true;
    _updateInfoTimer?.cancel();
    state = state.copyWith(updateCheck: const UpdateCheckResult.checking());
    try {
      final result = await _checkUpdate();
      if (!ref.mounted) return;
      state = state.copyWith(updateCheck: result);
    } catch (_) {
      if (!ref.mounted) return;
      state = state.copyWith(updateCheck: const UpdateCheckResult.failed());
    }
  }

  /// 로그인된 앱이 포그라운드로 복귀할 때 현재 세션을 재검증.
  Future<void> revalidateSessionOnResume(String id, String pw) {
    final active = _sessionRecoveryInFlight;
    if (active != null) return active.then((_) {});
    if (state.isLoading ||
        !state.isLoggedIn ||
        ref.read(attendanceProvider.notifier).hasActiveSubmission ||
        ref.read(attendanceProvider.notifier).lectureRetryDelay >
            Duration.zero) {
      return Future.value();
    }
    final request = _revalidateSessionOnResume(id, pw);
    return _shareSessionRecovery(request).then((_) {});
  }

  Future<SessionRecoveryResult> _revalidateSessionOnResume(
    String id,
    String pw,
  ) async {
    final generation = _authGeneration;
    final attendance = ref.read(attendanceProvider.notifier);
    final submissionRevision = attendance.submissionRevision;
    bool canApplyResult() =>
        ref.mounted &&
        generation == _authGeneration &&
        !attendance.hasActiveSubmission &&
        submissionRevision == attendance.submissionRevision;
    final status = await _authService.checkSessionStatus();
    // A foreground check must not invalidate attendance that began meanwhile.
    if (!canApplyResult()) return SessionRecoveryResult.cancelled;
    switch (status) {
      case SessionStatus.valid:
        state = state.copyWith(
          isLoggedIn: true,
          loginStatus: LoginStatus.required,
          statusMessage: '세션이 아직 유효해요.',
          recoveryPhase: SessionRecoveryPhase.verifyingLecture,
        );
        _prefetchLecture();
        scheduleUpdateCheck(delay: const Duration(seconds: 2));
        return SessionRecoveryResult.restored;
      case SessionStatus.integrationError:
      case SessionStatus.expired:
        attendance.markSessionUnverified();
        final result = await _recoverAttendanceSession(
          resumeCredentials: (id, pw),
          canApplyResult: canApplyResult,
        );
        if (!canApplyResult()) return result;
        if (result.isRestored) {
          state = state.copyWith(
            recoveryPhase: SessionRecoveryPhase.verifyingLecture,
          );
          _prefetchLecture();
          scheduleUpdateCheck(delay: const Duration(seconds: 2));
        }
        return result;
      case SessionStatus.unknown:
        attendance.markSessionUnverified();
        state = state.copyWith(
          loginStatus: LoginStatus.required,
          recoveryPhase: SessionRecoveryPhase.unavailable,
        );
        return SessionRecoveryResult.temporarilyUnavailable;
    }
  }

  /// Share recovery with concurrent lecture requests and foreground checks.
  Future<SessionRecoveryResult> recoverAttendanceSession() {
    final active = _sessionRecoveryInFlight;
    if (active != null) return active;
    if (!state.isLoggedIn || state.isLoading) {
      return Future.value(SessionRecoveryResult.cancelled);
    }
    return _shareSessionRecovery(_recoverAttendanceSession());
  }

  Future<SessionRecoveryResult> _shareSessionRecovery(
    Future<SessionRecoveryResult> request,
  ) {
    late final Future<SessionRecoveryResult> shared;
    shared = request.whenComplete(() {
      if (identical(_sessionRecoveryInFlight, shared)) {
        _sessionRecoveryInFlight = null;
      }
    });
    _sessionRecoveryInFlight = shared;
    return shared;
  }

  Future<SessionRecoveryResult> _recoverAttendanceSession({
    (String, String)? resumeCredentials,
    bool Function()? canApplyResult,
    bool startingUp = false,
  }) async {
    final generation = _authGeneration;
    final userId = state.userId;
    bool canContinue() =>
        ref.mounted &&
        generation == _authGeneration &&
        (state.isLoggedIn || startingUp) &&
        (canApplyResult?.call() ?? true);
    final previousPhase = state.recoveryPhase;
    String? reauthenticationPassword;
    String usePassword(String password) {
      reauthenticationPassword = password;
      return password;
    }

    ref.read(attendanceProvider.notifier).markSessionUnverified();
    String? noPassword(String reason) {
      logMsg(
        'attendance recovery credentialsUnavailable reason=$reason',
        level: LogLevel.info,
      );
      state = state.copyWith(
        recoveryPhase: SessionRecoveryPhase.credentialsUnavailable,
      );
      return null;
    }

    state = state.copyWith(
      loginStatus: LoginStatus.recoveringSession,
      recoveryPhase: SessionRecoveryPhase.restoringSession,
    );
    try {
      final recovered = await _authService.recoverAttendanceSession(
        studentId: userId,
        readPassword: () async {
          if (!canContinue()) return null;
          if (_automaticReloginAttempts > 0 &&
              (_automaticReloginAttempts >= 2 ||
                  _automaticReloginRetryAt == null ||
                  _now().isBefore(_automaticReloginRetryAt!))) {
            logMsg(
              'attendance recovery reauthenticationSkipped reason=alreadyAttempted',
              level: LogLevel.info,
            );
            state = state.copyWith(
              recoveryPhase:
                  previousPhase == SessionRecoveryPhase.credentialsRejected
                  ? previousPhase
                  : SessionRecoveryPhase.unavailable,
            );
            return null;
          }
          final sessionCredentials = _sessionCredentials;
          if (sessionCredentials != null &&
              sessionCredentials.$1.toUpperCase() == userId?.toUpperCase()) {
            return usePassword(sessionCredentials.$2);
          }
          if (!state.rememberMe || !state.autoLogin) {
            return noPassword('automaticLoginDisabled');
          }
          if (resumeCredentials case final credentials?) {
            final password =
                credentials.$1.toUpperCase() == userId?.toUpperCase()
                ? credentials.$2
                : null;
            if (password == null || password.isEmpty) {
              return noPassword('missingOrMismatchedResumeCredentials');
            }
            return usePassword(password);
          }
          (String?, String?) credentials = (null, null);
          final loaded = await _queueCredentialOperation(() async {
            if (canContinue() && state.rememberMe && state.autoLogin) {
              credentials = await _userDao.load();
            }
          });
          if (!canContinue() || !state.rememberMe || !state.autoLogin) {
            return null;
          }
          if (!loaded) return noPassword('storageUnavailable');
          final password =
              credentials.$1?.toUpperCase() == userId?.toUpperCase()
              ? credentials.$2
              : null;
          if (password == null || password.isEmpty) {
            return noPassword(
              credentials.$1?.toUpperCase() != userId?.toUpperCase()
                  ? 'missingOrMismatchedStoredAccount'
                  : 'missingStoredPassword',
            );
          }
          return usePassword(password);
        },
        onReauthenticate: () {
          _automaticReloginAttempts++;
          _automaticReloginRetryAt = null;
          state = state.copyWith(recoveryPhase: SessionRecoveryPhase.loggingIn);
        },
        canContinue: canContinue,
      );
      if (!canContinue()) return SessionRecoveryResult.cancelled;
      if (recovered.isRestored) {
        if (reauthenticationPassword != null && userId != null) {
          _sessionCredentials = (userId, reauthenticationPassword!);
        }
        state = state.copyWith(
          recoveryPhase: SessionRecoveryPhase.verifyingLecture,
        );
        return recovered;
      }
      if (recovered == SessionRecoveryResult.cancelled) {
        state = state.copyWith(recoveryPhase: previousPhase);
        return recovered;
      }
      if (recovered == SessionRecoveryResult.retryableFailure &&
          _automaticReloginAttempts < 2) {
        _automaticReloginRetryAt = _now().add(automaticReloginRetryInterval);
      }
      if (recovered == SessionRecoveryResult.loginRequired &&
          state.recoveryPhase == SessionRecoveryPhase.loggingIn) {
        _sessionCredentials = null;
        state = state.copyWith(
          recoveryPhase: SessionRecoveryPhase.credentialsRejected,
        );
      } else if (state.recoveryPhase !=
              SessionRecoveryPhase.credentialsUnavailable &&
          state.recoveryPhase != SessionRecoveryPhase.credentialsRejected) {
        state = state.copyWith(recoveryPhase: SessionRecoveryPhase.unavailable);
      }
      ref
          .read(attendanceProvider.notifier)
          .markSessionUnverified(retryNotBefore: _automaticReloginRetryAt);
      return SessionRecoveryResult.temporarilyUnavailable;
    } catch (_) {
      if (!canContinue()) return SessionRecoveryResult.cancelled;
      state = state.copyWith(recoveryPhase: SessionRecoveryPhase.unavailable);
      ref.read(attendanceProvider.notifier).markSessionUnverified();
      return SessionRecoveryResult.temporarilyUnavailable;
    } finally {
      if (ref.mounted &&
          generation == _authGeneration &&
          (state.isLoggedIn || startingUp)) {
        state = state.copyWith(
          loginStatus: LoginStatus.required,
          recoveryPhase: !canContinue() ? previousPhase : state.recoveryPhase,
        );
      }
    }
  }

  Future<void> requestSessionLogin() async {
    _sessionCredentials = null;
    _resetAutomaticRelogin();
    _sessionRecoveryInFlight = null;
    _authGeneration++;
    state = state.copyWith(
      isLoggedIn: false,
      loginStatus: LoginStatus.expired,
      statusMessage: '다시 로그인해 주세요.',
      recoveryPhase: SessionRecoveryPhase.idle,
    );
    await _transport.clearAuthSession();
  }

  void confirmAttendanceSession() {
    if (state.isLoggedIn) {
      _resetAutomaticRelogin();
      if (state.recoveryPhase != SessionRecoveryPhase.idle) {
        state = state.copyWith(recoveryPhase: SessionRecoveryPhase.idle);
      }
    }
  }

  void markAttendanceRecoveryUnavailable() {
    if (state.recoveryPhase == SessionRecoveryPhase.verifyingLecture) {
      state = state.copyWith(recoveryPhase: SessionRecoveryPhase.unavailable);
    }
  }

  /// 로그인 시도
  Future<LoginResult> login(String id, String pw) => _login(id, pw);

  Future<LoginResult> _login(
    String id,
    String pw, {
    bool automatic = false,
  }) async {
    if (id.isEmpty || pw.isEmpty) {
      return const LoginResult.failure(
        LoginFailureKind.invalidInput,
        '학번과 비밀번호를 모두 입력해 주세요.',
      );
    }
    _sessionRecoveryInFlight = null;
    _sessionCredentials = null;
    _resetAutomaticRelogin();
    _updateInfoTimer?.cancel();
    final generation = ++_authGeneration;
    ref.read(attendanceProvider.notifier).resetSession();
    state = state.copyWith(
      isLoggedIn: false,
      loginStatus: automatic
          ? LoginStatus.automaticLogin
          : LoginStatus.loggingIn,
      statusMessage: automatic ? '자동으로 로그인하고 있어요.' : '홍대 서버와 보안 통신 중...',
      recoveryPhase: SessionRecoveryPhase.idle,
    );
    final result = await _authService.login(
      id,
      pw,
      canContinue: () => ref.mounted && generation == _authGeneration,
    );
    if (!ref.mounted || generation != _authGeneration) {
      return const LoginResult.cancelled();
    }
    if (result.isSuccess) {
      final saved = await _queueCredentialOperation(() async {
        if (!ref.mounted ||
            generation != _authGeneration ||
            !state.rememberMe) {
          return;
        }
        try {
          await _userDao.save(id, pw);
        } catch (_) {
          _appConfig.clearSavedCredentials();
          await _userDao.delete();
          rethrow;
        }
      });
      if (!ref.mounted || generation != _authGeneration) {
        return const LoginResult.cancelled();
      }
      _sessionCredentials = (id, pw);
      state = state.copyWith(
        isLoggedIn: true,
        loginStatus: LoginStatus.required,
        recoveryPhase: SessionRecoveryPhase.verifyingLecture,
        statusMessage: saved
            ? '로그인했어요. 세션을 활성화했어요.'
            : '로그인했지만 로그인 정보 저장에 실패했어요.',
        userId: id,
      );
      _prefetchLecture();
      scheduleUpdateCheck(delay: const Duration(seconds: 2));
    } else {
      state = state.copyWith(
        isLoggedIn: false,
        loginStatus: LoginStatus.failed,
        statusMessage: result.displayMessage,
      );
      scheduleUpdateCheck();
    }
    return result;
  }

  void _prefetchLecture() {
    unawaited(
      ref.read(attendanceProvider.notifier).fetchLecture(forceRefresh: true),
    );
  }

  Future<void> onRememberMeChanged(bool value) {
    if (!value) {
      _appConfig.clearSavedCredentials();
      state = state.copyWith(rememberMe: value, autoLogin: false);
    } else {
      state = state.copyWith(rememberMe: value);
    }
    return _persistCredentialSettings(
      rememberMe: state.rememberMe,
      autoLogin: state.autoLogin,
    );
  }

  Future<void> onAutoLoginChanged(bool value) {
    if (value) {
      state = state.copyWith(autoLogin: value, rememberMe: true);
    } else {
      state = state.copyWith(autoLogin: value);
    }
    return _persistCredentialSettings(
      rememberMe: state.rememberMe,
      autoLogin: state.autoLogin,
    );
  }

  Future<bool> _queueCredentialOperation(Future<void> Function() operation) {
    final result = _credentialOperations.then((_) async {
      try {
        await operation();
        return true;
      } catch (error, stack) {
        // Storage exceptions may contain sensitive values; log only their type.
        logMsg(
          'Credential persistence failed',
          level: LogLevel.error,
          error: error.runtimeType,
          stackTrace: stack,
        );
        return false;
      }
    });
    _credentialOperations = result.then<void>((_) {});
    return result;
  }

  Future<void> _persistCredentialSettings({
    required bool rememberMe,
    required bool autoLogin,
  }) async {
    final revision = ++_credentialRevision;
    final generation = _authGeneration;
    final saved = await _queueCredentialOperation(() async {
      if (rememberMe) {
        await _appConfig.setRememberMe(true);
        await _appConfig.setAutoLogin(autoLogin);
      } else {
        try {
          await _appConfig.setAutoLogin(false);
          await _appConfig.setRememberMe(false);
        } finally {
          // Forgetting credentials must still be attempted if preferences fail.
          await _userDao.delete();
        }
      }
    });
    if (!saved &&
        ref.mounted &&
        revision == _credentialRevision &&
        generation == _authGeneration) {
      state = state.copyWith(
        rememberMe: _appConfig.rememberMe,
        autoLogin: _appConfig.rememberMe && _appConfig.autoLogin,
        statusMessage: '로그인 정보 설정을 저장하지 못했어요. 다시 시도해 주세요.',
      );
    }
  }

  Future<void> logout() async {
    _sessionRecoveryInFlight = null;
    _sessionCredentials = null;
    _resetAutomaticRelogin();
    final generation = ++_authGeneration;
    ref.read(attendanceProvider.notifier).resetSession();
    state = state.copyWith(
      isLoggedIn: false,
      loginStatus: LoginStatus.required,
      autoLogin: false,
      statusMessage: '로그아웃했어요.',
      recoveryPhase: SessionRecoveryPhase.idle,
    );
    final preferences = _persistCredentialSettings(
      rememberMe: state.rememberMe,
      autoLogin: false,
    );
    await _transport.clearAuthSession();
    await preferences;
    if (!ref.mounted || generation != _authGeneration) return;
    scheduleUpdateCheck();
  }
}
