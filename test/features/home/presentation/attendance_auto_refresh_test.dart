import 'dart:async';
import 'package:hongik_ingan/features/home/domain/session_recovery_result.dart';
import 'dart:io' show HttpDate;

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hongik_ingan/core/network/school_request_options.dart';
import 'package:hongik_ingan/core/network/school_transport.dart';
import 'package:hongik_ingan/core/network/school_transport_provider.dart';
import 'package:hongik_ingan/features/attendance/application/attendance_controller.dart';
import 'package:hongik_ingan/features/attendance/presentation/attendance_auto_refresh.dart';
import 'package:hongik_ingan/features/home/application/home_controller.dart';

void main() {
  testWidgets('waits five seconds after an eight-second response', (
    tester,
  ) async {
    final h = await _mount(tester);
    await tester.pump(const Duration(seconds: 8));
    expect(h.transport.requests, hasLength(1));
    h.transport.complete(_empty);
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    expect(h.transport.requests, hasLength(1));
    await tester.pump(const Duration(seconds: 1));
    expect(h.transport.requests, hasLength(2));
    expect(h.transport.requests.last.allowProxyRetry, isFalse);
    final shared = h.controller.fetchLecture(forceRefresh: true);
    await tester.pump(const Duration(seconds: 12));
    expect(h.transport.requests, hasLength(2));
    h.transport.complete(_empty);
    await shared;
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    expect(h.transport.requests, hasLength(3));
  });

  testWidgets('manual refresh restarts the five-second wait', (tester) async {
    final h = await _mount(tester);
    h.transport.complete(_empty);
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    final manual = h.controller.fetchLecture(forceRefresh: true);
    expect(h.transport.requests.last.allowProxyRetry, isTrue);
    await tester.pump(const Duration(seconds: 8));
    expect(h.transport.requests, hasLength(2));
    h.transport.complete(_empty);
    await manual;
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    expect(h.transport.requests, hasLength(2));
    await tester.pump(const Duration(seconds: 1));
    expect(h.transport.requests, hasLength(3));
  });

  testWidgets('unrelated home updates do not postpone the next request', (
    tester,
  ) async {
    final h = await _mount(tester);
    h.transport.complete(_empty);
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    h.home.setStatus('session checked');
    await tester.pump(const Duration(seconds: 2));
    expect(h.transport.requests, hasLength(2));
  });

  testWidgets(
    'pauses polling while the submission result is open and resumes when its flow ends',
    (tester) async {
      final h = await _mount(tester);
      h.transport.complete(_lecture);
      await tester.pump();
      await tester.pump(const Duration(seconds: 30));
      expect(h.transport.requests, hasLength(1));
      final code = Completer<String?>();
      final attendance = h.controller.performAttendance(
        requestAuthCode: () => code.future,
        canContinue: () => true,
      );
      await tester.pump(const Duration(seconds: 10));
      expect(
        h.container.read(attendanceProvider).phase,
        AttendancePhase.enteringCode,
      );
      expect(h.transport.requests, hasLength(1));
      code.complete('1234');
      await attendance;
      await tester.pump();
      expect(h.transport.submissions, 1);
      expect(h.transport.requests, hasLength(2));
      h.transport.complete(_empty);
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));
      expect(h.transport.requests, hasLength(2));
      await tester.pump(const Duration(seconds: 1));
      expect(h.transport.requests, hasLength(2));
      expect(
        h.container.read(attendanceProvider).submissionResult?.message,
        'done',
      );
      h.controller.finishAttendanceFlow(h.controller.submissionRevision);
      await tester.pump();
      expect(h.container.read(attendanceProvider).submissionResult, isNull);
      await tester.pump(const Duration(seconds: 5));
      expect(h.transport.requests, hasLength(3));
      expect(h.transport.submissions, 1);
    },
  );

  testWidgets(
    'failed post-submit query retries without restoring the old lecture card',
    (tester) async {
      final h = await _mount(tester);
      h.transport.complete(_lecture);
      await tester.pump();
      await h.controller.performAttendance(
        requestAuthCode: () async => '1234',
        canContinue: () => true,
      );
      h.transport.complete('SSO 시스템 연동 오류');
      await tester.pump();
      expect(h.container.read(attendanceProvider).currentLecture, isNull);
      expect(
        h.container.read(attendanceProvider).submissionResult?.message,
        'done',
      );
      await tester.pump(const Duration(seconds: 29));
      expect(h.transport.requests, hasLength(2));
      await tester.pump(const Duration(seconds: 1));
      expect(h.transport.requests, hasLength(3));
      h.transport.complete(_lecture);
      await tester.pump();
      expect(h.container.read(attendanceProvider).hasDisplayLecture, isFalse);
      expect(
        h.container.read(attendanceProvider).submissionResult?.message,
        'done',
      );
      await tester.pump(const Duration(seconds: 60));
      expect(h.transport.requests, hasLength(3));
      expect(h.transport.submissions, 1);
    },
  );

  testWidgets('cancelling code entry keeps the lecture and polling stopped', (
    tester,
  ) async {
    final h = await _mount(tester);
    h.transport.complete(_lecture);
    await tester.pump();
    await h.controller.performAttendance(
      requestAuthCode: () async => null,
      canContinue: () => true,
    );
    await tester.pump(const Duration(seconds: 30));
    expect(h.transport.requests, hasLength(1));
    expect(h.transport.submissions, 0);
    expect(h.container.read(attendanceProvider).currentLecture, isNotNull);
  });

  testWidgets('pauses on hidden tabs, inactive screens, and logout', (
    tester,
  ) async {
    final h = await _mount(tester);
    h.transport.complete(_empty);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump(const Duration(seconds: 30));
    expect(h.transport.requests, hasLength(1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 4));
    expect(h.transport.requests, hasLength(1));
    await tester.pump(const Duration(seconds: 1));
    expect(h.transport.requests, hasLength(2));
    h.transport.complete(_empty);
    await tester.pump();
    await h.render(tester, visible: false);
    await tester.pump(const Duration(seconds: 30));
    expect(h.transport.requests, hasLength(2));
    await h.render(tester, visible: true);
    await tester.pump(const Duration(seconds: 5));
    expect(h.transport.requests, hasLength(3));
    h.home.setLoggedIn(false);
    h.controller.resetSession();
    h.transport.complete(_lecture);
    await tester.pump(const Duration(seconds: 30));
    expect(h.transport.requests, hasLength(3));
    expect(h.container.read(attendanceProvider).currentLecture, isNull);
    h.home.setLoggedIn(true);
    final fresh = h.controller.fetchLecture(forceRefresh: true);
    h.transport.complete(_empty);
    await fresh;
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    expect(h.transport.requests, hasLength(5));
  });

  testWidgets(
    'unverified expiry retains the screen and retries after cooldown',
    (tester) async {
      final h = await _mount(tester);
      h.home.recoveryResult = SessionRecoveryResult.loginRequired;
      h.transport.complete('<form><input name="USER_ID"></form>');
      await tester.pump();
      expect(h.container.read(attendanceProvider).sessionExpired, isFalse);
      expect(h.container.read(attendanceProvider).isLectureStale, isTrue);
      expect(h.container.read(homeControllerProvider).isLoggedIn, isTrue);
      await tester.pump(const Duration(seconds: 29));
      expect(h.transport.requests, hasLength(1));
      await tester.pump(const Duration(seconds: 1));
      expect(h.transport.requests, hasLength(2));
      h.transport.complete(_empty);
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));
      expect(h.transport.requests, hasLength(3));
    },
  );

  for (final asDate in [false, true]) {
    testWidgets('honors Retry-After (${asDate ? 'HTTP date' : 'seconds'})', (
      tester,
    ) async {
      final h = await _mount(tester);
      final retryAfter = asDate
          ? HttpDate.format(
              tester.binding.clock.now().add(const Duration(seconds: 20)),
            )
          : '20';
      h.transport.complete('unavailable', status: 503, retryAfter: retryAfter);
      await tester.pump();
      await tester.pump(const Duration(seconds: 29));
      expect(h.transport.requests, hasLength(1));
      await tester.pump(const Duration(seconds: 1));
      expect(h.transport.requests, hasLength(2));
      h.controller.resetSession();
    });
  }

  testWidgets('initial network errors recover silently with a cooldown', (
    tester,
  ) async {
    final h = await _mount(tester);
    h.transport.fail();
    await tester.pump();
    expect(h.container.read(attendanceProvider).error, isNull);
    expect(h.container.read(attendanceProvider).isLectureStale, isTrue);
    await tester.pump(const Duration(seconds: 29));
    expect(h.transport.requests, hasLength(1));
    await tester.pump(const Duration(seconds: 1));
    expect(h.transport.requests, hasLength(2));
    h.controller.resetSession();
  });

  testWidgets(
    'stale lecture retries after cooldown and stops again on success',
    (tester) async {
      final h = await _mount(tester);
      h.transport.complete(_lecture);
      await tester.pump();
      final refresh = h.controller.fetchLecture(forceRefresh: true);
      h.transport.complete('SSO 시스템 연동 오류');
      await refresh;
      await tester.pump();
      expect(h.container.read(attendanceProvider).currentLecture, isNotNull);
      expect(h.container.read(attendanceProvider).isLectureStale, isTrue);
      expect(h.container.read(attendanceProvider).error, isNull);
      await tester.pump(const Duration(seconds: 29));
      expect(h.transport.requests, hasLength(2));
      await tester.pump(const Duration(seconds: 1));
      expect(h.transport.requests, hasLength(3));
      h.transport.complete(_lecture);
      await tester.pump();
      expect(h.container.read(attendanceProvider).isLectureStale, isFalse);
      await tester.pump(const Duration(seconds: 60));
      expect(h.transport.requests, hasLength(3));
    },
  );

  testWidgets('a response arriving while hidden does not restart polling', (
    tester,
  ) async {
    final h = await _mount(tester);
    h.transport.complete(_empty);
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    expect(h.transport.requests, hasLength(2));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    h.transport.complete(_empty);
    await tester.pump();
    await tester.pump(const Duration(seconds: 30));
    expect(h.transport.requests, hasLength(2));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 4));
    expect(h.transport.requests, hasLength(2));
    await tester.pump(const Duration(seconds: 1));
    expect(h.transport.requests, hasLength(3));
  });

  testWidgets('disposing the screen during a request leaves no refresh timer', (
    tester,
  ) async {
    final h = await _mount(tester);
    h.transport.complete(_empty);
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    expect(h.transport.requests, hasLength(2));
    await tester.pumpWidget(const SizedBox());
    h.transport.complete(_empty);
    await tester.pump();
    await tester.pump(const Duration(seconds: 30));
    expect(h.transport.requests, hasLength(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('delay notice appears without waiting for Retry-After', (
    tester,
  ) async {
    final h = await _mount(tester);
    h.transport.complete('unavailable', status: 503, retryAfter: '120');
    await tester.pump();
    expect(h.container.read(attendanceProvider).error, isNull);
    await tester.pump(const Duration(seconds: 59));
    expect(h.container.read(attendanceProvider).error, isNull);
    await tester.pump(const Duration(seconds: 1));
    expect(
      h.container.read(attendanceProvider).error,
      AttendanceController.connectionDelayMessage,
    );
    expect(h.transport.requests, hasLength(1));
    expect(h.container.read(attendanceProvider).isLectureStale, isTrue);
    expect(h.transport.submissions, 0);
  });

  testWidgets('closing a result keeps follow-up recovery silent', (
    tester,
  ) async {
    final h = await _mount(tester);
    h.transport.complete(_lecture);
    await tester.pump();
    await h.controller.performAttendance(
      requestAuthCode: () async => '1234',
      canContinue: () => true,
    );
    h.transport.complete('unavailable', status: 503, retryAfter: '120');
    await tester.pump();
    expect(
      h.container.read(attendanceProvider).submissionResult?.message,
      'done',
    );
    h.controller.finishAttendanceFlow(h.controller.submissionRevision);
    await tester.pump();
    expect(h.container.read(attendanceProvider).submissionResult, isNull);
    expect(h.container.read(attendanceProvider).error, isNull);
    expect(h.container.read(attendanceProvider).isLectureStale, isTrue);
    expect(
      await h.controller.performAttendance(
        requestAuthCode: () async => '1234',
        canContinue: () => true,
      ),
      isNull,
    );
    await tester.pump(const Duration(seconds: 60));
    expect(
      h.container.read(attendanceProvider).error,
      AttendanceController.connectionDelayMessage,
    );
    expect(h.transport.requests, hasLength(2));
    expect(h.transport.submissions, 1);
  });

  testWidgets('successful manual refresh cancels the delay notice', (
    tester,
  ) async {
    final h = await _mount(tester);
    h.transport.complete('unavailable', status: 503, retryAfter: '120');
    await tester.pump();
    await tester.pump(const Duration(seconds: 20));
    final refresh = h.controller.fetchLecture(forceRefresh: true);
    h.transport.complete(_lecture);
    await refresh;
    await tester.pump(const Duration(seconds: 60));
    expect(h.container.read(attendanceProvider).error, isNull);
    expect(h.container.read(attendanceProvider).isLectureStale, isFalse);
    expect(h.transport.requests, hasLength(2));
  });

  testWidgets('a slow session recovery shows delay while still waiting', (
    tester,
  ) async {
    final h = await _mount(tester);
    h.home.recoveryGate = Completer<SessionRecoveryResult>();
    h.transport.complete('SSO 시스템 연동 오류');
    await tester.pump();
    expect(
      h.container.read(attendanceProvider).phase,
      AttendancePhase.fetchingLecture,
    );
    expect(h.container.read(attendanceProvider).isLectureStale, isTrue);
    await tester.pump(const Duration(seconds: 60));
    expect(
      h.container.read(attendanceProvider).error,
      AttendanceController.connectionDelayMessage,
    );
    expect(h.transport.requests, hasLength(1));
    h.home.recoveryGate!.complete(SessionRecoveryResult.temporarilyUnavailable);
    await tester.pump();
    expect(
      h.container.read(attendanceProvider).error,
      AttendanceController.connectionDelayMessage,
    );
    h.controller.resetSession();
  });

  testWidgets('session reset cancels a pending recovery notice', (
    tester,
  ) async {
    final h = await _mount(tester);
    h.transport.complete('unavailable', status: 503, retryAfter: '120');
    await tester.pump();
    await tester.pump(const Duration(seconds: 10));
    h.controller.resetSession();
    await tester.pump(const Duration(seconds: 60));
    expect(h.container.read(attendanceProvider).error, isNull);
    expect(h.container.read(attendanceProvider).hasCheckedLecture, isFalse);
    expect(h.transport.requests, hasLength(1));
  });

  for (final retryAfter in ['2', 'invalid-date', '-1']) {
    testWidgets(
      'Retry-After "$retryAfter" never shortens the recovery cooldown',
      (tester) async {
        final h = await _mount(tester);
        h.transport.complete(
          'unavailable',
          status: 429,
          retryAfter: retryAfter,
        );
        await tester.pump();
        expect(h.container.read(attendanceProvider).error, isNull);
        await tester.pump(const Duration(seconds: 29));
        expect(h.transport.requests, hasLength(1));
        await tester.pump(const Duration(seconds: 1));
        expect(h.transport.requests, hasLength(2));
        h.controller.resetSession();
      },
    );
  }
}

Future<_Harness> _mount(WidgetTester tester) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  final transport = _Transport();
  final home = _Home();
  final container = ProviderContainer.test(
    overrides: [
      schoolTransportProvider.overrideWithValue(transport),
      homeControllerProvider.overrideWith(() => home),
      attendanceProvider.overrideWith(
        () => AttendanceController(
          now: () => tester.binding.clock.now(),
          locationProvider: () async => Position(
            latitude: 0,
            longitude: 0,
            timestamp: tester.binding.clock.now(),
            accuracy: 0,
            altitude: 0,
            altitudeAccuracy: 0,
            heading: 0,
            headingAccuracy: 0,
            speed: 0,
            speedAccuracy: 0,
          ),
        ),
      ),
    ],
  );
  final harness = _Harness(container, transport, home);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });
  unawaited(harness.controller.fetchLecture(forceRefresh: true));
  await harness.render(tester);
  return harness;
}

