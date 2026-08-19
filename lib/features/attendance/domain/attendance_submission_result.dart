class AttendanceSubmissionResult {
  const AttendanceSubmissionResult._({
    required this.isSuccess,
    required this.message,
  });

  const AttendanceSubmissionResult.success(String message)
    : this._(isSuccess: true, message: message);

  const AttendanceSubmissionResult.failure(String message)
    : this._(isSuccess: false, message: message);

  final bool isSuccess;
  final String message;
}
