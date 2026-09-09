class AttendanceSubmissionResult {
  const AttendanceSubmissionResult._({
    required this.isError,
    required this.message,
  });

  const AttendanceSubmissionResult.notice(String message)
    : this._(isError: false, message: message);

  const AttendanceSubmissionResult.failure(String message)
    : this._(isError: true, message: message);

  final bool isError;
  final String message;
}