class _Harness {
  _Harness(this.container, this.transport, this.home);
  final ProviderContainer container;
  final _Transport transport;
  final _Home home;
  AttendanceController get controller =>
      container.read(attendanceProvider.notifier);
  Future<void> render(WidgetTester tester, {bool visible = true}) =>
      tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: TickerMode(
              enabled: visible,
              child: const AttendanceAutoRefresh(child: SizedBox()),
            ),
          ),
        ),
      );
}

class _Home extends HomeController {
  Completer<SessionRecoveryResult>? recoveryGate;
  SessionRecoveryResult recoveryResult =
      SessionRecoveryResult.temporarilyUnavailable;
  @override
  HomeState build() => const HomeState(isLoggedIn: true, userId: 'student');
  @override
  Future<SessionRecoveryResult> recoverAttendanceSession() =>
      recoveryGate?.future ?? Future.value(recoveryResult);
  void setLoggedIn(bool value) => state = state.copyWith(isLoggedIn: value);
  void setStatus(String value) => state = state.copyWith(statusMessage: value);
}

class _Transport implements SchoolTransport {
  final requests = <SchoolRequestOptions>[];
  final pending = <Completer<Response<String>>>[];
  int submissions = 0;
  @override
  Future<Response<T>> get<T>(
    String target, {
    Map<String, dynamic>? queryParameters,
    SchoolRequestOptions options = const SchoolRequestOptions(),
  }) {
    requests.add(options);
    final request = Completer<Response<String>>();
    pending.add(request);
    return request.future.then((response) => response as Response<T>);
  }

