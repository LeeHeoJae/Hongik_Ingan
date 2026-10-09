import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/core/network/school_transport.dart';
import 'package:hongik_ingan/core/network/school_transport_native.dart';
import 'package:hongik_ingan/core/network/school_transport_web.dart';
import 'package:hongik_ingan/features/attendance/data/attendance_service.dart';
import 'package:hongik_ingan/features/attendance/domain/lecture.dart';

const _host = 'https://at.hongik.ac.kr';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final web in [true, false]) {
    for (final status in [200, 401]) {
      test(
        'logout rejects queued requests and ignores response cookies (web=$web status=$status)',
        () async {
          final server = _SessionServer(web, true)..firstStatus = status;
          final dio = Dio()..httpClientAdapter = server;
          addTearDown(() => dio.close(force: true));
          final transport = await _createTransport(web, dio);
          final first = transport.get<String>('$_host/index.jsp');
          final completed = status == 200
              ? first.then<void>((_) {})
              : expectLater(first, throwsA(isA<DioException>()));
          await server.started.future;
          final queued = transport.post<String>('$_host/stud02_proc.jsp');
          final rejected = expectLater(
            queued,
            throwsA(
              isA<DioException>().having(
                (error) => error.type,
                'type',
                DioExceptionType.cancel,
              ),
            ),
          );
          await transport.clearAuthSession();
          server.release.complete();
          await completed;
          await rejected;
          expect(await transport.hasAuthSession(), isFalse);
          expect(server.posts, 0);
        },
      );
    }
  }

  test(
    'native public requests do not wait for authentication requests',
    () async {
      final server = _SessionServer(false, false);
      final dio = Dio()..httpClientAdapter = server;
      addTearDown(() => dio.close(force: true));
      final transport = await _createTransport(false, dio);
      final first = transport.get<String>('$_host/index.jsp');
      await server.started.future;
      try {
        await transport.get<String>('https://reading.hongik.ac.kr/status');
        expect(server.gets, 2);
      } finally {
        server.release.complete();
        await first;
      }
    },
  );

  test(
    'native authentication queue continues after a failed request',
    () async {
      final server = _SessionServer(false, false)..firstStatus = 503;
      final dio = Dio()..httpClientAdapter = server;
      addTearDown(() => dio.close(force: true));
      final transport = await _createTransport(false, dio);
      final first = transport.get<String>('$_host/index.jsp');
      final failed = expectLater(first, throwsA(isA<DioException>()));
      await server.started.future;
      final next = transport.post<String>('$_host/stud02_proc.jsp');
      server.release.complete();
      await failed;
      await next;
      expect(server.posts, 1);
      expect(await transport.hasCookie(Uri.parse(_host), 'JSESSIONID'), isTrue);
    },
  );

  test('native logout waits for a cookie save already in progress', () async {
    final server = _SessionServer(false, true)..release.complete();
    final jar = _DelayedCookieJar();
    final dio = Dio()..httpClientAdapter = server;
    addTearDown(() => dio.close(force: true));
    final transport = SchoolTransportNative(dio, jar);
    final request = transport.get<String>('$_host/index.jsp');
    await jar.started.future;
    final cleared = transport.clearAuthSession();
    jar.release.complete();
    await Future.wait([request, cleared]);
    expect(await transport.hasAuthSession(), isFalse);
  });

  test(
    'native explicit cookie save cannot restore cookies after logout',
    () async {
      final jar = _DelayedCookieJar();
      final dio = Dio();
      addTearDown(() => dio.close(force: true));
      final transport = SchoolTransportNative(dio, jar);
      final saving = transport.saveAuthCookies([Cookie('SSO', 'old')]);
      await jar.started.future;
      final cleared = transport.clearAuthSession();
      jar.release.complete();
      await Future.wait([saving, cleared]);
      expect(await transport.hasAuthSession(), isFalse);
    },
  );

  test('proxy receives cookie scopes for every authentication host', () async {
    final server = _SessionServer(true, false)..release.complete();
    final dio = Dio()..httpClientAdapter = server;
    addTearDown(() => dio.close(force: true));
    final store = WebAuthCookieStore()
      ..saveSetCookie(Uri.parse(_host), 'JSESSIONID=old; Path=/; Secure')
      ..saveSetCookie(
        Uri.parse('https://ap.hongik.ac.kr/'),
        'SSO_AP=ap-only; Path=/; Secure',
      );
    await SchoolTransportWeb(dio, store).get<String>('$_host/index.jsp');
    final records =
        jsonDecode(utf8.decode(base64Url.decode(server.inventory!))) as List;
    expect(records.map((record) => record['domain']), [
      'at.hongik.ac.kr',
      'ap.hongik.ac.kr',
    ]);
    expect(records.every((record) => record['hostOnly'] == true), isTrue);
  });
  for (final web in [true, false]) {
    for (final late in [true, false]) {
      for (final echoOldCookie in [true, false]) {
        test('web=$web late=$late echoOldCookie=$echoOldCookie', () async {
          // Model contract: POST rotates and invalidates the previous session.
          // SSO failure is computed from the request cookie, not preselected.
          final server = _SessionServer(web, echoOldCookie);
          final dio = Dio()..httpClientAdapter = server;
          addTearDown(() => dio.close(force: true));
          final transport = await _createTransport(web, dio);
          final service = AttendanceService(transport);
          final olderGet = transport.get<String>('$_host/index.jsp');
          await server.started.future;
          if (!late) {
            server.release.complete();
            await olderGet;
          }
          final submission = service.submitAttendance(
            Lecture(
              name: 'Course',
              time: '10:00',
              attendanceParams: const {'lecture': '1'},
            ),
            '1234',
            '37',
            '126',
          );
          if (late) {
            await Future<void>.delayed(Duration.zero);
            expect(server.posts, 0);
            server.release.complete();
            await olderGet;
          }
          final result = await submission;
          expect(result.message, 'Attendance accepted');
          final fetched = await service.getActiveLecture();
          expect(server.cookies.last, 'JSESSIONID=new');
          expect(fetched.status, LectureFetchStatus.empty);
          expect(server.posts, 1);
        });
      }
    }
  }
}

