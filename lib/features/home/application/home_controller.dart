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
import 'package:hongik_ingan/features/update/check_update.dart';
import 'package:hongik_ingan/features/update/domain/update_info.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'home_controller.g.dart';

enum LoginStatus {
  required,
  checkingSession,
  loggingIn,
  recoveringSession,
  failed,
  expired,
  verificationFailed,
}

@immutable
class HomeState {
  const HomeState({
    this.isLoading = false,
    this.isLoggedIn = false,
    this.loginStatus = LoginStatus.required,
    this.statusMessage = '서비스를 이용하려면 로그인해 주세요.',
    this.rememberMe = false,
    this.autoLogin = false,
    this.userId,
    this.updateInfo,
  });

  final bool isLoading;
  final bool isLoggedIn;
  final LoginStatus loginStatus;
  final String statusMessage;
  final bool rememberMe;
  final bool autoLogin;
  final String? userId;
  final UpdateInfo? updateInfo;

  HomeState copyWith({
    bool? isLoading,
    bool? isLoggedIn,
    LoginStatus? loginStatus,
    String? statusMessage,
    bool? rememberMe,
    bool? autoLogin,
    String? userId,
    UpdateInfo? updateInfo,
  }) {
    return HomeState(
      isLoading: isLoading ?? this.isLoading,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      loginStatus: loginStatus ?? this.loginStatus,
      statusMessage: statusMessage ?? this.statusMessage,
      rememberMe: rememberMe ?? this.rememberMe,
      autoLogin: autoLogin ?? this.autoLogin,
      userId: userId ?? this.userId,
      updateInfo: updateInfo ?? this.updateInfo,
    );
  }
}

@Riverpod(keepAlive: true)
class HomeController extends _$HomeController {
  HomeController({
    AppConfig? appConfig,
    UserDao? userDao,
    Future<UpdateInfo?> Function()? updateChecker,
  }) : _appConfig = appConfig ?? AppConfig(),
       _userDao = userDao ?? UserDao(),
       _checkUpdate = updateChecker ?? checkUpdate;

  late final SchoolTransport _transport;
  late final AuthService _authService;
  final AppConfig _appConfig;
  final UserDao _userDao;
  final Future<UpdateInfo?> Function() _checkUpdate;
  Timer? _updateInfoTimer;
  var _updateInfoStarted = false;
  int _authGeneration = 0;
  Future<bool>? _sessionRecoveryInFlight;
  Future<void> _credentialOperations = Future.value();
  int _credentialRevision = 0;

