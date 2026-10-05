class AttendanceSubmissionResult {
  const AttendanceSubmissionResult._({
    required this.isError,
    required this.message,
    required this.hasServerResponse,
  });

  const AttendanceSubmissionResult.notice(String message)
    : this._(isError: false, message: message, hasServerResponse: true);

  const AttendanceSubmissionResult.failure(String message)
    : this._(isError: true, message: message, hasServerResponse: false);

  final bool isError;
  final String message;
  final bool hasServerResponse;
}
