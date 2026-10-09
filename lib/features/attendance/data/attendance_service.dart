import 'package:dio/dio.dart';
import 'package:hongik_ingan/core/logging/logger.dart';
import 'package:hongik_ingan/core/network/attendance_session_response.dart';
import 'package:hongik_ingan/core/network/school_log_interceptor.dart';
import 'package:hongik_ingan/core/network/school_request_options.dart';
import 'package:hongik_ingan/core/network/school_transport.dart';
import 'package:hongik_ingan/features/attendance/domain/attendance_submission_result.dart';
import 'package:hongik_ingan/features/attendance/domain/lecture.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;

enum LectureFetchStatus { success, empty, failure }

/// 강의 불러오기 결과에 대한 정보.
class LectureFetchResult {
  const LectureFetchResult._({
    required this.status,
    required this.message,
    this.lecture,
    this.error,
    this.sessionExpired = false,
    this.ssoIntegrationError = false,
    this.retryAfter,
  });

  const LectureFetchResult.success(Lecture lecture)
    : this._(
        status: LectureFetchStatus.success,
        message: '출석 가능한 수업을 찾았어요.',
        lecture: lecture,
      );

  const LectureFetchResult.empty()
    : this._(status: LectureFetchStatus.empty, message: '현재 출석 가능한 수업이 없어요.');

  const LectureFetchResult.failure({
    required String message,
    Object? error,
    bool sessionExpired = false,
    bool ssoIntegrationError = false,
    String? retryAfter,
  }) : this._(
         status: LectureFetchStatus.failure,
         message: message,
         error: error,
         sessionExpired: sessionExpired,
         ssoIntegrationError: ssoIntegrationError,
         retryAfter: retryAfter,
       );

  final LectureFetchStatus status;
  final String message;
  final Lecture? lecture;
  final Object? error;
  final bool sessionExpired;
  final bool ssoIntegrationError;
  final String? retryAfter;
}

/// 출결 서버와 통신해 현재 출석 가능한 강의를 조회하고 제출.
class AttendanceService {
  const AttendanceService(this._transport);

  final SchoolHttpTransport _transport;

  /// 현재 출석 가능한 강의를 조회.
  Future<LectureFetchResult> getActiveLecture({
    bool isAutomatic = false,
  }) async {
    logMsg('출결 페이지 로딩');
    try {
      final response = await _transport.get<String>(
        'https://at.hongik.ac.kr/index.jsp',
        options: SchoolRequestOptions(
          timeoutProfile: NetworkTimeoutProfile.lectureFetch,
          responseType: ResponseType.plain,
          headers: {'Referer': 'https://at.hongik.ac.kr/login.jsp'},
          allowProxyRetry: !isAutomatic,
        ),
      );
      logResponseDiagnostics(response);
      final result = _parseLectureFetchResponse(response);
      return _logResult(result, context: responseLogContext(response));
    } on DioException catch (e, stack) {
      if (e.response case final response?) logResponseDiagnostics(response);
      return _logResult(
        LectureFetchResult.failure(
          message: '출결 서버에 연결하지 못했어요.',
          error: e,
          retryAfter: _retryAfter(e.response),
        ),
        stackTrace: stack,
        context: responseLogContext(e.response, request: e.requestOptions),
      );
    } catch (e, stack) {
      return _logResult(
        LectureFetchResult.failure(message: '출결 페이지 형식을 분석하지 못했어요.', error: e),
        stackTrace: stack,
      );
    }
  }

  LectureFetchResult _parseLectureFetchResponse(Response<String> response) {
    final statusCode = response.statusCode;
    if (statusCode != null && statusCode >= 400) {
      return LectureFetchResult.failure(
        message: '출결 서버에 연결하지 못했어요.',
        retryAfter: _retryAfter(response),
      );
    }
    if (statusCode != null && statusCode >= 300 && statusCode < 400) {
      return const LectureFetchResult.failure(
        message: '출결 서버 세션이 만료됐어요.',
        sessionExpired: true,
      );
    }
    final body = response.data?.toString() ?? '';
    if (body.trim().isEmpty) {
      return const LectureFetchResult.failure(message: '출결 서버 응답이 비어 있어요.');
    }
    if (isAttendanceSessionExpired(body)) {
      return const LectureFetchResult.failure(
        message: '출결 서버 세션이 만료됐어요.',
        sessionExpired: true,
      );
    }
    if (body.contains('SSO 시스템 연동') && body.contains('오류')) {
      return const LectureFetchResult.failure(
        message: '출결 서버 SSO 연동에 실패했어요.',
        ssoIntegrationError: true,
      );
    }

    final document = html.parse(response.data);
    final table = document.querySelector('table');
    if (table == null) {
      return const LectureFetchResult.failure(message: '출결 페이지를 찾지 못했어요.');
    }

    final rows = table.querySelectorAll('tbody > tr');
    final active = _findActiveLecture(rows);
    if (active == null) {
      return const LectureFetchResult.empty();
    }

    final lecture = _parseLectureRow(row: active.row, form: active.form);
    if (lecture == null) {
      return const LectureFetchResult.failure(
        message: '출석 가능한 수업 정보를 분석하지 못했어요.',
      );
    }
    return LectureFetchResult.success(lecture);
  }

