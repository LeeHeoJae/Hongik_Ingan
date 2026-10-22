enum SessionRecoveryResult {
  restored,
  temporarilyUnavailable,
  retryableFailure,
  loginRequired,
  cancelled;

  bool get isRestored => this == restored;
}

enum SessionRecoveryPhase {
  idle,
  restoringSession,
  loggingIn,
  verifyingLecture,
  unavailable,
  credentialsUnavailable,
  credentialsRejected;

  bool get isActive => switch (this) {
    restoringSession || loggingIn || verifyingLecture => true,
    _ => false,
  };

  String? get message => switch (this) {
    idle => null,
    restoringSession => '학교 연결을 복구하고 있어요.',
    loggingIn => '로그인 연결을 복구하고 있어요.',
    verifyingLecture => '수업 정보를 확인하고 있어요.',
    unavailable => '학교 연결을 복구하지 못했어요. 잠시 후 다시 시도해 주세요.',
    credentialsUnavailable => '자동 로그인에 사용할 정보가 없어요.',
    credentialsRejected => '로그인 정보를 다시 확인해야 해요.',
  };
}
