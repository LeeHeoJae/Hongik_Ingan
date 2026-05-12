import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:hongik_ingan/core/logger.dart';
import 'package:hongik_ingan/core/network_client.dart';

class AuthService {
  final Dio dio = NetworkClient().dio;

  // RTT 절감을 위해 로그인에 실패하더라도 로그인 요청은 보냄
  Future<String> login(String studentId, String password) async {
    try {
      final loginData = {'USER_ID': studentId, 'PASSWD': password};
      await dio.get('https://my.hongik.ac.kr/my/login.do');
      logMsg('로그인 시도 시작');
      final ssoResponseFuture = requestValidate(loginData);
      final classNetResponseFuture = requestLogin(loginData);

      final ssoResponse = await ssoResponseFuture;
      if (ssoResponse['result_code'] == 'R' ||
          ssoResponse['result_code'] == 'N') {
        logMsg('로그인 차단됨: $ssoResponse');
        return ssoResponse['result_msg'] ?? 'Login failed';
      }

      final classNetResponse = await classNetResponseFuture;
      await parseCookies(classNetResponse);

      logMsg('출결 서버 세션 활성화');
      await dio.get(
        'https://at.hongik.ac.kr/login.jsp',
        options: Options(headers: {'Referer': 'https://my.hongik.ac.kr/'}),
      );
      logMsg('로그인 성공');
      return 'Success';
    } on DioException catch (e) {
      logMsg('로그인 에러 발생: ${e.message}');
      if (e.response != null) {
        logMsg('에러 상세 내용: ${e.response?.data}');
      }
      return 'Error:: ${e.response?.data}';
    } catch (e) {
      logMsg('알 수 없는 에러: $e');
      return 'Unknown Error';
    }
  }

  Future<Map<String, dynamic>> requestValidate(
    Map<String, String> loginData,
  ) async {
    logMsg('SSO 서버로 인증 시도');
    final response = await dio.post(
      'https://ap.hongik.ac.kr/login/LoginCheck_SSO.php',
      data: loginData,
    );
    logMsg('SSO 서버 응답: $response');
    return Map<String, dynamic>.from(response.data);
  }

  Future<String> requestLogin(Map<String, String> loginData) async {
    logMsg('LoginExec3 로그인 시도');
    final classNetResponse = await dio.post(
      'https://ap.hongik.ac.kr/login/LoginExec3.php',
      data: loginData,
      options: Options(
        headers: {
          'Referer': 'https://ap.hongik.ac.kr/login/login.jsp',
          'Origin': 'https://ap.hongik.ac.kr',
        },
      ),
    );
    logMsg('LoginExec3 응답 : ${classNetResponse.data}');
    return classNetResponse.data.toString();
  }

  Future<void> parseCookies(String htmlBody) async {
    // SetCookie('이름', '값'...) 패턴을 찾는 정규식
    final regex = RegExp(r"SetCookie\s*\(\s*'([^']+)'\s*,\s*'([^']+)'");
    final matches = regex.allMatches(htmlBody);

    List<Cookie> extractedCookies = [];
    for (final match in matches) {
      final name = match.group(1);
      final value = match.group(2);

      if (name != null && value != null) {
        // 쿠키 객체를 만들어서 리스트에 담기
        extractedCookies.add(
          Cookie(name, value)
            ..domain = '.hongik.ac.kr'
            ..path = '/',
        );
      }
    }
    logMsg('HTML에서 강제로 뽑아낸 쿠키 개수: ${extractedCookies.length}개');
    // 강제로 뽑아낸 쿠키들을 Dio의 CookieJar에 강제로 넣기
    await NetworkClient().cookieJar.saveFromResponse(
      Uri.parse('https://hongik.ac.kr'),
      extractedCookies,
    );
  }

  Future<bool> isSessionValid() async {
    try {
      final response = await dio.get(
        'https://at.hongik.ac.kr/stud01.jsp',
        options: Options(
          followRedirects: false,
          validateStatus: (status) {
            return status != null && status < 500;
          },
        ),
      );
      final isRedirectedToLogin =
          response.statusCode == 302 &&
          response.headers['location']?.first.contains('login') == true;
      final containsLoginString = response.data.toString().contains('통합 로그인');
      if (isRedirectedToLogin || containsLoginString) {
        logMsg('세션이 만료되었습니다.');
        return false;
      }
      logMsg('세션이 유효합니다.');
      return true;
    } catch (e) {
      logMsg('세션 확인 중 오류 발생: $e');
      return false;
    }
  }
}
