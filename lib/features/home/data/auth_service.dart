import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:hongik_ingan/core/logging/logger.dart';
import 'package:hongik_ingan/core/network/attendance_session_response.dart';
import 'package:hongik_ingan/core/network/school_log_interceptor.dart';
import 'package:hongik_ingan/core/network/school_request_options.dart';

import '../../../core/network/school_transport.dart';
import '../domain/session_status.dart';

class AuthService {
  const AuthService(this._transport);

  final SchoolTransport _transport;

  /// Reuse SSO cookies first; reauthenticate only when activation rejects them.
  Future<bool> recoverAttendanceSession({
    String? studentId,
    String? password,
    Future<String?> Function()? readPassword,
    required bool Function() canContinue,
  }) async {
    if (!canContinue()) return false;
    try {
      await _activateAttendanceSession(canContinue: canContinue);
      logMsg('attendance recovery result=reactivated', level: LogLevel.info);
      return canContinue();
    } on AttendanceSessionException catch (error) {
      logMsg(
        'attendance recovery activationRejected '
        'sessionExpired=${error.sessionExpired} '
        'ssoIntegrationError=${error.ssoIntegrationError}',
        level: LogLevel.info,
      );
      if (!canContinue() ||
          (!error.sessionExpired && !error.ssoIntegrationError)) {
        return false;
      }
      final recoveryPassword = password ?? await readPassword?.call();
      if (!canContinue() ||
          studentId == null ||
          studentId.isEmpty ||
          recoveryPassword == null ||
          recoveryPassword.isEmpty) {
        logMsg(
          'attendance recovery result=skipped reason=noEligibleCredentials',
          level: LogLevel.info,
        );
        return false;
      }
      logMsg('attendance recovery stage=reauthenticate', level: LogLevel.info);
      final restored =
          await login(studentId, recoveryPassword, canContinue: canContinue) ==
          'Success';
      logMsg(
        'attendance recovery result=${restored ? 'restored' : 'failed'}',
        level: LogLevel.info,
      );
      return canContinue() && restored;
    } catch (e, stack) {
      logMsg(
        '출결 세션 복구 실패: $e',
        level: LogLevel.error,
        error: e,
        stackTrace: stack,
      );
      return false;
    }
  }

  /// 로그인 시도.
  ///
  /// RTT 절감을 위해 로그인에 실패하더라도 로그인 요청은 보낸다.
  Future<String> login(
    String studentId,
    String password, {
    bool Function()? canContinue,
  }) async {
    if (canContinue != null && !canContinue()) return 'Cancelled';
    try {
      final loginData = {'USER_ID': studentId, 'PASSWD': password};
      await _transport.get(
        'https://my.hongik.ac.kr/my/login.do',
        options: const SchoolRequestOptions(
          timeoutProfile: NetworkTimeoutProfile.loginPage,
        ),
      );
      if (canContinue != null && !canContinue()) return 'Cancelled';
      logMsg('로그인 시도 시작', level: LogLevel.info);
      final validation = await _verifyCredentials(loginData);
      if (canContinue != null && !canContinue()) return 'Cancelled';
      if (!validation.isAccepted) {
        logMsg('로그인 실패: ${validation.message}', level: LogLevel.warning);
        return validation.message;
      }
      await _establishSession(loginData, canContinue: canContinue);
      if (canContinue != null && !canContinue()) return 'Cancelled';
      await _activateAttendanceSession(canContinue: canContinue);
      if (canContinue != null && !canContinue()) return 'Cancelled';
      logMsg('로그인 성공', level: LogLevel.info);
      return 'Success';
    } on AttendanceSessionException catch (e, stack) {
      logMsg(e.message, level: .error, error: e, stackTrace: stack);
      return e.message;
    } on DioException catch (e, stack) {
      if (e.response case final response?) logResponseDiagnostics(response);
      logMsg(
        '로그인 에러 발생: ${e.message}',
        level: .error,
        error: e.type,
        stackTrace: stack,
        context: responseLogContext(e.response, request: e.requestOptions),
      );
      return 'Error:: ${e.response?.data}';
    } catch (e, stack) {
      logMsg('알 수 없는 에러: $e', level: .error, error: e, stackTrace: stack);
      return 'Unknown Error';
    }
  }

  /// 로그인 후 출결 서버 세션을 명시적으로 활성화하고 초기화.
  ///
  /// login.jsp에서 JSESSIONID를 발급받은 뒤 index.jsp를 거쳐야
  /// stud01.jsp에 접근할 수 있다.
  Future<void> _activateAttendanceSession({
    bool Function()? canContinue,
  }) async {
    if (canContinue != null && !canContinue()) return;
    logMsg('출결 서버 세션 활성화');
    final loginResponse = await _transport.get<String>(
      'https://at.hongik.ac.kr/login.jsp',
      options: const SchoolRequestOptions(
        timeoutProfile: NetworkTimeoutProfile.attendanceSession,
        responseType: ResponseType.plain,
        headers: {'Referer': 'https://my.hongik.ac.kr/'},
      ),
    );
    if (canContinue != null && !canContinue()) return;
    _validateAttendanceResponse(loginResponse);

    final hasAttendanceSession = await _transport.hasCookie(
      Uri.parse('https://at.hongik.ac.kr/'),
      'JSESSIONID',
    );
    if (canContinue != null && !canContinue()) return;
    if (!hasAttendanceSession) {
      throw const AttendanceSessionException('출결 서버 세션 쿠키를 발급받지 못했어요.');
    }

    final indexResponse = await _transport.get<String>(
      'https://at.hongik.ac.kr/index.jsp',
      options: const SchoolRequestOptions(
        timeoutProfile: NetworkTimeoutProfile.attendanceSession,
        responseType: ResponseType.plain,
        headers: {'Referer': 'https://at.hongik.ac.kr/login.jsp'},
      ),
    );
    if (canContinue != null && !canContinue()) return;
    _validateAttendanceResponse(indexResponse);
  }

