import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:hongik_ingan/core/logging/logger.dart';
import 'package:hongik_ingan/core/network/school_request_options.dart';

import '../../../core/network/school_transport.dart';

class AuthService {
  const AuthService(this._transport);

  final SchoolTransport _transport;

  /// 로그인 시도.
  ///
  /// RTT 절감을 위해 로그인에 실패하더라도 로그인 요청은 보낸다.
  Future<String> login(String studentId, String password) async {
    try {
      final loginData = {'USER_ID': studentId, 'PASSWD': password};
      await _transport.get(
        'https://my.hongik.ac.kr/my/login.do',
        options: const SchoolRequestOptions(
          timeoutProfile: NetworkTimeoutProfile.loginPage,
        ),
      );
      logMsg('로그인 시도 시작');
      final ssoResponseFuture = _verifyCredentials(loginData);
      final classNetResponseFuture = _establishSession(loginData);

      final validation = await ssoResponseFuture;
      if (!validation.isAccepted) {
        logMsg('로그인 실패: ${validation.message}');
        return validation.message;
      }
      await classNetResponseFuture;

      logMsg('출결 서버 세션 활성화');
      await _transport.get(
        'https://at.hongik.ac.kr/login.jsp',
        options: const SchoolRequestOptions(
          timeoutProfile: NetworkTimeoutProfile.attendanceSession,
          headers: {'Referer': 'https://my.hongik.ac.kr/'},
        ),
      );
      logMsg('로그인 성공');
      return 'Success';
    } on DioException catch (e) {
      logMsg('로그인 에러 발생: ${e.message}', level: .error);
      if (e.response != null) {
        logMsg('에러 상세 내용: ${e.response?.data}', level: .debug);
      }
      return 'Error:: ${e.response?.data}';
    } catch (e) {
      logMsg('알 수 없는 에러: $e', level: .error);
      return 'Unknown Error';
    }
  }

  /// 학번과 비밀번호가 SSO에서 유효한지 검증.
  Future<SsoValidationResult> _verifyCredentials(
    Map<String, String> loginData,
  ) async {
    logMsg('SSO 서버로 인증 시도');
    final response = await _transport.post(
      'https://ap.hongik.ac.kr/login/LoginCheck_SSO.php',
      data: loginData,
      options: const SchoolRequestOptions(
        timeoutProfile: NetworkTimeoutProfile.loginPost,
        contentType: Headers.formUrlEncodedContentType,
      ),
    );
    logMsg('SSO 서버 응답: $response');
    return SsoValidationResult.fromJson(
      Map<String, dynamic>.from(response.data),
    );
  }

  /// 실제 로그인 시도, 쿠키추출.
  Future<void> _establishSession(Map<String, String> loginData) async {
    logMsg('LoginExec3 로그인 시도');
    final classNetResponse = await _transport.post(
      'https://ap.hongik.ac.kr/login/LoginExec3.php',
      data: loginData,
      options: const SchoolRequestOptions(
        timeoutProfile: NetworkTimeoutProfile.loginPost,
        contentType: Headers.formUrlEncodedContentType,
        headers: {
          'Referer': 'https://ap.hongik.ac.kr/login/login.jsp',
          'Origin': 'https://ap.hongik.ac.kr',
        },
      ),
    );
    logMsg('LoginExec3 응답 : ${classNetResponse.data}');
    await _parseCookies(classNetResponse.data.toString());
  }

  /// Html에 숨겨져 있는 Cookie를 추출.
  ///
  /// 세션 쿠키가 이 안에 있기 때문에 중요하다.
  Future<void> _parseCookies(String htmlBody) async {
    // SetCookie('이름', '값'...) 패턴을 찾는 정규식
    final regex = RegExp(r"SetCookie\s*\(\s*'([^']+)'\s*,\s*'([^']+)'");
    final matches = regex.allMatches(htmlBody);

    List<Cookie> extractedCookies = [];
    for (final match in matches) {
      final name = match.group(1);
      final value = match.group(2);

      if (name != null && value != null) {
        extractedCookies.add(
          Cookie(name, value)
            ..domain = '.hongik.ac.kr'
            ..path = '/'
            ..secure = true
            ..httpOnly = true,
        );
      }
    }
    logMsg('HTML에서 강제로 뽑아낸 쿠키 개수: ${extractedCookies.length}개');
    logMsg(
      '추출된 쿠키: ${extractedCookies.map((cookie) => cookie.name).join(', ')}',
      level: LogLevel.info,
    );
    await _transport.saveAuthCookies(extractedCookies);
  }

  Future<bool> isSessionValid() async {
    try {
      // TODO : 세션이 진짜 만료된건지 패킷 손실 등의 원인인지 체크
      final response = await _transport.get(
        'https://at.hongik.ac.kr/stud01.jsp',
        options: SchoolRequestOptions(
          timeoutProfile: NetworkTimeoutProfile.sessionCheck,
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

class SsoValidationResult {
  const SsoValidationResult(this.isAccepted, this.message);

  final bool isAccepted;
  final String message;

  factory SsoValidationResult.fromJson(Map<String, dynamic> json) {
    return SsoValidationResult(
      json['result_code'] != 'R' && json['result_code'] != 'N',
      json['result_msg'] ?? 'Login failed',
    );
  }
}
