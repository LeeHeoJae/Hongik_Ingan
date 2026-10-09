import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;

/// Inspects one response without parsing its HTML again in feature services.
final class AttendanceSessionResponse {
  AttendanceSessionResponse(this.body);

  final String body;
  late final Document document = html.parse(body);
  bool get isEmpty => body.trim().isEmpty;
  late final bool integrationError =
      body.contains('시스템 연동') && body.contains('오류');

  // Lecture/submission endpoints historically require this more specific cue.
  bool get ssoIntegrationError =>
      integrationError && body.contains('SSO 시스템 연동');

  late final bool sessionExpired =
      !integrationError && _isSessionExpired(document);
}

/// Recognizes authentication pages returned with HTTP 200 by attendance SSO.
bool isAttendanceSessionExpired(String body) =>
    AttendanceSessionResponse(body).sessionExpired;

bool _isSessionExpired(Document document) {
  final text = _visibleText(document.body).replaceAll(RegExp(r'\s+'), ' ');
  if (text.contains('통합 로그인') ||
      text.contains('장시간 사용이 없어 로그아웃') ||
      document
          .querySelectorAll('input[name="USER_ID"], input[name="PASSWD"]')
          .any(
            (input) => input.attributes['type']?.toLowerCase() != 'hidden',
          )) {
    return true;
  }

  // A normal page may contain a logout link; inspect only error/redirect cues.
  if (text.contains('[오류]') &&
      document.outerHtml.contains('/site/login/logout.php')) {
    return true;
  }
  final redirect = RegExp(
    r'''^document\s*\.\s*location\s*\.\s*replace\s*\(\s*["']https?://(?:ap\.hongik\.ac\.kr/site/login/logout\.php|(?:www\.)?hongik\.ac\.kr/?)["']\s*\)''',
    caseSensitive: false,
  );
  final expiryAlert = RegExp(
    r'''^(?:window\s*\.\s*)?alert\s*\(\s*["'][^"']*장시간 사용이 없어 로그아웃''',
  );
  final leadingComments = RegExp(
    r'^(?:\s+|//[^\r\n]*(?:\r?\n|$)|/\*[\s\S]*?\*/)*',
  );
  return document.querySelectorAll('script').any((script) {
    // Recognize immediate error cues, not function bodies or string constants.
    final immediate = script.text.replaceFirst(leadingComments, '');
    return redirect.hasMatch(immediate) || expiryAlert.hasMatch(immediate);
  });
}

String _visibleText(Node? node) {
  if (node is Text) return node.data;
  if (node is Element &&
      (node.localName == 'script' || node.localName == 'style')) {
    return '';
  }
  return node?.nodes.map(_visibleText).join(' ') ?? '';
}
