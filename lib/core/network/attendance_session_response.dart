import 'package:html/parser.dart' as html;

/// Recognizes authentication pages returned with HTTP 200 by attendance SSO.
bool isAttendanceSessionExpired(String body) {
  final document = html.parse(body);
  final text = (document.body?.text ?? body).replaceAll(RegExp(r'\s+'), ' ');
  if (text.contains('통합 로그인') ||
      text.contains('장시간 사용이 없어 로그아웃') ||
      body.contains('장시간 사용이 없어 로그아웃') ||
      document.querySelector('input[name="USER_ID"], input[name="PASSWD"]') !=
          null) {
    return true;
  }

  // A normal page may contain a logout link; inspect only error/redirect cues.
  if (text.contains('[오류]') && body.contains('/site/login/logout.php')) {
    return true;
  }
  final redirect = RegExp(
    r'''\bdocument\s*\.\s*location\s*\.\s*replace\s*\(\s*["']https?://(?:ap\.hongik\.ac\.kr/site/login/logout\.php|(?:www\.)?hongik\.ac\.kr/?)["']\s*\)''',
    caseSensitive: false,
  );
  return document
      .querySelectorAll('script')
      .any((script) => redirect.hasMatch(script.text));
}
