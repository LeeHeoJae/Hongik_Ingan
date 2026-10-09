import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/core/network/attendance_session_response.dart';

void main() {
  for (final scenario in [
    (body: '', empty: true, integration: false, sso: false),
    (body: '시스템 연동 오류', empty: false, integration: true, sso: false),
    (body: 'SSO 시스템 연동 오류', empty: false, integration: true, sso: true),
  ]) {
    test(
      'response cues retain endpoint integration policy: ${scenario.body}',
      () {
        final inspected = AttendanceSessionResponse(scenario.body);
        expect(inspected.isEmpty, scenario.empty);
        expect(inspected.integrationError, scenario.integration);
        expect(inspected.ssoIntegrationError, scenario.sso);
        expect(inspected.sessionExpired, isFalse);
      },
    );
  }

  const attendancePage = '''
<div class="panel-heading clearfix">
  <a href="stud04.jsp">Status</a><a href="logout.jsp">Logout</a>
</div>
<table><tbody><tr><td>
  <form action="stud02.jsp"><input type="hidden" name="USER_ID" value="STUDENT"></form>
</td></tr></tbody></table>
''';

  test('hidden student identity does not indicate a login page', () {
    expect(isAttendanceSessionExpired(attendancePage), isFalse);
  });

  for (final script in [
    '''function onSessionTimeout() {
      alert("장시간 사용이 없어 로그아웃 되었습니다.");
      document.location.replace("https://www.hongik.ac.kr/");
    }''',
    '''const loginLabel = "통합 로그인";''',
    '''// document.location.replace("https://www.hongik.ac.kr/");''',
  ]) {
    test('unused script content does not invalidate attendance: $script', () {
      expect(
        isAttendanceSessionExpired('$attendancePage<script>$script</script>'),
        isFalse,
      );
      expect(
        isAttendanceSessionExpired('<table></table><script>$script</script>'),
        isFalse,
      );
    });
  }

  for (final body in [
    '<form><input name="USER_ID"><input name="PASSWD" type="password"></form>',
    '<h1>통합 로그인</h1>',
    '<p>장시간 사용이 없어 로그아웃 되었습니다.</p>',
    '<script>alert("장시간 사용이 없어 로그아웃 되었습니다.");</script>',
    '<script>document.location.replace("https://www.hongik.ac.kr/");</script>',
  ]) {
    test('authentication failure is still recognized: $body', () {
      expect(isAttendanceSessionExpired(body), isTrue);
    });
  }

  test('immediate expiry alert takes precedence over attendance content', () {
    expect(
      isAttendanceSessionExpired(
        '$attendancePage<script>alert("장시간 사용이 없어 로그아웃 되었습니다.");</script>',
      ),
      isTrue,
    );
  });
}
