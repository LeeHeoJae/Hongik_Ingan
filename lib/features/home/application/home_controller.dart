import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hongik_ingan/core/app_config.dart';
import 'package:hongik_ingan/core/network/school_transport.dart';
import 'package:hongik_ingan/core/network/school_transport_provider.dart';
import 'package:hongik_ingan/core/user_dao.dart';
import 'package:hongik_ingan/features/attendance/application/attendance_controller.dart';
import 'package:hongik_ingan/features/home/data/auth_service.dart';
import 'package:hongik_ingan/features/update/check_update.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'home_controller.g.dart';

@immutable
class HomeState {
  const HomeState({
    this.isLoading = false,
    this.isLoggedIn = false,
    this.statusMessage = '서비스 이용을 위해 로그인해주세요.',
    this.rememberMe = false,
    this.autoLogin = false,
    this.userId,
    this.updateInfo,
  });

  final bool isLoading;
  final bool isLoggedIn;
  final String statusMessage;
  final bool rememberMe;
  final bool autoLogin;
  final String? userId;
  final Map<String, String>? updateInfo;

  HomeState copyWith({
    bool? isLoading,
    bool? isLoggedIn,
    String? statusMessage,
    bool? rememberMe,
    bool? autoLogin,
    String? userId,
    Map<String, String>? updateInfo,
  }) {
    return HomeState(
      isLoading: isLoading ?? this.isLoading,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
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

  @override
  HomeState build() {
    _transport = ref.watch(schoolTransportProvider);
    _authService = AuthService(_transport);
    _appConfig = AppConfig();
    _userDao = UserDao();
    ref.onDispose(() => _updateInfoTimer?.cancel());

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

  Future<void> restoreSessionOrLogin(String id, String pw) async {
    state = state.copyWith(isLoading: true, statusMessage: '저장된 세션 확인 중...');
    final hasCookies = await _transport.hasAuthSession();
    if (hasCookies) {
      final isSessionValid = await _authService.isSessionValid();
      if (isSessionValid) {
        state = state.copyWith(
          isLoading: false,
          isLoggedIn: true,
          statusMessage: '저장된 세션으로 로그인되었습니다.',
          userId: id.isEmpty ? state.userId : id,
        );
        _prefetchLecture();
        scheduleUpdateCheck(delay: const Duration(seconds: 2));
        return;
      }

      await _transport.clearAuthSession();
    }

    if (state.rememberMe && id.isNotEmpty && pw.isNotEmpty) {
      await login(id, pw);
      return;
    }

    state = state.copyWith(
      isLoading: false,
      isLoggedIn: false,
      statusMessage: hasCookies
          ? '세션이 만료되어 다시 로그인해주세요.'
          : '서비스 이용을 위해 로그인해주세요.',
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

  Future<void> fetchUpdateInfo() async {
    if (kIsWeb) return;
    if (state.isLoading) {
      scheduleUpdateCheck(delay: const Duration(seconds: 4));
      return;
    }

    _updateInfoStarted = true;
    final updateInfo = await checkUpdate();
    state = state.copyWith(updateInfo: updateInfo);
  }

  Future<void> checkSessionValidityAndReact(String id, String pw) async {
    final isSessionValid = await _authService.isSessionValid();
    if (isSessionValid) {
      state = state.copyWith(isLoggedIn: true, statusMessage: '아직 세션이 유효합니다.');
      _prefetchLecture();
      scheduleUpdateCheck(delay: const Duration(seconds: 2));
      return;
    }
    await _transport.clearAuthSession();
    if (state.rememberMe && state.autoLogin) {
      final result = await login(id, pw);
      if (result == 'Success') {
        state = state.copyWith(
          isLoggedIn: true,
          statusMessage: '세션이 만료됐지만 다시 로그인하였습니다.',
        );
      }
    } else {
      state = state.copyWith(
        isLoggedIn: false,
        statusMessage: '세션이 만료되어 로그아웃되었습니다.',
      );
    }
  }

  Future<String> login(String id, String pw) async {
    if (id.isEmpty) {
      return '학번과 비밀번호를 모두 입력해주세요.';
    }
    _updateInfoTimer?.cancel();
    state = state.copyWith(isLoading: true, statusMessage: '홍대 서버와 보안 통신 중...');
    final result = await _authService.login(id, pw);
    if (result == 'Success') {
      if (state.rememberMe) {
        await _userDao.save(id, pw);
      }
      state = state.copyWith(
        isLoading: false,
        isLoggedIn: true,
        statusMessage: '로그인 성공! 세션이 활성화되었습니다.',
        userId: id,
      );
      _prefetchLecture();
      scheduleUpdateCheck(delay: const Duration(seconds: 2));
    } else {
      state = state.copyWith(
        isLoading: false,
        isLoggedIn: false,
        statusMessage: '로그인 실패. 정보를 확인해주세요.\n$result',
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
    await _transport.clearAuthSession();
    await _appConfig.setAutoLogin(false);
    state = state.copyWith(
      isLoggedIn: false,
      autoLogin: false,
      statusMessage: '로그아웃 되었습니다.',
    );
    scheduleUpdateCheck();
  }
}