  String? _retryAfter(Response<dynamic>? response) {
    if (response?.statusCode != 429 && response?.statusCode != 503) return null;
    return response?.headers.value('retry-after');
  }

  ({Element row, Element form})? _findActiveLecture(List<Element> rows) {
    for (final row in rows) {
      final form = row.querySelector('form[action*="stud02.jsp"]');
      if (form != null) {
        return (row: row, form: form);
      }
    }
    return null;
  }

  Lecture? _parseLectureRow({required Element row, required Element form}) {
    final cells = row.querySelectorAll('td');
    if (cells.length < 5) {
      return null;
    }
    final params = _extractAttendanceParams(form);
    if (params.isEmpty) {
      return null;
    }
    return Lecture(
      name: _normalizeText(cells[2].text),
      time: _normalizeText(cells[4].text),
      attendanceParams: params,
    );
  }

  Map<String, String> _extractAttendanceParams(Element form) {
    final attendanceParams = <String, String>{};

    for (final input in form.querySelectorAll('input[name]')) {
      final name = input.attributes['name'];
      final value = input.attributes['value'];
      if (name != null && name.isNotEmpty) {
        attendanceParams[name] = value ?? '';
      }
    }
    logMsg('활성화된 수업 파라미터 개수: ${attendanceParams.length}');
    return attendanceParams;
  }