  /// 출결 서버 응답 본문을 검사해 실제 사용 가능한 페이지인지 확인.
  void _validateAttendanceResponse(Response<String> response) {
    logResponseDiagnostics(response);
    final responseBody = response.data ?? '';
    final looksLikeIntegrationError =
        responseBody.contains('시스템 연동') && responseBody.contains('오류');
    final expiredPage = isAttendanceSessionExpired(responseBody);
    logMsg(
      'attendance session activation status=${response.statusCode} '
      'expiredPage=$expiredPage ssoIntegrationError=$looksLikeIntegrationError',
      level:
          expiredPage ||
              looksLikeIntegrationError ||
              response.statusCode != 200 ||
              responseBody.trim().isEmpty
          ? LogLevel.warning
          : LogLevel.info,
      context: responseLogContext(response),
    );
    if (expiredPage ||
        (response.statusCode != null &&
            response.statusCode! >= 300 &&
            response.statusCode! < 400)) {
      throw const AttendanceSessionException(
        '출결 서버가 로그인 세션을 인식하지 못했어요.',
        sessionExpired: true,
      );
    }
    if (looksLikeIntegrationError) {
      throw const AttendanceSessionException(
        '출결 시스템 연동 중 오류가 발생했어요.',
        ssoIntegrationError: true,
      );
    }
    if (responseBody.trim().isEmpty || response.statusCode != 200) {
      throw const AttendanceSessionException('출결 서버 응답을 확인하지 못했어요.');
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
    logResponseDiagnostics(response);
    logMsg(
      'SSO 서버 응답: status=${response.statusCode}',
      context: responseLogContext(response),
    );
    return SsoValidationResult.fromJson(
      Map<String, dynamic>.from(response.data),
    );
  }

  /// 실제 로그인 시도, 쿠키추출.
  Future<void> _establishSession(
    Map<String, String> loginData, {
    bool Function()? canContinue,
  }) async {
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
    if (canContinue != null && !canContinue()) return;
    logResponseDiagnostics(classNetResponse);
    logMsg(
      'LoginExec3 응답 : status=${classNetResponse.statusCode}',
      context: responseLogContext(classNetResponse),
    );
    await _parseCookies(classNetResponse.data.toString());
  }

  /// HTML에 숨겨진 쿠키를 추출.
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

  /// 재시도 정책으로 세션 상태 확인.
  Future<SessionStatus> checkSessionStatus() async {
    const maxAttempts = 2;
    for (var attempts = 0; attempts < maxAttempts; attempts++) {
      final status = await _requestSessionStatus();
      if (status != SessionStatus.unknown) {
        return status;
      }
      if (attempts + 1 < maxAttempts) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
    return SessionStatus.unknown;
  }

  /// 세션 상태 확인.
  Future<SessionStatus> _requestSessionStatus() async {
    try {
      final response = await _transport.get(
        'https://at.hongik.ac.kr/index.jsp',
        options: SchoolRequestOptions(
          timeoutProfile: NetworkTimeoutProfile.sessionCheck,
          responseType: ResponseType.plain,
          followRedirects: true,
          validateStatus: (status) {
            return status != null && status < 500;
          },
        ),
      );
      final responseBody = response.data?.toString() ?? '';
      logResponseDiagnostics(response);
      final containsLoginPage = isAttendanceSessionExpired(responseBody);
      final containsSsoIntegrationError =
          responseBody.contains('시스템 연동') && responseBody.contains('오류');
      logMsg(
        'attendance session check status=${response.statusCode} '
        'expiredPage=$containsLoginPage ssoIntegrationError=$containsSsoIntegrationError',
        level:
            containsLoginPage ||
                containsSsoIntegrationError ||
                response.statusCode != 200 ||
                responseBody.trim().isEmpty
            ? LogLevel.warning
            : LogLevel.info,
        context: responseLogContext(response),
      );
      if (containsSsoIntegrationError) {
        return SessionStatus.integrationError;
      }
      if (containsLoginPage) {
        logMsg('세션이 만료되었습니다.', level: LogLevel.info);
        return SessionStatus.expired;
      }
      final statusCode = response.statusCode;
      if (statusCode == null ||
          statusCode < 200 ||
          statusCode >= 300 ||
          responseBody.trim().isEmpty) {
        logMsg('세션 응답을 판정하지 못했습니다.', level: LogLevel.warning);
        return SessionStatus.unknown;
      }
      logMsg('세션이 유효합니다.');
      return SessionStatus.valid;
    } catch (e, stack) {
      logMsg(
        '세션 확인 중 오류 발생: $e',
        level: LogLevel.warning,
        error: e is DioException ? e.type : e,
        stackTrace: stack,
        context: e is DioException
            ? responseLogContext(e.response, request: e.requestOptions)
            : const {},
      );
      return SessionStatus.unknown;
    }
  }
}

class AttendanceSessionException implements Exception {
  const AttendanceSessionException(
    this.message, {
    this.sessionExpired = false,
    this.ssoIntegrationError = false,
  });

  final String message;
  final bool sessionExpired;
  final bool ssoIntegrationError;
}

class SsoValidationResult {
  const SsoValidationResult(this.isAccepted, this.message);

  final bool isAccepted;
  final String message;

  factory SsoValidationResult.fromJson(Map<String, dynamic> json) {
    return SsoValidationResult(
      json['result_code'] == 'Y',
      json['result_msg'] ?? 'Login failed',
    );
  }
}
