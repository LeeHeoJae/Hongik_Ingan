import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:hongik_ingan/core/network_client.dart';

class AuthService {
  final Dio dio = NetworkClient().dio;

  Future<bool> login(String studentId, String password) async {
    try {
      final loginData = {'USER_ID': studentId, 'PASSWD': password};
      await dio.get('https://my.hongik.ac.kr/my/login.do');
      print('1단계 SSO 서버로 인증 시작');
      final ssoResponse = await dio.post(
        'https://ap.hongik.ac.kr/login/LoginCheck_SSO.php',
        data: loginData,
      );
      print('1단계 응답 : ${ssoResponse.data}');
      print('2단계 쿠키 탈취');
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
      print('2단계 응답 : ${classNetResponse.data}');
      final htmlBody = classNetResponse.data.toString();

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

      print('HTML에서 강제로 뽑아낸 쿠키 개수: ${extractedCookies.length}개');

      // 강제로 뽑아낸 쿠키들을 Dio의 CookieJar에 억지로 쑤셔 넣기!
      await NetworkClient().cookieJar.saveFromResponse(
        Uri.parse('https://hongik.ac.kr'),
        extractedCookies,
      );

      print('3단계 : 출결 서버 세션 활성화 시작');
      await dio.get(
        'https://at.hongik.ac.kr/index.jsp',
        options: Options(headers: {'Referer': 'https://my.hongik.ac.kr/'}),
      );
      return true;
    } on DioException catch (e) {
      print('로그인 에러 발생: ${e.message}');
      if (e.response != null) {
        print('에러 상세 내용: ${e.response?.data}');
      }
      return false;
    } catch (e) {
      print('알 수 없는 에러: $e');
      return false;
    }
  }
}
