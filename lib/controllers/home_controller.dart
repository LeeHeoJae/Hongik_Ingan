import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/app_config.dart';
import '../core/mock_attendance.dart';
import '../core/user_dao.dart';
import '../services/auth_service.dart';
import '../services/check_update.dart';

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
  late final AuthService _authService;
  late final AppConfig _appConfig;
  late final UserDao _userDao;

  @override
  HomeState build() {
    _authService = AuthService();
    _appConfig = AppConfig();
    _userDao = UserDao();

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
    if (_appConfig.savedId != null) {
      idController.text = _appConfig.savedId!;
    }
    if (_appConfig.savedPw != null) {
      pwController.text = _appConfig.savedPw!;
    }

    if (state.rememberMe && state.autoLogin) {
      await login(idController.text, pwController.text);
    }
  }

  Future<void> fetchUpdateInfo() async {
    if (kIsWeb) return;
    final updateInfo = await checkUpdate();
    state = state.copyWith(updateInfo: updateInfo);
  }

  Future<void> checkSessionValidityAndReact(String id, String pw) async {
    if (id == mockAttendanceUserId) {
      state = state.copyWith(isLoggedIn: true, statusMessage: '테스트 계정으로 접속합니다');
      return;
    }
    final isSessionValid = await _authService.isSessionValid();
    if (isSessionValid) {
      state = state.copyWith(isLoggedIn: true, statusMessage: '아직 세션이 유효합니다.');
      return;
    }
    if (state.rememberMe && state.autoLogin) {
      await login(id, pw);
      state = state.copyWith(
        isLoggedIn: true,
        statusMessage: '세션이 만료됐지만 다시 로그인하였습니다.',
      );
    } else {
      state = state.copyWith(
        isLoggedIn: false,
        statusMessage: '세션이 만료되어 로그아웃되었습니다.',
      );
    }
  }

  Future<String> login(String id, String pw) async {
    if (id.isEmpty || (id != mockAttendanceUserId && pw.isEmpty)) {
      return '학번과 비밀번호를 모두 입력해주세요.';
    }
    // 모의 계정
    if (id == mockAttendanceUserId) {
      state = state.copyWith(
        isLoading: false,
        isLoggedIn: true,
        statusMessage: '테스트 로그인 성공! 모의 출석체크를 사용할 수 있습니다.',
        userId: id,
      );
      return 'Success';
    }
    state = state.copyWith(isLoading: true, statusMessage: '홍대 서버와 보안 통신 중...');
    final result = await _authService.login(id, pw);
    if (result == 'Success') {
      if (state.rememberMe) {
        _userDao.save(id, pw);
      }
      state = state.copyWith(
        isLoading: false,
        isLoggedIn: true,
        statusMessage: '로그인 성공! 세션이 활성화되었습니다.',
        userId: id,
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        isLoggedIn: false,
        statusMessage: '로그인 실패. 정보를 확인해주세요.\n$result',
      );
    }
    return result;
  }

  void onRememberMeChanged(bool value) {
    _appConfig.setRememberMe(value);
    if (!value) {
      _appConfig.setAutoLogin(false);
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

  void logout() {
    state = state.copyWith(isLoggedIn: false, statusMessage: '로그아웃 되었습니다.');
  }
}
