import 'package:dio/dio.dart';
import 'package:hongik_ingan/core/logging/logger.dart';
import 'package:hongik_ingan/features/attendance/domain/lecture.dart';
import 'package:html/parser.dart' as html;

import 'package:hongik_ingan/core/network_client.dart';

// partial은 일부가 누락(스킵)된 경우
enum LectureFetchStatus { success, empty, partial, failure }

class LectureFetchResult {
  const LectureFetchResult({
    required this.status,
    required this.lectures,
    required this.message,
    required this.tableRowCount,
    required this.skippedRowCount,
    this.error,
    this.warnings = const [],
  });

  final LectureFetchStatus status;
  final List<Lecture> lectures;
  final String message;
  final int tableRowCount;
  final int skippedRowCount;
  final Object? error;
  final List<String> warnings;

  int get parsedCount => lectures.length;

  String get diagnosticSummary {
    final buffer = StringBuffer(
      '상태: ${status.name}, 파싱: $parsedCount개, 검사한 행: $tableRowCount개, '
      '스킵: $skippedRowCount개',
    );
    if (warnings.isNotEmpty) {
      buffer.write(', 경고: ${warnings.join(' / ')}');
    }
    return buffer.toString();
  }
}

class AttendanceService {
  Dio get dio => NetworkClient().dio;

