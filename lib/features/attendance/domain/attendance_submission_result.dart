enum AttendanceSubmissionStatus {
  notice,
  failure,
  sessionExpired,
  ssoIntegrationError,
  unconfirmed,
}

enum AttendanceOutcome { success, failure, unknown }

class AttendanceSubmissionResult {
  const AttendanceSubmissionResult._({
    required this.status,
    required this.message,
    required this.hasServerResponse,
  });

  const AttendanceSubmissionResult.notice(String message)
    : this._(
        status: AttendanceSubmissionStatus.notice,
        message: message,
        hasServerResponse: true,
      );

  const AttendanceSubmissionResult.failure(String message)
    : this._(
        status: AttendanceSubmissionStatus.failure,
        message: message,
        hasServerResponse: false,
      );

  const AttendanceSubmissionResult.sessionExpired(String message)
    : this._(
        status: AttendanceSubmissionStatus.sessionExpired,
        message: message,
        hasServerResponse: true,
      );

  const AttendanceSubmissionResult.ssoIntegrationError(String message)
    : this._(
        status: AttendanceSubmissionStatus.ssoIntegrationError,
        message: message,
        hasServerResponse: true,
      );

  const AttendanceSubmissionResult.unconfirmed(
    String message, {
    bool hasServerResponse = false,
  }) : this._(
         status: AttendanceSubmissionStatus.unconfirmed,
         message: message,
         hasServerResponse: hasServerResponse,
       );

  final AttendanceSubmissionStatus status;
  AttendanceOutcome get outcome {
    if (status != AttendanceSubmissionStatus.notice) {
      return AttendanceOutcome.unknown;
    }
    if (message.contains('출석확인이 완료되었습니다')) {
      return AttendanceOutcome.success;
    }
    if (message.trim() == '인증번호가 일치하지 않습니다.') {
      return AttendanceOutcome.failure;
    }
    return AttendanceOutcome.unknown;
  }

  bool get isConfirmedAttendance => outcome == AttendanceOutcome.success;
  bool get isError =>
      status != AttendanceSubmissionStatus.notice ||
      outcome == AttendanceOutcome.failure;
  bool get isUnconfirmed =>
      status == AttendanceSubmissionStatus.unconfirmed ||
      status == AttendanceSubmissionStatus.ssoIntegrationError;
  bool get needsSessionRecovery =>
      status == AttendanceSubmissionStatus.sessionExpired ||
      status == AttendanceSubmissionStatus.ssoIntegrationError;
  final String message;
  final bool hasServerResponse;
}
