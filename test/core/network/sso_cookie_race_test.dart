import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/core/network/school_transport.dart';
import 'package:hongik_ingan/core/network/school_transport_native.dart';
import 'package:hongik_ingan/core/network/school_transport_web.dart';
import 'package:hongik_ingan/features/attendance/data/attendance_service.dart';
import 'package:hongik_ingan/features/attendance/domain/lecture.dart';

const _host = 'https://at.hongik.ac.kr';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'logout rejects queued requests and ignores in-flight response cookies',
    () async {
      final server = _SessionServer(true, true);
      final dio = Dio()..httpClientAdapter = server;
      addTearDown(() => dio.close(force: true));
      final store = WebAuthCookieStore()
        ..saveSetCookie(Uri.parse(_host), 'JSESSIONID=old; Path=/');
      final transport = SchoolTransportWeb(dio, store);
      final first = transport.get<String>('$_host/index.jsp');
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
      await first;
      await rejected;
      expect(store.headerFor(Uri.parse(_host)), isNull);
      expect(server.posts, 0);
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
          final SchoolTransport transport;
          if (web) {
            final store = WebAuthCookieStore()
              ..saveSetCookie(Uri.parse(_host), 'JSESSIONID=old; Path=/');
            transport = SchoolTransportWeb(dio, store);
          } else {
            final jar = CookieJar();
            await jar.saveFromResponse(Uri.parse(_host), [
              Cookie('JSESSIONID', 'old')..path = '/',
            ]);
            dio.interceptors.add(CookieManager(jar));
            transport = SchoolTransportNative(dio, jar);
          }
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
          if (web && late) {
            await Future<void>.delayed(Duration.zero);
            expect(server.posts, 0);
            server.release.complete();
            await olderGet;
          }
          final result = await submission;
          expect(result.message, 'Attendance accepted');
          if (late && !web) {
            server.release.complete();
            await olderGet;
          }
          final fetched = await service.getActiveLecture();
          final corrupt = !web && late && echoOldCookie;
          expect(
            server.cookies.last,
            corrupt ? 'JSESSIONID=old' : 'JSESSIONID=new',
          );
          expect(
            fetched.status,
            corrupt ? LectureFetchStatus.failure : LectureFetchStatus.empty,
          );
          if (corrupt) expect(fetched.message, '출결 서버 SSO 연동에 실패했어요.');
          expect(server.posts, 1);
        });
      }
    }
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
      200,
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
