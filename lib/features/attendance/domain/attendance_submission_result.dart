enum AttendanceSubmissionStatus {
  notice,
  failure,
  sessionExpired,
  ssoIntegrationError,
  unconfirmed,
}

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
  bool get isError => status != AttendanceSubmissionStatus.notice;
  bool get isUnconfirmed =>
      status == AttendanceSubmissionStatus.unconfirmed ||
      status == AttendanceSubmissionStatus.ssoIntegrationError;
  bool get needsSessionRecovery =>
      status == AttendanceSubmissionStatus.sessionExpired ||
      status == AttendanceSubmissionStatus.ssoIntegrationError;
  final String message;
  final bool hasServerResponse;
}
