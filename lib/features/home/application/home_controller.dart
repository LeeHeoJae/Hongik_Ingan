import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hongik_ingan/core/app_config.dart';
import 'package:hongik_ingan/core/network/school_transport.dart';
import 'package:hongik_ingan/core/network/school_transport_provider.dart';
import 'package:hongik_ingan/core/user_dao.dart';
import 'package:hongik_ingan/features/attendance/application/attendance_controller.dart';
import 'package:hongik_ingan/features/home/data/auth_service.dart';
import 'package:hongik_ingan/features/home/domain/session_status.dart';
import 'package:hongik_ingan/features/update/check_update.dart';
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
  final Map<String, String>? updateInfo;

  HomeState copyWith({
    bool? isLoading,
    bool? isLoggedIn,
    LoginStatus? loginStatus,
    String? statusMessage,
    bool? rememberMe,
    bool? autoLogin,
    String? userId,
    Map<String, String>? updateInfo,
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
  late final SchoolTransport _transport;
  late final AuthService _authService;
  late final AppConfig _appConfig;
  late final UserDao _userDao;
  Timer? _updateInfoTimer;
  var _updateInfoStarted = false;
  int _authGeneration = 0;
  Future<bool>? _sessionRecoveryInFlight;

  @override
  HomeState build() {
    _transport = ref.watch(schoolTransportProvider);
    _authService = AuthService(_transport);
    _appConfig = AppConfig();
    _userDao = UserDao();
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

  Future<void> initializeApp(
    TextEditingController idController,
    TextEditingController pwController,
  ) async {
    await _appConfig.init();
    state = state.copyWith(
      rememberMe: _appConfig.rememberMe,
      autoLogin: _appConfig.autoLogin,
      userId: _appConfig.savedId,
    );

    if (_appConfig.savedId != null) {
      idController.text = _appConfig.savedId!;
    }
    if (_appConfig.savedPw != null) {
      pwController.text = _appConfig.savedPw!;
    }

    if (state.autoLogin) {
      await restoreSessionOrLogin(idController.text, pwController.text);
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
    final updateInfo = await checkUpdate();
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
        final restored = await _authService.recoverAttendanceSession(
          canContinue: () => ref.mounted && generation == _authGeneration,
        );
        if (!canApplyResult()) return false;
        if (restored) {
          _prefetchLecture();
          return true;
        }
        state = state.copyWith(
          loginStatus: LoginStatus.verificationFailed,
          statusMessage: '출결 서버 SSO 연동을 확인하지 못했어요. 잠시 후 다시 시도해 주세요.',
        );
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
        if (result == 'Success') {
          state = state.copyWith(statusMessage: '세션이 만료됐지만 다시 로그인했어요.');
        }
        return result == 'Success';
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
          final credentials = await _userDao.load();
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
  Future<String> login(
    String id,
    String pw, {
    bool isSessionRecovery = false,
  }) async {
    if (id.isEmpty || pw.isEmpty) {
      return '학번과 비밀번호를 모두 입력해 주세요.';
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
    if (!ref.mounted || generation != _authGeneration) return 'Cancelled';
    if (result == 'Success') {
      if (state.rememberMe) {
        await _userDao.save(id, pw);
      }
      if (!ref.mounted || generation != _authGeneration) return 'Cancelled';
      state = state.copyWith(
        isLoading: false,
        isLoggedIn: true,
        loginStatus: LoginStatus.required,
        statusMessage: '로그인했어요. 세션을 활성화했어요.',
        userId: id,
      );
      _prefetchLecture();
      scheduleUpdateCheck(delay: const Duration(seconds: 2));
    } else {
      state = state.copyWith(
        isLoading: false,
        isLoggedIn: false,
        loginStatus: LoginStatus.failed,
        statusMessage: result,
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

  void onRememberMeChanged(bool value) {
    _appConfig.setRememberMe(value);
    if (!value) {
      _appConfig.setAutoLogin(false);
      _appConfig.clearSavedCredentials();
      unawaited(_userDao.delete());
      state = state.copyWith(rememberMe: value, autoLogin: false);
    } else {
      state = state.copyWith(rememberMe: value);
    }
  }

  void onAutoLoginChanged(bool value) {
    _appConfig.setAutoLogin(value);
    if (value) {
      _appConfig.setRememberMe(true);
      state = state.copyWith(autoLogin: value, rememberMe: true);
    } else {
      state = state.copyWith(autoLogin: value);
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
    await _transport.clearAuthSession();
    await _appConfig.setAutoLogin(false);
    if (!ref.mounted || generation != _authGeneration) return;
    scheduleUpdateCheck();
  }
}
