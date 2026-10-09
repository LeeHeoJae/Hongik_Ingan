import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hongik_ingan/core/network/school_request_options.dart';
import 'package:hongik_ingan/core/network/school_transport.dart';
import 'package:hongik_ingan/core/network/school_transport_provider.dart';
import 'package:hongik_ingan/core/network/school_transport_web.dart';
import 'package:hongik_ingan/features/attendance/application/attendance_controller.dart';
import 'package:hongik_ingan/features/attendance/domain/attendance_submission_result.dart';
import 'package:hongik_ingan/features/home/application/home_controller.dart';
import 'package:hongik_ingan/features/home/data/auth_service.dart';
import 'package:hongik_ingan/features/home/domain/session_status.dart';
import 'package:hongik_ingan/features/home/domain/login_result.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _table = '<table><tbody></tbody></table>';
const _ssoError = 'SSO 시스템 연동 오류';
const _lecture =
    '<table><tbody><tr><td>1</td><td>2</td><td>Course</td><td>Room</td><td>10:00</td><td><form action="stud02.jsp"><input name="lecture" value="1"></form></td></tr></tbody></table>';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => null);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'fresh login: credential check → shared SSO cookie → attendance session',
    () async {
      final h = _Harness();
      expect(
        (await h.auth.login('student', 'test-password')).isSuccess,
        isTrue,
      );
      expect(h.server.paths, [
        '/my/login.do',
        '/login/LoginCheck_SSO.php',
        '/login/LoginExec3.php',
        '/login.jsp',
        '/index.jsp',
      ]);
      expect(h.server.cookies[3], 'SSO=test-sso');
      expect(h.server.cookies[4], 'SSO=test-sso; JSESSIONID=at-session');
      expect(
        h.store.headerFor(Uri.parse('https://ap.hongik.ac.kr/')),
        'SSO=test-sso',
      );
    },
  );

  test(
    'web reload creates an empty cookie store even if server session survives',
    () async {
      final h = _Harness();
      expect(
        (await h.auth.login('student', 'test-password')).isSuccess,
        isTrue,
      );
      expect(h.store.isNotEmpty, isTrue);
      final reloadedDio = Dio()..httpClientAdapter = h.server;
      addTearDown(() => reloadedDio.close(force: true));
      final reloaded = SchoolTransportWeb(reloadedDio, WebAuthCookieStore());
      expect(await reloaded.hasAuthSession(), isFalse);
      expect(
        await AuthService(
          reloaded,
        ).recoverAttendanceSession(canContinue: () => true),
        isFalse,
      );
      expect(h.server.cookies.last, isEmpty);
    },
  );

  for (final failure in [
    'credentials',
    'missing-sso',
    'missing-attendance-cookie',
    'sso-activation',
    'empty-activation',
    'empty-index',
    'network',
  ]) {
    test('fresh login rejects $failure', () async {
      final h = _Harness();
      switch (failure) {
        case 'credentials':
          h.server.credentialsAccepted = false;
        case 'missing-sso':
          h.server.issueSso = false;
        case 'missing-attendance-cookie':
          h.server.issueAttendance = false;
        case 'sso-activation':
          h.server.activationBody = _ssoError;
        case 'empty-activation':
          h.server.activationBody = '';
        case 'empty-index':
          h.server.indexFixtures.add((200, ''));
        case 'network':
          h.server.activationNetworkFailure = true;
      }
      final result = await h.auth.login('student', 'test-password');
      expect(result.isFailure, isTrue);
      expect(result.failureKind, switch (failure) {
        'credentials' => LoginFailureKind.credentials,
        'network' => LoginFailureKind.connection,
        _ => LoginFailureKind.attendanceSession,
      });
      if (failure == 'credentials') {
        expect(h.server.paths, ['/my/login.do', '/login/LoginCheck_SSO.php']);
      }
      if (failure == 'missing-sso') {
        expect(
          h.store.hasCookie(
            Uri.parse('https://at.hongik.ac.kr/'),
            'JSESSIONID',
          ),
          isFalse,
        );
      }
    });
  }

  final checks = [
    (
      name: 'normal',
      status: 200,
      body: _table,
      expected: SessionStatus.valid,
      calls: 1,
    ),
    (
      name: 'login page',
      status: 200,
      body: '통합 로그인',
      expected: SessionStatus.expired,
      calls: 1,
    ),
    (
      name: 'logout page',
      status: 200,
      body: '장시간 사용이 없어 로그아웃 되었습니다.',
      expected: SessionStatus.expired,
      calls: 1,
    ),
    (
      name: 'SSO error',
      status: 200,
      body: _ssoError,
      expected: SessionStatus.integrationError,
      calls: 1,
    ),
    (
      name: '401 SSO body',
      status: 401,
      body: _ssoError,
      expected: SessionStatus.integrationError,
      calls: 1,
    ),
    (
      name: '401 ordinary body',
      status: 401,
      body: 'Unauthorized',
      expected: SessionStatus.unknown,
      calls: 2,
    ),
    (
      name: '429',
      status: 429,
      body: 'Busy',
      expected: SessionStatus.unknown,
      calls: 2,
    ),
    (
      name: '503',
      status: 503,
      body: _ssoError,
      expected: SessionStatus.unknown,
      calls: 2,
    ),
    (
      name: 'empty 200',
      status: 200,
      body: '',
      expected: SessionStatus.unknown,
      calls: 2,
    ),
    (
      name: 'connection failure',
      status: -1,
      body: '',
      expected: SessionStatus.unknown,
      calls: 2,
    ),
    (
      name: 'unrecognized 200',
      status: 200,
      body: '<p>Maintenance</p>',
      expected: SessionStatus.valid,
      calls: 1,
    ),
  ];
  for (final check in checks) {
    test('session check: ${check.name}', () async {
      final h = _Harness(sso: true, attendance: true);
      h.server.indexFixtures.addAll(
        List.filled(check.calls, (check.status, check.body)),
      );
      expect(await h.auth.checkSessionStatus(), check.expected);
      expect(h.server.paths.length, check.calls);
      expect(h.server.paths.every((path) => path == '/index.jsp'), isTrue);
      expect(h.transport.clears, 0); // Classifier itself never logs out.
    });
  }

  test('unknown session retries once then accepts a normal response', () async {
    final h = _Harness(sso: true, attendance: true);
    h.server.indexFixtures.addAll([(503, 'Busy'), (200, _table)]);
    expect(await h.auth.checkSessionStatus(), SessionStatus.valid);
    expect(h.server.paths, ['/index.jsp', '/index.jsp']);
  });

  test(
    'attendance session can work without a reusable shared SSO cookie',
    () async {
      final h = _Harness(attendance: true);
      expect(await h.auth.checkSessionStatus(), SessionStatus.valid);
      expect(
        await h.auth.recoverAttendanceSession(canContinue: () => true),
        isFalse,
      );
      expect(h.server.paths, ['/index.jsp', '/login.jsp']);
    },
  );

  test('cancelled recovery sends no authentication request', () async {
    final h = _Harness(sso: true);
    expect(
      await h.auth.recoverAttendanceSession(canContinue: () => false),
      isFalse,
    );
    expect(h.server.paths, isEmpty);
  });

  test('shared SSO survives while attendance session is absent', () async {
    final h = _Harness(sso: true);
    var passwordReads = 0;
    expect(
      await h.auth.recoverAttendanceSession(
        canContinue: () => true,
        readPassword: () async {
          passwordReads++;
          return null;
        },
      ),
      isTrue,
    );
    expect(h.server.paths, ['/login.jsp', '/index.jsp']);
    expect(passwordReads, 0);
    expect(h.transport.clears, 0);
  });

  test('expired shared SSO recovers through credential login', () async {
    final h = _Harness();
    expect(
      await h.auth.recoverAttendanceSession(
        studentId: 'student',
        password: 'test-password',
        canContinue: () => true,
      ),
      isTrue,
    );
    expect(h.server.paths, [
      '/login.jsp',
      '/my/login.do',
      '/login/LoginCheck_SSO.php',
      '/login/LoginExec3.php',
      '/login.jsp',
      '/index.jsp',
    ]);
  });

  test('expired SSO without credentials cannot recover', () async {
    final h = _Harness();
    expect(
      await h.auth.recoverAttendanceSession(canContinue: () => true),
      isFalse,
    );
    expect(h.server.paths, ['/login.jsp']);
  });

  test(
    'network failure during activation does not retry password login',
    () async {
      final h = _Harness(sso: true)..server.activationNetworkFailure = true;
      expect(
        await h.auth.recoverAttendanceSession(
          studentId: 'student',
          password: 'test-password',
          canContinue: () => true,
        ),
        isFalse,
      );
      expect(h.server.paths, ['/login.jsp']);
    },
  );

  for (final trigger in ['startup', 'resume', 'lecture']) {
    for (final ssoWorks in [true, false]) {
      test(
        '$trigger SSO error, reusable shared SSO=$ssoWorks, no automatic credentials',
        () async {
          final h = _Harness(sso: ssoWorks, attendance: true);
          h.server.indexFixtures.add((200, _ssoError));
          final container = ProviderContainer.test(
            overrides: [
              schoolTransportProvider.overrideWithValue(h.transport),
              homeControllerProvider.overrideWith(_Home.new),
            ],
          );
          final home = container.read(homeControllerProvider.notifier);
          switch (trigger) {
            case 'startup':
              await home.restoreSessionOrLogin('', '');
            case 'resume':
              await home.revalidateSessionOnResume('', '');
            case 'lecture':
              await container.read(attendanceProvider.notifier).fetchLecture();
          }
          final failedResume = trigger == 'resume' && !ssoWorks;
          final remainsLoggedIn = trigger != 'startup' && !failedResume;
          expect(
            container.read(homeControllerProvider).isLoggedIn,
            remainsLoggedIn,
          );
          expect(h.transport.clears, failedResume ? 1 : 0);
          expect(
            h.server.paths.any((path) => path.endsWith('LoginCheck_SSO.php')),
            isFalse,
          );
          if (trigger == 'lecture') {
            expect(
              container.read(attendanceProvider).error,
              ssoWorks ? isNull : _ssoErrorMessage,
            );
          }
        },
      );
    }
  }

  for (final trigger in ['startup', 'resume']) {
    test(
      '$trigger unverified session retains cookies and preserves an existing resume login',
      () async {
        final h = _Harness(sso: true, attendance: true);
        h.server.indexFixtures.addAll([(503, 'Busy'), (503, 'Busy')]);
        final container = ProviderContainer.test(
          overrides: [
            schoolTransportProvider.overrideWithValue(h.transport),
            homeControllerProvider.overrideWith(_Home.new),
          ],
        );
        final home = container.read(homeControllerProvider.notifier);
        if (trigger == 'startup') {
          await home.restoreSessionOrLogin('', '');
        } else {
          await home.revalidateSessionOnResume('', '');
        }
        expect(
          container.read(homeControllerProvider).isLoggedIn,
          trigger == 'resume',
        );
        expect(
          container.read(homeControllerProvider).loginStatus,
          LoginStatus.verificationFailed,
        );
        expect(h.transport.clears, 0);
        expect(await h.transport.hasAuthSession(), isTrue);
        expect(h.server.paths, ['/index.jsp', '/index.jsp']);
      },
    );
  }

  test(
    'resume verification failure preserves an accepted POST result',
    () async {
      final h = _Harness(sso: true, attendance: true);
      final container = _attendanceContainer(h);
      final controller = container.read(attendanceProvider.notifier);
      h.server.indexFixtures.add((200, _lecture));
      await controller.fetchLecture();
      h.server.indexFixtures.addAll([(503, 'Busy'), (503, 'Busy')]);
      h.server.gateIndexCall = 3;
      h.server.postGate = Completer<void>();
      final resume = container
          .read(homeControllerProvider.notifier)
          .revalidateSessionOnResume('', '');
      await h.server.indexGateStarted.future;
      final submission = controller.performAttendance(
        requestAuthCode: () async => '1234',
        canContinue: () => container.read(homeControllerProvider).isLoggedIn,
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(attendanceProvider).phase,
        AttendancePhase.submitting,
      );
      expect(h.server.posts, 0); // POST is queued behind the foreground check.
      h.server.indexGate.complete();
      await h.server.postStarted.future;
      await resume;
      expect(container.read(homeControllerProvider).isLoggedIn, isTrue);
      expect(h.transport.clears, 0);
      h.server.postGate!.complete();
      expect((await submission)?.message, 'Attendance accepted');
      await controller.fetchLecture();
      expect(h.server.posts, 1);
      expect(h.server.acceptedPosts, 1);
    },
  );

  for (final recover in [false, true]) {
    test(
      recover
          ? 'SSO foreground check does not cancel an open code entry'
          : 'attendance control: valid resume check preserves an open code entry',
      () async {
        final h = _Harness(sso: true, attendance: true);
        final container = _attendanceContainer(h);
        final controller = container.read(attendanceProvider.notifier);
        h.server.indexFixtures.addAll([
          (200, _lecture),
          (200, recover ? _ssoError : _table),
        ]);
        await controller.fetchLecture();
        h.server.gateIndexCall = 2;
        final resume = container
            .read(homeControllerProvider.notifier)
            .revalidateSessionOnResume('', '');
        await h.server.indexGateStarted.future;
        final code = Completer<String?>();
        final submission = controller.performAttendance(
          requestAuthCode: () => code.future,
          canContinue: () => container.read(homeControllerProvider).isLoggedIn,
        );
        expect(
          container.read(attendanceProvider).phase,
          AttendancePhase.enteringCode,
        );
        h.server.indexGate.complete();
        await resume;
        expect(container.read(homeControllerProvider).isLoggedIn, isTrue);
        code.complete('1234');
        final result = await submission;
        await controller.fetchLecture();
        expect(result?.message, 'Attendance accepted');
        expect(h.server.posts, 1);
        expect(h.server.paths, isNot(contains('/login.jsp')));
      },
    );
  }

  test(
    'accepted POST timeout requires confirmation before another manual submission',
    () async {
      final h = _Harness(sso: true, attendance: true);
      final container = _attendanceContainer(h);
      final controller = container.read(attendanceProvider.notifier);
      h.server.indexFixtures.addAll(List.filled(3, (200, _lecture)));
      h.server.postTimeout = true;
      await controller.fetchLecture();
      final first = await controller.performAttendance(
        requestAuthCode: () async => '1234',
        canContinue: () => true,
      );
      await controller.fetchLecture();
      expect(first?.isError, isTrue);
      expect(first?.isUnconfirmed, isTrue);
      expect(first?.hasServerResponse, isFalse);
      expect(h.server.acceptedPosts, 1);
      h.server.postTimeout = false;
      final second = await controller.performAttendance(
        requestAuthCode: () async => '1234',
        canContinue: () => true,
      );
      await controller.fetchLecture();
      expect(second, isNull);
      expect(h.server.posts, 1);
      final third = await controller.performAttendance(
        requestAuthCode: () async => '1234',
        canContinue: () => true,
        confirmUnconfirmedRetry: (previous) async {
          expect(previous.isUnconfirmed, isTrue);
          return true;
        },
      );
      await controller.fetchLecture();
      expect(third?.message, 'Attendance accepted');
      expect(h.server.posts, 2);
      expect(
        h.server.acceptedPosts,
        2,
      ); // Model server has no duplicate prevention.
    },
  );

  for (final body in [
    "<script>alert('장시간 사용이 없어 로그아웃 되었습니다.');</script>",
    _ssoError,
  ]) {
    test(
      'authentication POST response is classified and recovered without repost: $body',
      () async {
        final h = _Harness(sso: true, attendance: true);
        final container = _attendanceContainer(h);
        final controller = container.read(attendanceProvider.notifier);
        h.server.indexFixtures.add((200, _lecture));
        h.server.postBody = body;
        await controller.fetchLecture();
        final result = await controller.performAttendance(
          requestAuthCode: () async => '1234',
          canContinue: () => true,
        );
        await controller.fetchLecture();
        final hasAlert = body.contains('alert(');
        expect(result?.isError, isTrue);
        expect(result?.hasServerResponse, isTrue);
        expect(result?.needsSessionRecovery, isTrue);
        expect(
          result?.status,
          hasAlert
              ? AttendanceSubmissionStatus.sessionExpired
              : AttendanceSubmissionStatus.ssoIntegrationError,
        );
        expect(container.read(homeControllerProvider).isLoggedIn, isTrue);
        expect(h.server.posts, 1);
        expect(
          h.server.paths.where((path) => path == '/login.jsp'),
          hasLength(1),
        );
      },
    );
  }

  test(
    'attendance control: simultaneous button actions send only one POST',
    () async {
      final h = _Harness(sso: true, attendance: true);
      final container = _attendanceContainer(h);
      final controller = container.read(attendanceProvider.notifier);
      h.server.indexFixtures.add((200, _lecture));
      h.server.postGate = Completer<void>();
      await controller.fetchLecture();
      final first = controller.performAttendance(
        requestAuthCode: () async => '1234',
        canContinue: () => true,
      );
      final second = controller.performAttendance(
        requestAuthCode: () async => '1234',
        canContinue: () => true,
      );
      await h.server.postStarted.future;
      expect(await second, isNull);
      h.server.postGate!.complete();
      expect((await first)?.message, 'Attendance accepted');
      await controller.fetchLecture();
      expect(h.server.posts, 1);
    },
  );

  test('persistent SSO error waits before another automatic fetch', () async {
    final h = _Harness(sso: true, attendance: true);
    final container = _attendanceContainer(h);
    final controller = container.read(attendanceProvider.notifier);
    h.server.indexFixtures.addAll([(200, _ssoError), (200, _ssoError)]);
    h.server.activationBody = _ssoError;
    await controller.fetchLecture(forceRefresh: true, isAutomatic: true);
    await controller.fetchLecture(forceRefresh: true, isAutomatic: true);
    expect(container.read(attendanceProvider).sessionExpired, isFalse);
    expect(container.read(attendanceProvider).retryNotBefore, isNotNull);
    expect(controller.lectureRetryDelay.inSeconds, greaterThanOrEqualTo(29));
    expect(h.server.paths.where((path) => path == '/login.jsp'), hasLength(1));
    expect(h.server.posts, 0);
  });
  test('resume check is skipped while a POST is in flight', () async {
    final h = _Harness(sso: true, attendance: true);
    final container = _attendanceContainer(h);
    final controller = container.read(attendanceProvider.notifier);
    h.server.indexFixtures.add((200, _lecture));
    await controller.fetchLecture();
    h.server.postGate = Completer<void>();
    final submission = controller.performAttendance(
      requestAuthCode: () async => '1234',
      canContinue: () => true,
    );
    await h.server.postStarted.future;
    await container
        .read(homeControllerProvider.notifier)
        .revalidateSessionOnResume('', '');
    expect(h.server.indexCalls, 1);
    h.server.postGate!.complete();
    expect((await submission)?.message, 'Attendance accepted');
    await controller.fetchLecture();
    expect(h.server.posts, 1);
  });

  test(
    'successful SSO recovery preserves input started during activation',
    () async {
      final h = _Harness(sso: true, attendance: true);
      final container = _attendanceContainer(h);
      final controller = container.read(attendanceProvider.notifier);
      h.server.indexFixtures.addAll([(200, _lecture), (200, _ssoError)]);
      await controller.fetchLecture();
      h.server.activationGate = Completer<void>();
      final resume = container
          .read(homeControllerProvider.notifier)
          .revalidateSessionOnResume('', '');
      await h.server.activationStarted.future;
      final code = Completer<String?>();
      final submission = controller.performAttendance(
        requestAuthCode: () => code.future,
        canContinue: () => container.read(homeControllerProvider).isLoggedIn,
      );
      h.server.activationGate!.complete();
      await resume;
      expect(
        container.read(attendanceProvider).phase,
        AttendancePhase.enteringCode,
      );
      code.complete('1234');
      expect((await submission)?.message, 'Attendance accepted');
      await controller.fetchLecture();
      expect(h.server.posts, 1);
      expect(h.transport.clears, 0);
    },
  );

  test(
    'late expiry check cannot reset attendance that already finished',
    () async {
      final h = _Harness(sso: true, attendance: true);
      final container = _attendanceContainer(h);
      final controller = container.read(attendanceProvider.notifier);
      h.server.indexFixtures.addAll([(200, _lecture), (200, '통합 로그인')]);
      await controller.fetchLecture();
      h.server.gateIndexCall = 2;
      final resume = container
          .read(homeControllerProvider.notifier)
          .revalidateSessionOnResume('', '');
      await h.server.indexGateStarted.future;
      await controller.performAttendance(
        requestAuthCode: () async => null,
        canContinue: () => true,
      );
      expect(controller.hasActiveSubmission, isFalse);
      h.server.indexGate.complete();
      await resume;
      expect(container.read(homeControllerProvider).isLoggedIn, isTrue);
      expect(container.read(attendanceProvider).currentLecture, isNotNull);
      expect(h.transport.clears, 0);
      expect(h.server.posts, 0);
    },
  );

  for (final activation in [_ssoError, '']) {
    test(
      'activation retries credentials only for recognized authentication errors: $activation',
      () async {
        final h = _Harness(sso: true)..server.activationBody = activation;
        var passwordReads = 0;
        expect(
          await h.auth.recoverAttendanceSession(
            studentId: 'student',
            readPassword: () async {
              passwordReads++;
              return 'test-password';
            },
            canContinue: () => true,
          ),
          isFalse,
        );
        final shouldReauthenticate = activation == _ssoError;
        expect(passwordReads, shouldReauthenticate ? 1 : 0);
        expect(
          h.server.paths.where((path) => path.endsWith('LoginCheck_SSO.php')),
          hasLength(shouldReauthenticate ? 1 : 0),
        );
        expect(
          h.server.paths.where((path) => path.endsWith('LoginExec3.php')),
          hasLength(shouldReauthenticate ? 1 : 0),
        );
        expect(
          h.server.paths.where((path) => path == '/login.jsp'),
          hasLength(shouldReauthenticate ? 2 : 1),
        );
      },
    );
  }

  test(
    'SSO cooldown resumes polling after 30 seconds and permits manual refresh',
    () async {
      var now = DateTime.utc(2026);
      final h = _Harness(sso: true, attendance: true);
      final container = _attendanceContainer(h, now: () => now);
      final controller = container.read(attendanceProvider.notifier);
      h.server.activationBody = _ssoError;
      h.server.indexFixtures.addAll(List.filled(4, (200, _ssoError)));
      await controller.fetchLecture(forceRefresh: true, isAutomatic: true);
      now = now.add(const Duration(seconds: 29));
      await controller.fetchLecture(forceRefresh: true, isAutomatic: true);
      expect(h.server.indexCalls, 1);
      now = now.add(const Duration(seconds: 1));
      await controller.fetchLecture(forceRefresh: true, isAutomatic: true);
      expect(h.server.indexCalls, 2);
      await controller.fetchLecture(forceRefresh: true);
      expect(h.server.indexCalls, 3);
      expect(
        h.server.paths.where((path) => path == '/login.jsp'),
        hasLength(3),
      );
      expect(h.server.posts, 0);
    },
  );

  for (final status in [401, 503]) {
    test(
      'POST $status preserves the received response and does not repost',
      () async {
        final h = _Harness(sso: true, attendance: true);
        final container = _attendanceContainer(h);
        final controller = container.read(attendanceProvider.notifier);
        h.server.indexFixtures.add((200, _lecture));
        h.server.postStatus = status;
        h.server.postBody = status == 401 ? _ssoError : 'Busy';
        await controller.fetchLecture();
        final result = await controller.performAttendance(
          requestAuthCode: () async => '1234',
          canContinue: () => true,
        );
        await controller.fetchLecture();
        expect(result?.hasServerResponse, isTrue);
        expect(result?.isUnconfirmed, isTrue);
        expect(result?.needsSessionRecovery, status == 401);
        expect(h.server.posts, 1);
      },
    );
  }
}

