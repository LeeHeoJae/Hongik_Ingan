import 'package:dio/dio.dart';
import 'package:hongik_ingan/core/logger.dart';

import '../core/network_client.dart';

class AttendanceService {
  final Dio dio = NetworkClient().dio;

  Future<String> submitAttendance(
    String authCode,
    String? lat,
    String? lng,
  ) async {
    try {
      logMsg('출석 체크 전송');
      final payload = {
        'key': authCode,
        'yy': '2026', //연도
        'hakgi': '1', //학기
        'haksu': '008749', //학수번호
        'bunban': '1', //분반
        'weekno': '5', //n주차
        'week': '4', //요일
        'time': '6', //교시
        'latitude': lat,
        'longitude': lng,
      };
      final options = Options(
        headers: {
          'Host': 'at.hongik.ac.kr',
          'Origin': 'https://at.hongik.ac.kr',
          'Referer': 'https://at.hongik.ac.kr/stud02.jsp',
        },
        responseType: ResponseType.plain,
      );
      final response = await dio.post(
        'https://at.hongik.ac.kr/stud02_proc.jsp',
        data: payload,
        options: options,
      );
      logMsg('출석 체크 응답: ${response.data}');
      return response.data.toString();
    } on DioException catch (e) {
      logMsg('로그인 에러 발생: ${e.message}');
      if (e.response != null) {
        logMsg('에러 상세 내용: ${e.response?.data}');
      }
      return '네트워크 에러';
    } catch (e) {
      logMsg('알 수 없는 에러: $e');
      return '알수 없는 에러: $e';
    }
  }
}
