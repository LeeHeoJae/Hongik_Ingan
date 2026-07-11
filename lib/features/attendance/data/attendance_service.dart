import 'package:dio/dio.dart';
import 'package:hongik_ingan/core/logging/logger.dart';
import 'package:hongik_ingan/core/network/school_request_options.dart';
import 'package:hongik_ingan/core/network/school_transport.dart';
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
  });

  const LectureFetchResult.success(Lecture lecture)
    : this._(
        status: LectureFetchStatus.success,
        message: '활성 수업을 찾았습니다.',
        lecture: lecture,
      );

  const LectureFetchResult.empty()
    : this._(status: LectureFetchStatus.empty, message: '현재 출석 가능한 수업이 없습니다.');

  const LectureFetchResult.failure({required String message, Object? error})
    : this._(
        status: LectureFetchStatus.failure,
        message: message,
        error: error,
      );

  final LectureFetchStatus status;
  final String message;
  final Lecture? lecture;
  final Object? error;
}

/// 출결 서버와 통신해 현재 출석 가능한 강의를 조회하고 제출.
class AttendanceService {
  const AttendanceService(this._transport);

  final SchoolHttpTransport _transport;

  /// 현재 출석 가능한 강의를 조회.
  Future<LectureFetchResult> getActiveLecture() async {
    logMsg('출석 페이지 로딩');
    try {
      final response = await _transport.get(
        'https://at.hongik.ac.kr/index.jsp',
        options: const SchoolRequestOptions(
          timeoutProfile: NetworkTimeoutProfile.lectureFetch,
          responseType: ResponseType.plain,
          headers: {'Referer': 'https://at.hongik.ac.kr/login.jsp'},
        ),
      );
      final result = _parseLectureFetchResult(response.data?.toString());
      return _logResult(result);
    } on DioException catch (e) {
      return _logResult(
        LectureFetchResult.failure(message: '출석 서버에 연결하지 못했습니다.', error: e),
      );
    } catch (e) {
      return _logResult(
        LectureFetchResult.failure(message: '출석 페이지 형식을 분석하지 못했습니다.', error: e),
      );
    }
  }

  LectureFetchResult _parseLectureFetchResult(String? data) {
    final body = data?.toString() ?? '';
    if (body.trim().isEmpty) {
      return const LectureFetchResult.failure(message: '출석 서버 응답이 비어 있습니다.');
    }

    final document = html.parse(data);
    if (_looksLikeLoginPage(document.body?.text ?? body, body)) {
      return const LectureFetchResult.failure(message: '출석 서버 세션이 만료되었습니다.');
    }

    final table = document.querySelector('table');
    if (table == null) {
      return const LectureFetchResult.failure(message: '출석 페이지를 찾지 못했습니다.');
    }

    final rows = table.querySelectorAll('tbody > tr');
    final active = _findActiveLecture(rows);
    if (active == null) {
      return const LectureFetchResult.empty();
    }

    final lecture = _parseLectureRow(row: active.row, form: active.form);
    if (lecture == null) {
      return const LectureFetchResult.failure(message: '활성 수업 정보를 분석하지 못했습니다.');
    }
    return LectureFetchResult.success(lecture);
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
    const requiredParams = {'class_code', 'subject_code'};
    if (!params.keys.toSet().containsAll(requiredParams)) {
      return null;
    }
    return Lecture(
      name: _normalizeText(cells[2].text),
      time: _normalizeText(cells[4].text),
      attendanceParams: params,
    );
  }

  Map<String, String> _extractAttendanceParams(Element row) {
    Map<String, String> attendanceParams = {};

    final form = row.querySelector('form');
    if (form != null) {
      final action = form.attributes['action'] ?? '';
      if (action.contains('stud02.jsp')) {
        final inputs = form.querySelectorAll('input[type="hidden"]');
        for (var input in inputs) {
          final inputName = input.attributes['name'];
          final inputValue = input.attributes['value'];
          if (inputName != null && inputValue != null) {
            attendanceParams[inputName] = inputValue;
          }
        }
        logMsg('활성화된 수업 파라미터 개수: ${attendanceParams.length}');
      }
    }
    return attendanceParams;
  }

  String _normalizeText(String text) {
    return text.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  LectureFetchResult _logResult(LectureFetchResult result) {
    final level = result.status == LectureFetchStatus.failure
        ? LogLevel.error
        : LogLevel.debug;
    logMsg(
      '수업 목록 파싱 결과 - ${result.status.name} (${result.message})',
      level: level,
    );
    if (result.error != null) {
      logMsg('수업 목록 파싱 오류 상세: ${result.error}', level: LogLevel.error);
    }
    return result;
  }

  bool _looksLikeLoginPage(String text, String body) {
    return text.contains('통합 로그인') ||
        body.contains('name="USER_ID"') ||
        body.contains("name='USER_ID'") ||
        body.contains('name="PASSWD"') ||
        body.contains("name='PASSWD'");
  }

  Future<String> submitAttendance(
    Lecture lecture,
    String authCode,
    String? lat,
    String? lng,
  ) async {
    try {
      if (lecture.attendanceParams.isEmpty) {
        return '뭔가 잘못되었습니다.';
      }

      final payload = {
        ...lecture.attendanceParams,
        'key': authCode,
        'latitude': lat ?? '',
        'longitude': lng ?? '',
      };
      logMsg('출석 체크 전송 - 수업: ${lecture.name}');
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
      logMsg('출석 체크 응답: ${response.data}');
      final responseDocument = html.parse(response.data);
      final alertDiv = responseDocument.querySelector('.alert.alert-warning');
      if (alertDiv != null) {
        final message = alertDiv.text.trim().replaceAll(RegExp(r'\s+'), ' ');
        if (message.isNotEmpty) {
          logMsg('출석 결과(html): $message');
          if (message.contains('완료')) {
            return '출석이 완료되었습니다.';
          }
          return message;
        }
      }
      return '알 수 없는 응답이 수신되었습니다.';
    } on DioException catch (e) {
      logMsg('출석 에러 발생: ${e.message}', level: .error);
      if (e.response != null) {
        logMsg('에러 상세 내용: ${e.response?.data}', level: .debug);
      }
      return '네트워크 에러가 발생했습니다.';
    } catch (e) {
      logMsg('알 수 없는 에러: $e', level: .error);
      return '알 수 없는 에러가 발생했습니다: $e';
    }
  }
}