ProviderContainer _attendanceContainer(
  _Harness h, {
  DateTime Function()? now,
}) => ProviderContainer.test(
  overrides: [
    schoolTransportProvider.overrideWithValue(h.transport),
    homeControllerProvider.overrideWith(_Home.new),
    attendanceProvider.overrideWith(
      () => AttendanceController(
        now: now,
        locationProvider: () async => Position(
          latitude: 37,
          longitude: 126,
          timestamp: DateTime.utc(2026),
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
)..read(homeControllerProvider);

const _ssoErrorMessage = '출결 서버 SSO 연동에 실패했어요.';

class _Home extends HomeController {
  @override
  HomeState build() {
    super.build();
    return const HomeState(isLoggedIn: true, userId: 'student');
  }
}

class _Harness {
  _Harness({bool sso = false, bool attendance = false}) {
    server = _Server()..attendanceActive = attendance;
    if (sso) {
      store.saveSetCookie(
        Uri.parse('https://ap.hongik.ac.kr/'),
        'SSO=test-sso; Domain=.hongik.ac.kr; Path=/; Secure',
      );
    }
    if (attendance) {
      store.saveSetCookie(
        Uri.parse('https://at.hongik.ac.kr/'),
        'JSESSIONID=at-session; Path=/; Secure',
      );
    }
    final dio = Dio()..httpClientAdapter = server;
    addTearDown(() => dio.close(force: true));
    transport = _TrackingTransport(SchoolTransportWeb(dio, store));
    auth = AuthService(transport);
  }
  final store = WebAuthCookieStore();
  late final _Server server;
  late final _TrackingTransport transport;
  late final AuthService auth;
}

class _TrackingTransport implements SchoolTransport {
  _TrackingTransport(this.delegate);
  final SchoolTransport delegate;
  int clears = 0;
  @override
  Future<Response<T>> get<T>(
    String target, {
    Map<String, dynamic>? queryParameters,
    SchoolRequestOptions options = const SchoolRequestOptions(),
  }) => delegate.get<T>(
    target,
    queryParameters: queryParameters,
    options: options,
  );
  @override
  Future<Response<T>> post<T>(
    String target, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    SchoolRequestOptions options = const SchoolRequestOptions(),
  }) => delegate.post<T>(
    target,
    data: data,
    queryParameters: queryParameters,
    options: options,
  );
  @override
  Future<void> clearAuthSession() async {
    clears++;
    await delegate.clearAuthSession();
  }

  @override
  Future<bool> hasAuthSession() => delegate.hasAuthSession();
  @override
  Future<bool> hasCookie(Uri target, String name) =>
      delegate.hasCookie(target, name);
  @override
  Future<void> saveAuthCookies(List<Cookie> cookies) =>
      delegate.saveAuthCookies(cookies);
}

// Contract model: shared SSO authorizes attendance activation; its local
// JSESSIONID authorizes attendance pages. This is not a real school server.
class _Server implements HttpClientAdapter {
  final paths = <String>[];
  final cookies = <String>[];
  final indexFixtures = <(int, String)>[];
  final indexGateStarted = Completer<void>();
  final indexGate = Completer<void>();
  int indexCalls = 0;
  int? gateIndexCall;
  final postStarted = Completer<void>();
  final activationStarted = Completer<void>();
  Completer<void>? activationGate;
  Completer<void>? postGate;
  int posts = 0, acceptedPosts = 0;
  int postStatus = 200;
  bool postTimeout = false;
  String postBody = "<script>alert('Attendance accepted');</script>";
  bool credentialsAccepted = true,
      issueSso = true,
      issueAttendance = true,
      attendanceActive = false,
      activationNetworkFailure = false;
  String activationBody = 'activated';
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final target = Uri.parse(options.uri.queryParameters['url']!);
    final sentCookie = (options.headers['X-Target-Cookie'] ?? '').toString();
    paths.add(target.path);
    cookies.add(sentCookie);
    String body = 'ok';
    int status = 200;
    String contentType = 'text/html; charset=utf-8';
    String? cookie;
    switch (target.path) {
      case '/login/LoginCheck_SSO.php':
        contentType = 'application/json';
        body = jsonEncode({
          'result_code': credentialsAccepted ? 'Y' : 'N',
          'result_msg': 'Invalid credentials',
        });
      case '/login/LoginExec3.php':
        body = issueSso
            ? "<script>SetCookie('SSO', 'test-sso');</script>"
            : 'ok';
      case '/login.jsp':
        if (!activationStarted.isCompleted) activationStarted.complete();
        if (activationGate != null) await activationGate!.future;
        if (activationNetworkFailure) {
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
          );
        }
        if (sentCookie.contains('SSO=test-sso')) {
          body = activationBody;
          if (issueAttendance) {
            attendanceActive = true;
            cookie = 'JSESSIONID=at-session; Path=/; Secure';
          }
        } else {
          body = '통합 로그인';
        }
      case '/index.jsp':
        if (++indexCalls == gateIndexCall) {
          indexGateStarted.complete();
          await indexGate.future;
        }
        if (indexFixtures.isNotEmpty) {
          final fixture = indexFixtures.removeAt(0);
          status = fixture.$1;
          body = fixture.$2;
        } else {
          body =
              attendanceActive && sentCookie.contains('JSESSIONID=at-session')
              ? _table
              : '통합 로그인';
        }
      case '/stud02_proc.jsp':
        status = postStatus;
        posts++;
        if (!postStarted.isCompleted) {
          postStarted.complete();
        }
        if (postBody.contains('Attendance accepted')) {
          acceptedPosts++;
        }
        if (postGate != null) {
          await postGate!.future;
        }
        if (postTimeout) {
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.receiveTimeout,
          );
        }
        body = postBody;
    }
    if (status == -1) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
    }
    return ResponseBody.fromString(
      body,
      status,
      headers: {
        'content-type': [contentType],
        if (cookie != null)
          'x-target-set-cookies': [
            base64Url.encode(
              utf8.encode(
                jsonEncode([
                  {
                    'url': target.toString(),
                    'cookies': [cookie],
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
