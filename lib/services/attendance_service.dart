import 'package:dio/dio.dart';
import 'package:hongik_ingan/core/logger.dart';
import 'package:hongik_ingan/models/lecture.dart';
import 'package:html/parser.dart' as html;

import '../core/network_client.dart';

class AttendanceService {
  final Dio dio = NetworkClient().dio;

  Future<List<Lecture>> getLectures() async {
    logMsg('출석 페이지 로딩 (수업 목록)');
    try {
      final response = await dio.get(
        'https://at.hongik.ac.kr/index.jsp',
        options: Options(
          responseType: ResponseType.plain,
          headers: {'Referer': 'https://at.hongik.ac.kr/login.jsp'},
        ),
      );

      final document = html.parse(response.data);
      List<Lecture> lectures = [];

      final rows = document.querySelectorAll('tbody > tr');
      for (var row in rows) {
        final cells = row.querySelectorAll('td');
        if (cells.length >= 5) {
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
              logMsg('활성화된 수업 파라미터: $attendanceParams');
            }
          }

          lectures.add(
            Lecture(name: name, time: time, attendanceParams: attendanceParams),
          );
        }
      }

      logMsg('파싱된 수업 개수: ${lectures.length}');
      return lectures;
    } catch (e) {
      logMsg('수업 목록 가져오기 실패: $e');
      return [];
    }
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
      logMsg('Payload: $payload');
      final options = Options(
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
