import 'dart:convert';
import 'dart:io';

import '../logging/logger.dart';

/// 웹에서의 쿠키 저장소.
///
/// 네이티브와 달리 웹은 프록시를 사용하기에 기존의 CookieJar을 사용할 수 없다.
/// 따라서 X-Target-Cookie-Store를 사용하여 쿠키를 프록시에게 전송한다.
final class WebAuthCookieStore {
  final _authHosts = {
    'hongik.ac.kr',
    'my.hongik.ac.kr',
    'ap.hongik.ac.kr',
    'at.hongik.ac.kr',
  };

  final List<_StoredWebCookie> _cookies = [];

  bool isAuthHost(Uri target) => _authHosts.contains(target.host);

  String encodedForProxy() {
    _removeExpired();
    return base64Url.encode(
      utf8.encode(
        jsonEncode(
          _cookies
              .map(
                (cookie) => {
                  'name': cookie.name,
                  'value': cookie.value,
                  'domain': cookie.domain,
                  'path': cookie.path,
                  'hostOnly': cookie.hostOnly,
                  'secure': cookie.secure,
                  'expiresAt': cookie.expiresAt?.millisecondsSinceEpoch,
                },
              )
              .toList(),
        ),
      ),
    );
  }

  bool get isNotEmpty {
    _removeExpired();
    return _cookies.isNotEmpty;
  }

  /// origin에 cookie를 저장.
  void save(Uri origin, Cookie cookie) {
    _saveParsedCookie(origin, cookie);
  }

  /// rawCookie를 Cookie 객체로 변환하여 origin에 저장.
  void saveSetCookie(Uri origin, String rawCookie) {
    try {
      _saveParsedCookie(origin, Cookie.fromSetCookieValue(rawCookie));
    } catch (error) {
      logMsg('웹 Set-Cookie를 해석하지 못했습니다: $error', level: LogLevel.warning);
    }
  }

  bool hasCookie(Uri target, String name) {
    _removeExpired();
    return _matchingCookies(target).any((cookie) => cookie.name == name);
  }

  /// target에 대해 저장된 Cookie를 문자열로 변환
  String? headerFor(Uri target) {
    _removeExpired();
    if (!_authHosts.contains(target.host) || _cookies.isEmpty) {
      return null;
    }

    final matchingCookies = _matchingCookies(target)
      ..sort((a, b) => b.path.length.compareTo(a.path.length));
    if (matchingCookies.isEmpty) {
      return null;
    }
    return matchingCookies
        .map((cookie) => '${cookie.name}=${cookie.value}')
        .join('; ');
  }

  void clear() {
    _cookies.clear();
  }

  /// 파싱된 쿠키를 응답 URL 기준으로 검증하고 웹 쿠키 저장소에 저장.
  ///
  /// domain이 없으면 응답 호스트 전용 쿠키로 처리하고
  /// path가 없으면 응답 URL에서 기본 경로로 계산한다.
  /// domain이 일치하지 않으면 저장하지 않는다.
  void _saveParsedCookie(Uri origin, Cookie cookie) {
    if (cookie.name.isEmpty || !_authHosts.contains(origin.host)) {
      return;
    }

    final rawDomain = cookie.domain?.trim().toLowerCase();
    final hostOnly = rawDomain == null || rawDomain.isEmpty;
    final domain = hostOnly
        ? origin.host.toLowerCase()
        : rawDomain.replaceFirst(RegExp(r'^\.'), '');
    if (!hostOnly && !_isAllowedCookieDomain(domain)) {
      logMsg(
        '웹 쿠키의 도메인이 허용 범위를 벗어났습니다: '
        '${cookie.name} ($domain)',
        level: LogLevel.warning,
      );
      return;
    }
    if (!_domainMatches(origin.host.toLowerCase(), domain)) {
      logMsg(
        '웹 쿠키의 도메인이 응답 호스트와 일치하지 않습니다: '
        '${cookie.name} ($domain)',
        level: LogLevel.warning,
      );
      return;
    }

    final path = cookie.path == null || !cookie.path!.startsWith('/')
        ? _defaultPath(origin.path)
        : cookie.path!;
    // 만료시간
    final expiresAt = cookie.maxAge != null
        ? DateTime.now().toUtc().add(Duration(seconds: cookie.maxAge!))
        : cookie.expires?.toUtc();
    final shouldDelete =
        cookie.value.isEmpty ||
        (cookie.maxAge != null && cookie.maxAge! <= 0) ||
        (expiresAt != null && !expiresAt.isAfter(DateTime.now().toUtc()));

    // 기존 쿠키 제거
    _cookies.removeWhere(
      (stored) =>
          stored.name == cookie.name &&
          stored.domain == domain &&
          stored.path == path,
    );
    if (shouldDelete) {
      return;
    }
    // 새 쿠키 저장
    _cookies.add(
      _StoredWebCookie(
        name: cookie.name,
        value: cookie.value,
        domain: domain,
        path: path,
        hostOnly: hostOnly,
        secure: cookie.secure,
        expiresAt: expiresAt,
      ),
    );
  }

  List<_StoredWebCookie> _matchingCookies(Uri target) {
    if (!_authHosts.contains(target.host)) {
      return [];
    }
    final host = target.host.toLowerCase();
    final path = target.path.isEmpty ? '/' : target.path;
    return _cookies.where((cookie) {
      final domainMatches = cookie.hostOnly
          ? host == cookie.domain
          : _domainMatches(host, cookie.domain);
      return domainMatches &&
          _pathMatches(path, cookie.path) &&
          (!cookie.secure || target.scheme == 'https');
    }).toList();
  }

  void _removeExpired() {
    final now = DateTime.now().toUtc();
    _cookies.removeWhere(
      (cookie) => cookie.expiresAt != null && !cookie.expiresAt!.isAfter(now),
    );
  }

  /// domain과 host가 같은 도메인인지 체크.
  bool _domainMatches(String host, String domain) {
    return host == domain || host.endsWith('.$domain');
  }

  bool _isAllowedCookieDomain(String domain) {
    return _authHosts.contains(domain);
  }

  bool _pathMatches(String requestPath, String cookiePath) {
    if (requestPath == cookiePath) {
      return true;
    }
    if (!requestPath.startsWith(cookiePath)) {
      return false;
    }
    return cookiePath.endsWith('/') ||
        (requestPath.length > cookiePath.length &&
            requestPath[cookiePath.length] == '/');
  }

  String _defaultPath(String requestPath) {
    if (!requestPath.startsWith('/') || requestPath == '/') {
      return '/';
    }
    final lastSlash = requestPath.lastIndexOf('/');
    return lastSlash <= 0 ? '/' : requestPath.substring(0, lastSlash);
  }
}

final class _StoredWebCookie {
  const _StoredWebCookie({
    required this.name,
    required this.value,
    required this.domain,
    required this.path,
    required this.hostOnly,
    required this.secure,
    required this.expiresAt,
  });

  final String name;
  final String value;
  final String domain;
  final String path;
  final bool hostOnly;
  final bool secure;
  final DateTime? expiresAt;
}
