import 'package:hongik_ingan/features/attendance/domain/attendance_submission_result.dart';

enum AttendanceDialogStage { input, processing, result }

class AttendanceDialogState {
  const AttendanceDialogState.input()
    : stage = AttendanceDialogStage.input,
      message = '',
      result = null;

  const AttendanceDialogState.processing(this.message)
    : stage = AttendanceDialogStage.processing,
      result = null;

  const AttendanceDialogState.result(AttendanceSubmissionResult value)
    : stage = AttendanceDialogStage.result,
      result = value,
      message = '';

  final AttendanceDialogStage stage;
  final String message;
  final AttendanceSubmissionResult? result;
}