Future<SchoolTransport> _createTransport(bool web, Dio dio) async {
  if (web) {
    final store = WebAuthCookieStore()
      ..saveSetCookie(Uri.parse(_host), 'JSESSIONID=old; Path=/');
    return SchoolTransportWeb(dio, store);
  }
  final jar = CookieJar();
  await jar.saveFromResponse(Uri.parse(_host), [
    Cookie('JSESSIONID', 'old')..path = '/',
  ]);
  return SchoolTransportNative(dio, jar);
}

class _DelayedCookieJar extends DefaultCookieJar {
  final started = Completer<void>();
  final release = Completer<void>();

  @override
  Future<void> saveFromResponse(Uri uri, List<Cookie> cookies) async {
    if (!started.isCompleted) {
      started.complete();
      await release.future;
    }
    await super.saveFromResponse(uri, cookies);
  }
}

class _SessionServer implements HttpClientAdapter {
  _SessionServer(this.web, this.echoOldCookie);
  final bool web;
  final bool echoOldCookie;
  final started = Completer<void>();
  final release = Completer<void>();
  final cookies = <String>[];
  var currentSession = 'old';
  var gets = 0;
  var posts = 0;
  String? inventory;
  int firstStatus = 200;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final cookie = (options.headers[web ? 'X-Target-Cookie' : 'cookie'] ?? '')
        .toString();
    inventory = options.headers['X-Target-Cookie-Store'] as String?;
    cookies.add(cookie);
    String? setCookie;
    String body;
    if (options.method == 'POST') {
      posts++;
      expect(cookie, 'JSESSIONID=old');
      currentSession = 'new';
      setCookie = 'JSESSIONID=new; Path=/';
      body = "<script>alert('Attendance accepted');</script>";
    } else if (++gets == 1) {
      // Response was produced for the old session but delayed in transit.
      body = '<table><tbody></tbody></table>';
      if (echoOldCookie) setCookie = 'JSESSIONID=old; Path=/';
      started.complete();
      await release.future;
    } else {
      body = cookie == 'JSESSIONID=$currentSession'
          ? '<table><tbody></tbody></table>'
          : 'SSO 시스템 연동 오류';
    }
    return ResponseBody.fromString(
      body,
      options.method == 'GET' && gets == 1 ? firstStatus : 200,
      headers: {
        'content-type': ['text/html; charset=utf-8'],
        if (setCookie != null && !web) 'set-cookie': [setCookie],
        if (setCookie != null && web)
          'x-target-set-cookies': [
            base64Url.encode(
              utf8.encode(
                jsonEncode([
                  {
                    'url': '$_host/index.jsp',
                    'cookies': [setCookie],
                  },
                ]),
              ),
            ),
          ],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
