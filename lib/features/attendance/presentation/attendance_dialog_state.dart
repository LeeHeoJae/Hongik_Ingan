import 'package:hongik_ingan/features/attendance/domain/attendance_submission_result.dart';

enum AttendanceDialogStage { input, processing, result }

class AttendanceDialogState {
  const AttendanceDialogState.input()
    : stage = AttendanceDialogStage.input,
      message = '',
      result = null,
      openSettings = null;

  const AttendanceDialogState.processing(this.message)
    : stage = AttendanceDialogStage.processing,
      result = null,
      openSettings = null;

  const AttendanceDialogState.result(
    AttendanceSubmissionResult value, {
    this.openSettings,
  }) : stage = AttendanceDialogStage.result,
       result = value,
       message = '';

  final AttendanceDialogStage stage;
  final String message;
  final AttendanceSubmissionResult? result;

  /// 결과 화면의 주요 행동을 기기 설정 열기로 바꿈.
  final Future<bool> Function()? openSettings;
}