  void complete(String body, {int status = 200, String? retryAfter}) {
    pending
        .removeAt(0)
        .complete(
          Response<String>(
            data: body,
            statusCode: status,
            requestOptions: RequestOptions(
              path: 'https://at.hongik.ac.kr/index.jsp',
            ),
            headers: Headers.fromMap({
              if (retryAfter != null) 'retry-after': [retryAfter],
            }),
          ),
        );
  }

  void fail() => pending
      .removeAt(0)
      .completeError(
        DioException(
          requestOptions: RequestOptions(
            path: 'https://at.hongik.ac.kr/index.jsp',
          ),
          type: DioExceptionType.connectionError,
        ),
      );
  @override
  Future<Response<T>> post<T>(
    String target, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    SchoolRequestOptions options = const SchoolRequestOptions(),
  }) async {
    submissions++;
    return Response<String>(
          data: "<script>alert('done')</script>",
          statusCode: 200,
          requestOptions: RequestOptions(path: target),
        )
        as Response<T>;
  }

  @override
  Future<void> clearAuthSession() async {}
  @override
  Future<bool> hasAuthSession() async => true;
  @override
  Future<bool> hasCookie(Uri target, String name) async => true;
  @override
  Future<void> saveAuthCookies(List<Cookie> cookies) async {}
}

const _empty = '<table><tbody></tbody></table>';
const _lecture = '''<table><tbody><tr>
<td>1</td><td>2</td><td>Course</td><td>Room</td><td>10:00</td>
<td><form action="stud02.jsp"><input name="lecture" value="1"></form></td>
</tr></tbody></table>''';
