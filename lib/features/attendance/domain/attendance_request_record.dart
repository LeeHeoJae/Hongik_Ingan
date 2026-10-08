import 'attendance_submission_result.dart';

class AttendanceRequestRecord {
  const AttendanceRequestRecord({
    required this.id,
    required this.lectureName,
    required this.requestedAt,
    required this.authCode,
    this.hasServerResponse = false,
    this.isUnconfirmed = false,
    this.message = '요청 결과를 아직 확인하지 못했어요.',
  });

  final String id;
  final String lectureName;
  final DateTime requestedAt;
  final String authCode;
  final bool hasServerResponse;
  final bool isUnconfirmed;
  bool get hasKnownResult => hasServerResponse && !isUnconfirmed;
  final String message;

  AttendanceRequestRecord withResult(AttendanceSubmissionResult result) =>
      AttendanceRequestRecord(
        id: id,
        lectureName: lectureName,
        requestedAt: requestedAt,
        authCode: authCode,
        hasServerResponse: result.hasServerResponse,
        isUnconfirmed: result.isUnconfirmed,
        message: result.message,
      );

  Map<String, Object> toJson() => {
    'id': id,
    'lectureName': lectureName,
    'requestedAt': requestedAt.toUtc().toIso8601String(),
    'authCode': authCode,
    'hasServerResponse': hasServerResponse,
    'isUnconfirmed': isUnconfirmed,
    'message': message,
  };

  factory AttendanceRequestRecord.fromJson(Map<String, dynamic> json) =>
      AttendanceRequestRecord(
        id: json['id'] as String,
        lectureName: json['lectureName'] as String,
        requestedAt: DateTime.parse(json['requestedAt'] as String).toUtc(),
        authCode: json['authCode'] as String,
        hasServerResponse: json['hasServerResponse'] as bool,
        isUnconfirmed: json['isUnconfirmed'] as bool? ?? false,
        message: json['message'] as String,
      );
}