  @override
  HomeState build() {
    _transport = ref.watch(schoolTransportProvider);
    _authService = AuthService(_transport);
    ref.onDispose(() => _updateInfoTimer?.cancel());
    // 로그인 여부나 사용자 ID가 변경되면 출결 상태 초기화
    listenSelf((previous, next) {
      if (previous != null &&
          (previous.isLoggedIn != next.isLoggedIn ||
              previous.userId != next.userId)) {
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
    final generation = ++_authGeneration;
    state = state.copyWith(
      isLoading: true,
      loginStatus: LoginStatus.checkingSession,
      statusMessage: '저장된 세션 확인 중...',
    );
    final hasCookies = await _transport.hasAuthSession();
    if (!ref.mounted || generation != _authGeneration) return;
    if (hasCookies) {
      final status = await _authService.checkSessionStatus();
      if (!ref.mounted || generation != _authGeneration) return;
      switch (status) {
        case SessionStatus.valid:
          state = state.copyWith(
            isLoading: false,
            isLoggedIn: true,
            loginStatus: LoginStatus.required,
            statusMessage: '저장된 세션으로 로그인했어요.',
            userId: id.isEmpty ? state.userId : id,
          );
          _prefetchLecture();
          scheduleUpdateCheck(delay: const Duration(seconds: 2));
          return;
        case SessionStatus.expired:
          await _transport.clearAuthSession();
          break;
        case SessionStatus.integrationError:
        case SessionStatus.unknown:
          state = state.copyWith(
            isLoading: false,
            isLoggedIn: false,
            loginStatus: LoginStatus.verificationFailed,
            statusMessage: '로그인 상태를 확인하지 못했어요. 네트워크 연결을 확인해 주세요.',
          );
          return;
      }

      await _transport.clearAuthSession();
    }
    if (!ref.mounted || generation != _authGeneration) return;

    if (state.rememberMe && id.isNotEmpty && pw.isNotEmpty) {
      await login(id, pw);
      return;
    }

    state = state.copyWith(
      isLoading: false,
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
  Future<void> fetchUpdateInfo() async {
    if (state.isLoading) {
      scheduleUpdateCheck(delay: const Duration(seconds: 4));
      return;
    }

    _updateInfoStarted = true;
    final updateInfo = await _checkUpdate();
    if (!ref.mounted) return;
    state = state.copyWith(updateInfo: updateInfo);
  }

  /// 로그인된 앱이 포그라운드로 복귀할 때 현재 세션을 재검증.
  Future<void> revalidateSessionOnResume(String id, String pw) {
    final active = _sessionRecoveryInFlight;
    if (active != null) return active.then((_) {});
    if (state.isLoading ||
        !state.isLoggedIn ||
        ref.read(attendanceProvider.notifier).hasActiveSubmission) {
      return Future.value();
    }
    final request = _revalidateSessionOnResume(id, pw);
    return _shareSessionRecovery(request).then((_) {});
  }

  Future<bool> _revalidateSessionOnResume(String id, String pw) async {
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
    if (!canApplyResult()) return false;
    switch (status) {
      case SessionStatus.valid:
        state = state.copyWith(isLoggedIn: true, statusMessage: '세션이 아직 유효해요.');
        _prefetchLecture();
        scheduleUpdateCheck(delay: const Duration(seconds: 2));
        return true;
      case SessionStatus.integrationError:
        final canReauthenticate =
            state.rememberMe &&
            state.autoLogin &&
            id.toUpperCase() == state.userId?.toUpperCase();
        state = state.copyWith(
          isLoading: true,
          loginStatus: LoginStatus.recoveringSession,
        );
        final bool restored;
        try {
          restored = await _authService.recoverAttendanceSession(
            studentId: canReauthenticate ? id : null,
            password: canReauthenticate ? pw : null,
            canContinue: () => ref.mounted && generation == _authGeneration,
          );
        } finally {
          if (ref.mounted && generation == _authGeneration) {
            state = state.copyWith(
              isLoading: false,
              loginStatus: LoginStatus.required,
            );
          }
        }
        if (!canApplyResult()) return false;
        if (restored) {
          _prefetchLecture();
          return true;
        }
        state = state.copyWith(
          isLoggedIn: false,
          loginStatus: LoginStatus.expired,
          statusMessage: '출결 서버 SSO 연동에 실패해 로그아웃됐어요. 다시 로그인해 주세요.',
        );
        await _transport.clearAuthSession();
        return false;
      case SessionStatus.expired:
        // Attendance can expire while the shared SSO session remains valid.
        final restored = await _authService.recoverAttendanceSession(
          canContinue: () => ref.mounted && generation == _authGeneration,
        );
        if (!canApplyResult()) return false;
        if (restored) {
          _prefetchLecture();
          scheduleUpdateCheck(delay: const Duration(seconds: 2));
          return true;
        }
        final canRecover =
            state.rememberMe &&
            state.autoLogin &&
            id.isNotEmpty &&
            pw.isNotEmpty;
        state = state.copyWith(
          isLoggedIn: false,
          isLoading: canRecover,
          loginStatus: canRecover
              ? LoginStatus.recoveringSession
              : LoginStatus.expired,
        );
        await _transport.clearAuthSession();
        if (!ref.mounted || generation != _authGeneration) return false;
        if (!canRecover) {
          state = state.copyWith(
            isLoggedIn: false,
            statusMessage: '세션이 만료되어 로그아웃됐어요.',
          );
          return false;
        }
        final result = await login(id, pw, isSessionRecovery: true);
        if (!ref.mounted || generation + 1 != _authGeneration) return false;
        if (result.isSuccess) {
          state = state.copyWith(statusMessage: '세션이 만료됐지만 다시 로그인했어요.');
        }
        return result.isSuccess;
      case SessionStatus.unknown:
        state = state.copyWith(
          isLoading: false,
          loginStatus: LoginStatus.verificationFailed,
          statusMessage: '로그인 상태를 확인하지 못했어요. 네트워크 연결을 확인해 주세요.',
        );
        return false;
    }
  }

  /// Share recovery with concurrent lecture requests and foreground checks.
  Future<bool> recoverAttendanceSession() {
    final active = _sessionRecoveryInFlight;
    if (active != null) return active;
    if (!state.isLoggedIn || state.isLoading) return Future.value(false);
    return _shareSessionRecovery(_recoverAttendanceSession());
  }

  Future<bool> _shareSessionRecovery(Future<bool> request) {
    late final Future<bool> shared;
    shared = request.whenComplete(() {
      if (identical(_sessionRecoveryInFlight, shared)) {
        _sessionRecoveryInFlight = null;
      }
    });
    _sessionRecoveryInFlight = shared;
    return shared;
  }

  Future<bool> _recoverAttendanceSession() async {
    final generation = _authGeneration;
    final userId = state.userId;
    bool canContinue() =>
        ref.mounted && generation == _authGeneration && state.isLoggedIn;
    state = state.copyWith(
      isLoading: true,
      loginStatus: LoginStatus.recoveringSession,
    );
    try {
      final recovered = await _authService.recoverAttendanceSession(
        studentId: userId,
        readPassword: () async {
          if (!canContinue() || !state.rememberMe || !state.autoLogin) {
            return null;
          }
          (String?, String?) credentials = (null, null);
          await _queueCredentialOperation(() async {
            if (canContinue() && state.rememberMe && state.autoLogin) {
              credentials = await _userDao.load();
            }
          });
          if (!canContinue() || !state.rememberMe || !state.autoLogin) {
            return null;
          }
          return credentials.$1?.toUpperCase() == userId?.toUpperCase()
              ? credentials.$2
              : null;
        },
        canContinue: canContinue,
      );
      return canContinue() && recovered;
    } catch (_) {
      return false;
    } finally {
      if (canContinue()) {
        state = state.copyWith(
          isLoading: false,
          loginStatus: LoginStatus.required,
        );
      }
    }
  }

  /// 로그인 시도
  Future<LoginResult> login(
    String id,
    String pw, {
    bool isSessionRecovery = false,
  }) async {
    if (id.isEmpty || pw.isEmpty) {
      return const LoginResult.failure(
        LoginFailureKind.invalidInput,
        '학번과 비밀번호를 모두 입력해 주세요.',
      );
    }
    if (!isSessionRecovery) _sessionRecoveryInFlight = null;
    _updateInfoTimer?.cancel();
    final generation = ++_authGeneration;
    ref.read(attendanceProvider.notifier).resetSession();
    state = state.copyWith(
      isLoading: true,
      isLoggedIn: false,
      loginStatus: isSessionRecovery
          ? LoginStatus.recoveringSession
          : LoginStatus.loggingIn,
      statusMessage: '홍대 서버와 보안 통신 중...',
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
      state = state.copyWith(
        isLoading: false,
        isLoggedIn: true,
        loginStatus: LoginStatus.required,
        statusMessage: saved
            ? '로그인했어요. 세션을 활성화했어요.'
            : '로그인했지만 로그인 정보 저장에 실패했어요.',
        userId: id,
      );
      _prefetchLecture();
      scheduleUpdateCheck(delay: const Duration(seconds: 2));
    } else {
      state = state.copyWith(
        isLoading: false,
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
    final generation = ++_authGeneration;
    ref.read(attendanceProvider.notifier).resetSession();
    state = state.copyWith(
      isLoading: false,
      isLoggedIn: false,
      loginStatus: LoginStatus.required,
      autoLogin: false,
      statusMessage: '로그아웃했어요.',
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
