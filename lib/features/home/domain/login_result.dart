enum LoginResultStatus { success, cancelled, failure }

enum LoginFailureKind {
  invalidInput,
  credentials,
  attendanceSession,
  connection,
}

final class LoginResult {
  const LoginResult.success()
    : status = LoginResultStatus.success,
      failureKind = null,
      message = '';

  const LoginResult.cancelled()
    : status = LoginResultStatus.cancelled,
      failureKind = null,
      message = '';

  const LoginResult.failure(LoginFailureKind kind, this.message)
    : failureKind = kind,
      status = LoginResultStatus.failure;

  final LoginResultStatus status;
  final LoginFailureKind? failureKind;
  final String message;

  bool get isSuccess => status == LoginResultStatus.success;
  bool get isCancelled => status == LoginResultStatus.cancelled;
  bool get isFailure => status == LoginResultStatus.failure;

  String get displayMessage => switch (failureKind) {
    LoginFailureKind.attendanceSession => '$message 잠시 후 다시 시도해 주세요.',
    LoginFailureKind.credentials when message == 'Login failed' =>
      '학번과 비밀번호를 확인해 주세요.',
    _ => message,
  };
}
