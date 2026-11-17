part of 'home_controller.dart';

enum LoginStatus {
  required,
  checkingSession,
  loggingIn,
  automaticLogin,
  recoveringSession,
  securityCodeRequired,
  verifyingSecurityCode,
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
    LoginStatus.verifyingSecurityCode ||
    LoginStatus.automaticLogin ||
    LoginStatus.recoveringSession => true,
    _ => false,
  };

  bool get isSecurityCodeStage =>
      loginStatus == LoginStatus.securityCodeRequired ||
      loginStatus == LoginStatus.verifyingSecurityCode;

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