  String _normalizeText(String text) {
    return text.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  LectureFetchResult _logResult(
    LectureFetchResult result, {
    StackTrace? stackTrace,
    Map<String, Object?> context = const {},
  }) {
    final level = result.status == LectureFetchStatus.failure
        ? LogLevel.error
        : LogLevel.info;
    logMsg(
      '수업 목록 파싱 결과 - ${result.status.name} (${result.message})',
      level: level,
      error: result.error is DioException
          ? (result.error as DioException).type
          : result.error,
      stackTrace: stackTrace,
      context: context,
    );
    return result;
  }

  Future<AttendanceSubmissionResult> submitAttendance(
    Lecture lecture,
    String authCode,
    String? lat,
    String? lng,
  ) async {
    try {
      if (lecture.attendanceParams.isEmpty) {
        logMsg(
          'attendance submit result=failure reason=missingParameters',
          level: LogLevel.warning,
        );
        return const AttendanceSubmissionResult.failure(
          '출석 정보를 준비하지 못했어요. 다시 시도해 주세요.',
        );
      }

      final payload = {
        ...lecture.attendanceParams,
        'key': authCode,
        'latitude': lat ?? '',
        'longitude': lng ?? '',
      };
      logMsg('출석 체크 전송 - 수업: ${lecture.name}', level: LogLevel.info);
      logMsg('출석 체크 payload 필드 개수: ${payload.length}');
      final options = const SchoolRequestOptions(
        timeoutProfile: NetworkTimeoutProfile.attendanceSubmit,
        contentType: Headers.formUrlEncodedContentType,
        headers: {
          'Host': 'at.hongik.ac.kr',
          'Origin': 'https://at.hongik.ac.kr',
          'Referer': 'https://at.hongik.ac.kr/stud02.jsp',
        },
        responseType: ResponseType.plain,
      );
      final response = await _transport.post(
        'https://at.hongik.ac.kr/stud02_proc.jsp',
        data: payload,
        options: options,
      );
      logResponseDiagnostics(response);
      logMsg(
        '출석 체크 응답: status=${response.statusCode}',
        context: responseLogContext(response),
      );
      final authenticationFailure = _submissionAuthenticationFailure(
        response.data?.toString() ?? '',
      );
      if (authenticationFailure != null) {
        logMsg(
          'attendance submit result=authenticationFailure',
          level: LogLevel.warning,
          context: responseLogContext(response),
        );
        return authenticationFailure;
      }
      final responseDocument = html.parse(response.data);
      // alert로 나오는 문구를 그대로 알림으로 재사용
      final scriptMessage = _extractAlertMessage(responseDocument);
      if (scriptMessage != null) {
        logMsg(
          'attendance submit result=notice message=$scriptMessage',
          level: LogLevel.info,
          context: responseLogContext(response),
        );
        return AttendanceSubmissionResult.notice(scriptMessage);
      }
      final alertDiv = responseDocument.querySelector('.alert.alert-warning');
      if (alertDiv != null) {
        final message = alertDiv.text.trim().replaceAll(RegExp(r'\s+'), ' ');
        if (message.isNotEmpty) {
          logMsg(
            '출석 결과(html): $message',
            level: LogLevel.info,
            context: responseLogContext(response),
          );
          return AttendanceSubmissionResult.notice(message);
        }
      }
      logMsg(
        'attendance submit result=unconfirmed reason=unrecognizedResponse',
        level: LogLevel.warning,
        context: responseLogContext(response),
      );
      return const AttendanceSubmissionResult.unconfirmed(
        '출결 서버 응답을 해석하지 못했어요. 학교 출결 내역을 확인한 뒤 다시 입력해 주세요.',
        hasServerResponse: true,
      );
    } on DioException catch (e, stack) {
      if (e.response case final response?) logResponseDiagnostics(response);
      logMsg(
        '출석 에러 발생: ${e.message}',
        level: .error,
        error: e.type,
        stackTrace: stack,
        context: responseLogContext(e.response, request: e.requestOptions),
      );
      if (e.response != null) {
        final authenticationFailure = _submissionAuthenticationFailure(
          e.response?.data?.toString() ?? '',
        );
        if (authenticationFailure != null) return authenticationFailure;
      }
      return AttendanceSubmissionResult.unconfirmed(
        '네트워크 오류로 출결 처리 여부를 확인하지 못했어요. 학교 출결 내역을 확인한 뒤 다시 입력해 주세요.',
        hasServerResponse: e.response != null,
      );
    } catch (e, stack) {
      logMsg('알 수 없는 에러: $e', level: .error, error: e, stackTrace: stack);
      return const AttendanceSubmissionResult.unconfirmed(
        '출결 처리 여부를 확인하지 못했어요. 학교 출결 내역을 확인한 뒤 다시 입력해 주세요.',
      );
    }
  }

  AttendanceSubmissionResult? _submissionAuthenticationFailure(String body) {
    if (body.contains('SSO 시스템 연동') && body.contains('오류')) {
      return const AttendanceSubmissionResult.ssoIntegrationError(
        '출결 서버 SSO 연동에 실패해 처리 여부를 확인하지 못했어요. 학교 출결 내역을 확인해 주세요.',
      );
    }
    if (isAttendanceSessionExpired(body)) {
      return const AttendanceSubmissionResult.sessionExpired(
        '출결 서버 세션이 만료됐어요. 세션을 확인한 뒤 출결 번호를 다시 입력해 주세요.',
      );
    }
    return null;
  }

  /// alert의 안내 문구를 추출.
  String? _extractAlertMessage(Document document) {
    final pattern = RegExp(
      r'''//[^\r\n]*|/\*[\s\S]*?\*/|(?:\bwindow\s*\.\s*)?\balert\s*\(\s*(?:'((?:\\[\s\S]|[^'\\])*)'|"((?:\\[\s\S]|[^"\\])*)")\s*\)|'(?:\\[\s\S]|[^'\\])*'|"(?:\\[\s\S]|[^"\\])*"''',
    );
    for (final script in document.querySelectorAll('script')) {
      for (final match in pattern.allMatches(script.text)) {
        final literal = match.group(1) ?? match.group(2);
        if (literal == null) continue;
        final message = _decodeAlertLiteral(literal);
        if (message.trim().isNotEmpty) return message;
      }
    }
    return null;
  }

  /// 서버 문구의 특수 표기를 변환.
  String _decodeAlertLiteral(String value) {
    return value.replaceAllMapped(
      RegExp(
        r'\\(?:u\{[0-9a-fA-F]{1,6}\}|u[0-9a-fA-F]{4}|x[0-9a-fA-F]{2}|\r\n|[\s\S])',
      ),
      (match) {
        final escaped = match[0]!.substring(1);
        if (escaped.length > 1 &&
            (escaped.startsWith('u') || escaped.startsWith('x'))) {
          final hex = escaped.startsWith('u{')
              ? escaped.substring(2, escaped.length - 1)
              : escaped.substring(1);
          final codePoint = int.parse(hex, radix: 16);
          return codePoint <= 0x10ffff
              ? String.fromCharCode(codePoint)
              : match[0]!;
        }
        return switch (escaped) {
          'n' => '\n',
          'r' => '\r',
          't' => '\t',
          'b' => '\b',
          'f' => '\f',
          'v' => '\v',
          '0' => '\x00',
          '\n' || '\r' || '\r\n' => '',
          _ => escaped,
        };
      },
    );
  }
}