  Future<LectureFetchResult> getLectures() async {
    logMsg('출석 페이지 로딩 (수업 목록)');
    try {
      final response = await dio.get(
        'https://at.hongik.ac.kr/index.jsp',
        options: schoolRequestOptions(
          timeoutProfile: NetworkTimeoutProfile.lectureFetch,
          responseType: ResponseType.plain,
          headers: {'Referer': 'https://at.hongik.ac.kr/login.jsp'},
        ),
      );

      final body = response.data?.toString() ?? '';
      if (body.trim().isEmpty) {
        return _logResult(
          const LectureFetchResult(
            status: LectureFetchStatus.failure,
            lectures: [],
            message: '출석 서버 응답이 비어 있어 수업 정보를 읽지 못했습니다.',
            tableRowCount: 0,
            skippedRowCount: 0,
          ),
        );
      }

      final document = html.parse(response.data);
      if (_looksLikeLoginPage(document.body?.text ?? body, body)) {
        return _logResult(
          const LectureFetchResult(
            status: LectureFetchStatus.failure,
            lectures: [],
            message: '출석 서버 세션이 만료되어 수업 정보를 읽지 못했습니다.',
            tableRowCount: 0,
            skippedRowCount: 0,
          ),
        );
      }

      final lectures = <Lecture>[];
      final warnings = <String>[];
      final skippedRowTexts = <String>[];
      final rows = document.querySelectorAll('tbody > tr');
      var skippedRowCount = 0;

      for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
        final row = rows[rowIndex];
        final cells = row.querySelectorAll('td');
        if (cells.length < 5) {
          skippedRowCount++;
          final rowText = _normalizeText(row.text);
          skippedRowTexts.add(rowText);
          if (warnings.length < 3) {
            warnings.add(
              '${rowIndex + 1}번째 행의 열 개수 부족(${cells.length}개), '
              '내용: ${_snippet(rowText)}',
            );
          }
          continue;
        }

        String name = cells[2].text.trim().replaceAll(RegExp(r'\s+'), ' ');
        String time = cells[4].text.trim().replaceAll(RegExp(r'\s+'), ' ');
        Map<String, String> attendanceParams = {};

        final form = row.querySelector('form');
        if (form != null) {
          // 존재
          final action = form.attributes['action'] ?? '';
          if (action.contains('stud02.jsp')) {
            final inputs = form.querySelectorAll(
              'input[type="hidden"]',
            ); // 세부 사항들
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

        lectures.add(
          Lecture(name: name, time: time, attendanceParams: attendanceParams),
        );
      }

      final result = _buildFetchResult(
        lectures: lectures,
        hasTable: document.querySelectorAll('table').isNotEmpty,
        tableRowCount: rows.length,
        skippedRowCount: skippedRowCount,
        skippedRowTexts: skippedRowTexts,
        pageText: document.body?.text ?? body,
        warnings: warnings,
      );
      return _logResult(result);
    } catch (e) {
      return _logResult(
        LectureFetchResult(
          status: LectureFetchStatus.failure,
          lectures: const [],
          message: '수업 목록을 가져오거나 파싱하는 중 오류가 발생했습니다.',
          tableRowCount: 0,
          skippedRowCount: 0,
          error: e,
        ),
      );
    }
  }

  LectureFetchResult _buildFetchResult({
    required List<Lecture> lectures,
    required bool hasTable,
    required int tableRowCount,
    required int skippedRowCount,
    required List<String> skippedRowTexts,
    required String pageText,
    required List<String> warnings,
  }) {
    if (lectures.isNotEmpty) {
      final status = skippedRowCount > 0
          ? LectureFetchStatus.partial
          : LectureFetchStatus.success;
      final message = status == LectureFetchStatus.partial
          ? '일부 행은 건너뛰었지만 수업 정보를 읽었습니다.'
          : '수업 정보를 정상적으로 읽었습니다.';
      return LectureFetchResult(
        status: status,
        lectures: lectures,
        message: message,
        tableRowCount: tableRowCount,
        skippedRowCount: skippedRowCount,
        warnings: warnings,
      );
    }

    if (_containsEmptyLectureMessage(pageText) ||
        skippedRowTexts.any(_containsEmptyLectureMessage) ||
        (hasTable && tableRowCount == 0)) {
      return LectureFetchResult(
        status: LectureFetchStatus.empty,
        lectures: const [],
        message: '현재 출석 가능한 수업이 없습니다.',
        tableRowCount: tableRowCount,
        skippedRowCount: skippedRowCount,
        warnings: warnings,
      );
    }

    if (!hasTable) {
      return LectureFetchResult(
        status: LectureFetchStatus.failure,
        lectures: const [],
        message: '출석 페이지에서 수업 표를 찾지 못했습니다.',
        tableRowCount: tableRowCount,
        skippedRowCount: skippedRowCount,
        warnings: warnings,
      );
    }

    return LectureFetchResult(
      status: LectureFetchStatus.failure,
      lectures: const [],
      message: '출석 페이지 형식이 예상과 달라 수업 정보를 읽지 못했습니다.',
      tableRowCount: tableRowCount,
      skippedRowCount: skippedRowCount,
      warnings: warnings,
    );
  }

  String _normalizeText(String text) {
    return text.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  String _snippet(String text) {
    if (text.isEmpty) {
      return '(비어 있음)';
    }
    const maxLength = 80;
    if (text.length <= maxLength) {
      return text;
    }
    return '${text.substring(0, maxLength)}...';
  }

  LectureFetchResult _logResult(LectureFetchResult result) {
    final level = result.status == LectureFetchStatus.failure
        ? LogLevel.error
        : result.status == LectureFetchStatus.partial
        ? LogLevel.warning
        : LogLevel.debug;
    logMsg(
      '수업 목록 파싱 결과 - ${result.message} (${result.diagnosticSummary})',
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

  bool _containsEmptyLectureMessage(String text) {
    final normalizedText = _normalizeText(text).toLowerCase();
    return ((normalizedText.contains('수업') ||
                normalizedText.contains('강의') ||
                normalizedText.contains('출석') ||
                normalizedText.contains('출결')) &&
            normalizedText.contains('없')) ||
        normalizedText.contains('자료가 없습니다') ||
        normalizedText.contains('등록된 자료가 없습니다') ||
        normalizedText.contains('조회된 자료') ||
        normalizedText.contains('검색된 결과가 없습니다') ||
        normalizedText.contains('no data');
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
      final options = schoolRequestOptions(
        timeoutProfile: NetworkTimeoutProfile.attendanceSubmit,
        headers: {
          'Host': 'at.hongik.ac.kr',
          'Origin': 'https://at.hongik.ac.kr',
          'Referer': 'https://at.hongik.ac.kr/stud02.jsp',
        },
        responseType: ResponseType.plain,
        contentType: 'application/x-www-form-urlencoded',
      );
      final response = await dio.post(
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
