import 'dart:async';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hongik_ingan/core/network/school_request_options.dart';
import 'package:hongik_ingan/core/network/school_transport.dart';
import 'package:hongik_ingan/core/network/school_transport_provider.dart';
import 'package:hongik_ingan/core/theme/theme.dart';
import 'package:hongik_ingan/features/attendance/application/attendance_controller.dart';
import 'package:hongik_ingan/features/attendance/application/attendance_history_provider.dart';
import 'package:hongik_ingan/features/attendance/data/attendance_history_repository.dart';
import 'package:hongik_ingan/features/attendance/domain/attendance_request_record.dart';
import 'package:hongik_ingan/features/attendance/domain/attendance_submission_result.dart';
import 'package:hongik_ingan/features/attendance/presentation/attendance_history_view.dart';
import 'package:hongik_ingan/features/attendance/presentation/attendance_section.dart';
import 'package:hongik_ingan/features/home/application/home_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('restores only the latest 20 requests per account', () async {
    final repository = AttendanceHistoryRepository();
    await repository.save('second', _record(99));
    await Future.wait([
      for (var index = 0; index < 25; index++)
        repository.save('first', _record(index)),
    ]);
    final stored = await SharedPreferences.getInstance();
    SharedPreferences.setMockInitialValues({
      for (final key in stored.getKeys()) key: stored.get(key)!,
    });
    final restored = AttendanceHistoryRepository();
    final first = await restored.load('first');
    expect(first, hasLength(20));
    expect(first.first.id, '24');
    expect(first.last.id, '5');
    expect(first.first.authCode, '0123');
    expect(first.first.requestedAt.isUtc, isTrue);
    expect((await restored.load('second')).single.id, '99');
    expect(await restored.load('third'), isEmpty);
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString('attendance_history_v1:first')!;
    expect(encoded, isNot(contains('latitude')));
    expect(encoded, isNot(contains('attendanceParams')));
  });

  test('updates a request without merging separate retries', () async {
    final repository = AttendanceHistoryRepository();
    final request = _record(1);
    await Future.wait([
      repository.save('student', request),
      repository.save(
        'student',
        request.withResult(
          const AttendanceSubmissionResult.notice('인증번호가 올바르지 않아요.'),
        ),
      ),
      repository.save('student', _record(2)),
    ]);
    final records = await repository.load('student');
    expect(records, hasLength(2));
    expect(records.last.hasServerResponse, isTrue);
    expect(records.last.message, '인증번호가 올바르지 않아요.');
    expect(records.first.hasServerResponse, isFalse);
  });

  test(
    'preserves corrupt data without blocking writes for another account',
    () async {
      SharedPreferences.setMockInitialValues({
        'attendance_history_v1:broken': '{',
      });
      final repository = AttendanceHistoryRepository();
      await expectLater(repository.load('broken'), throwsFormatException);
      await expectLater(
        repository.save('broken', _record(1)),
        throwsFormatException,
      );
      await repository.save('other', _record(2));
      expect((await repository.load('other')).single.id, '2');
      expect(
        (await SharedPreferences.getInstance()).getString(
          'attendance_history_v1:broken',
        ),
        '{',
      );
    },
  );

  test(
    'records the sent lecture, timestamp, number and server refusal verbatim',
    () async {
      final h = _harness();
      await h.controller.fetchLecture();
      final result = await h.controller.performAttendance(
        userId: 'student',
        requestAuthCode: () async => '0123',
        canContinue: () => true,
      );
      final records = await h.repository.load('student');
      expect(result?.message, '인증번호가 올바르지 않아요.');
      expect(records, hasLength(1));
      expect(records.single.lectureName, '검증된 수업');
      expect(records.single.requestedAt, DateTime.utc(2026, 10, 4, 1, 2, 3));
      expect(records.single.authCode, '0123');
      expect(records.single.hasServerResponse, isTrue);
      expect(records.single.message, result?.message);
      await h.controller.fetchLecture();
      expect(await h.repository.load('student'), hasLength(1));
    },
  );

  test('does not record cancelled input or location failure', () async {
    final h = _harness(locationFails: true);
    await h.controller.fetchLecture();
    await h.controller.performAttendance(
      userId: 'student',
      requestAuthCode: () async => null,
      canContinue: () => true,
    );
    await expectLater(
      h.controller.performAttendance(
        userId: 'student',
        requestAuthCode: () async => '0123',
        canContinue: () => true,
      ),
      throwsException,
    );
    expect(h.transport.submissions, 0);
    expect(await h.repository.load('student'), isEmpty);
  });

  test('keeps an unknown result after a network error', () async {
    final h = _harness();
    h.transport.failSubmission = true;
    await h.controller.fetchLecture();
    await h.controller.performAttendance(
      userId: 'student',
      requestAuthCode: () async => '0123',
      canContinue: () => true,
    );
    final record = (await h.repository.load('student')).single;
    expect(record.hasServerResponse, isFalse);
    expect(record.isUnconfirmed, isTrue);
    expect(record.message, contains('출결 처리 여부를 확인하지 못했어요.'));
  });

  test(
    'keeps in-flight and late results under the originating account after logout',
    () async {
      final h = _harness();
      final response = Completer<Response<String>>();
      h.transport.pendingSubmission = response;
      await h.controller.fetchLecture();
      final submission = h.controller.performAttendance(
        userId: 'first',
        requestAuthCode: () async => '0123',
        canContinue: () => true,
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        (await h.repository.load('first')).single.hasServerResponse,
        isFalse,
      );
      h.controller.resetSession();
      response.complete(_response("<script>alert('이미 출석했어요.')</script>"));
      expect(await submission, isNull);
      expect((await h.repository.load('first')).single.message, '이미 출석했어요.');
      expect(await h.repository.load('second'), isEmpty);
    },
  );

  test(
    'blocked or failed storage does not delay attendance completion',
    () async {
      final repository = _BlockedRepository();
      final h = _harness(repository: repository);
      await h.controller.fetchLecture();
      final result = await h.controller.performAttendance(
        userId: 'student',
        requestAuthCode: () async => '0123',
        canContinue: () => true,
      );
      expect(result?.message, '인증번호가 올바르지 않아요.');
      expect(h.transport.submissions, 1);
      expect(repository.attempts, 2);
      repository.gate.complete();
      await Future<void>.delayed(Duration.zero);
    },
  );

  testWidgets(
    'first submit tap with keyboard open sends and records one request',
    (tester) async {
      tester.view.physicalSize = const Size(390, 520);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final h = _harness();
      await tester.pumpWidget(_flowSubject(h.container));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, '출결 번호 입력'));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 320);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '0705');
      await tester.pump();
      final submit = find.widgetWithText(ElevatedButton, '제출');
      expect(submit.hitTestable(), findsOneWidget);
      expect(tester.getRect(submit).bottom, lessThanOrEqualTo(200));
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(h.transport.submissions, 1);
      expect((h.transport.lastPayload as Map)['key'], '0705');
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pumpAndSettle();
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('attendance-history-button')));
      await tester.pumpAndSettle();
      expect(find.text('출결 번호  0705'), findsOneWidget);
      expect(find.text('서버 응답'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final scenario in [
    (
      name: 'success',
      body: "<script>alert('출석이 완료됐어요.')</script>",
      message: '출석이 완료됐어요.',
      response: true,
      networkError: false,
    ),
    (
      name: 'refusal',
      body: "<script>alert('인증번호가 올바르지 않아요.')</script>",
      message: '인증번호가 올바르지 않아요.',
      response: true,
      networkError: false,
    ),
    (
      name: 'unknown response',
      body: '<html>unexpected</html>',
      message: '출결 서버 응답을 해석하지 못했어요. 학교 출결 내역을 확인한 뒤 다시 입력해 주세요.',
      response: false,
      networkError: false,
    ),
    (
      name: 'network failure',
      body: '',
      message: '네트워크 오류로 출결 처리 여부를 확인하지 못했어요. 학교 출결 내역을 확인한 뒤 다시 입력해 주세요.',
      response: false,
      networkError: true,
    ),
  ]) {
    testWidgets(
      'code submission through the UI is saved and readable: ${scenario.name}',
      (tester) async {
        final h = _harness();
        h.transport.submissionBody = scenario.body;
        h.transport.failSubmission = scenario.networkError;
        await tester.pumpWidget(_flowSubject(h.container));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ElevatedButton, '출결 번호 입력'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '0123');
        await tester.pump();
        await tester.tap(find.widgetWithText(ElevatedButton, '제출'));
        await tester.pumpAndSettle();
        expect(h.transport.submissions, 1);
        expect((h.transport.lastPayload as Map)['key'], '0123');
        expect(find.text(scenario.message), findsOneWidget);
        await tester.tap(find.text('확인'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('attendance-history-button')),
        );
        await tester.pumpAndSettle();
        expect(find.text('검증된 수업'), findsWidgets);
        expect(find.text('요청 시각  2026.10.04 10:02:03'), findsOneWidget);
        expect(find.text('출결 번호  0123'), findsOneWidget);
        expect(
          find.text(scenario.response ? '서버 응답' : '서버 결과 확인 불가'),
          findsOneWidget,
        );
        expect(find.text(scenario.message), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('history opened during submission updates to the server result', (
    tester,
  ) async {
    final h = _harness();
    final response = Completer<Response<String>>();
    h.transport.pendingSubmission = response;
    await tester.pumpWidget(_flowSubject(h.container));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, '출결 번호 입력'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '0123');
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, '제출'));
    await tester.pumpAndSettle();
    expect(h.transport.submissions, 1);
    expect(
      tester
          .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, '출석 제출 중'),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const ValueKey('attendance-history-button')));
    await tester.pumpAndSettle();
    expect(find.text('서버 결과 확인 불가'), findsOneWidget);
    expect(find.text('요청 결과를 아직 확인하지 못했어요.'), findsOneWidget);
    response.complete(_response("<script>alert('출석이 완료됐어요.')</script>"));
    await tester.pumpAndSettle();
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(find.text('서버 응답'), findsOneWidget);
    expect(find.text('출석이 완료됐어요.'), findsOneWidget);
    expect(find.text('서버 결과 확인 불가'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test(
    'a response after container disposal still updates the stored request',
    () async {
      final h = _harness();
      final response = Completer<Response<String>>();
      h.transport.pendingSubmission = response;
      await h.controller.fetchLecture();
      final submission = h.controller.performAttendance(
        userId: 'student',
        requestAuthCode: () async => '0123',
        canContinue: () => true,
      );
      await Future<void>.delayed(Duration.zero);
      expect(await h.repository.load('student'), hasLength(1));
      h.container.dispose();
      response.complete(_response("<script>alert('출석이 완료됐어요.')</script>"));
      expect(await submission, isNull);
      expect((await h.repository.load('student')).single.message, '출석이 완료됐어요.');
    },
  );
  test(
    'uncertain HTTP response survives storage and older records remain readable',
    () async {
      final repository = AttendanceHistoryRepository();
      final uncertain = _record(1).withResult(
        const AttendanceSubmissionResult.unconfirmed(
          'Unrecognized response',
          hasServerResponse: true,
        ),
      );
      await repository.save('student', uncertain);
      final restored = (await AttendanceHistoryRepository().load(
        'student',
      )).single;
      expect(restored.hasServerResponse, isTrue);
      expect(restored.isUnconfirmed, isTrue);
      expect(restored.hasKnownResult, isFalse);
      final legacyJson = uncertain.toJson()..remove('isUnconfirmed');
      final legacy = AttendanceRequestRecord.fromJson(legacyJson);
      expect(legacy.isUnconfirmed, isFalse);
      expect(legacy.hasKnownResult, isTrue);
    },
  );

  for (final scenario in [
    (size: const Size(390, 844), scale: 1.0),
    (size: const Size(320, 480), scale: 2.0),
  ]) {
    testWidgets(
      'uncertain retry requires explicit confirmation at ${scenario.size} scale ${scenario.scale}',
      (tester) async {
        tester.view.physicalSize = scenario.size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final h = _harness();
        h.transport.failSubmission = true;
        await tester.pumpWidget(
          _flowSubject(h.container, scale: scenario.scale),
        );
        await tester.pumpAndSettle();
        await _submitThroughUi(tester, '0123');
        expect(h.transport.submissions, 1);
        await tester.tap(find.text('확인'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.widgetWithText(ElevatedButton, '출결 번호 입력'),
        );
        await tester.tap(find.widgetWithText(ElevatedButton, '출결 번호 입력'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('attendance-retry-confirmation')),
          findsOneWidget,
        );
        expect(find.byType(TextField), findsNothing);
        expect(h.transport.submissions, 1);
        await tester.tap(find.text('취소'));
        await tester.pumpAndSettle();
        expect(h.transport.submissions, 1);
        await tester.tap(find.widgetWithText(ElevatedButton, '출결 번호 입력'));
        await tester.pumpAndSettle();
        h.transport.failSubmission = false;
        await tester.tap(find.text('다시 입력'));
        await tester.pumpAndSettle();
        expect(h.transport.submissions, 1);
        await tester.enterText(find.byType(TextField), '4567');
        await tester.pump();
        await tester.ensureVisible(find.widgetWithText(ElevatedButton, '제출'));
        await tester.tap(find.widgetWithText(ElevatedButton, '제출'));
        await tester.pumpAndSettle();
        expect(h.transport.submissions, 2);
        final records = await h.repository.load('student');
        expect(records, hasLength(2));
        expect(records.first.isUnconfirmed, isFalse);
        expect(records.last.isUnconfirmed, isTrue);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('logout closes retry confirmation without another POST', (
    tester,
  ) async {
    final h = _harness();
    h.transport.failSubmission = true;
    await h.controller.fetchLecture();
    await h.controller.performAttendance(
      requestAuthCode: () async => '0123',
      canContinue: () => true,
    );
    await h.controller.fetchLecture();
    await tester.pumpWidget(_flowSubject(h.container));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, '출결 번호 입력'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('attendance-retry-confirmation')),
      findsOneWidget,
    );
    (h.container.read(homeControllerProvider.notifier) as _FlowHome)
        .endSession();
    h.controller.resetSession();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('attendance-retry-confirmation')),
      findsNothing,
    );
    expect(h.transport.submissions, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Future<void> _submitThroughUi(WidgetTester tester, String code) async {
  final enter = find.widgetWithText(ElevatedButton, '출결 번호 입력');
  await tester.ensureVisible(enter);
  await tester.tap(enter);
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), code);
  await tester.pump();
  final submit = find.widgetWithText(ElevatedButton, '제출');
  await tester.ensureVisible(submit);
  await tester.tap(submit);
  await tester.pumpAndSettle();
}

Widget _flowSubject(ProviderContainer container, {double scale = 1}) =>
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: themeData,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: const Scaffold(
          body: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: AttendanceHistoryButton(),
                ),
                AttendanceSection(),
              ],
            ),
          ),
        ),
      ),
    );

class _FlowHome extends HomeController {
  void endSession() => state = state.copyWith(isLoggedIn: false);
  @override
  HomeState build() => const HomeState(isLoggedIn: true, userId: 'student');
}

AttendanceRequestRecord _record(int index) => AttendanceRequestRecord(
  id: '$index',
  lectureName: '수업 $index',
  requestedAt: DateTime.utc(2026, 10, 4, 1, index),
  authCode: '0123',
);

({
  ProviderContainer container,
  AttendanceController controller,
  AttendanceHistoryRepository repository,
  _Transport transport,
})
_harness({
  bool locationFails = false,
  AttendanceHistoryRepository? repository,
}) {
  final transport = _Transport();
  final history = repository ?? AttendanceHistoryRepository();
  final now = DateTime.utc(2026, 10, 4, 1, 2, 3);
  final container = ProviderContainer.test(
    overrides: [
      schoolTransportProvider.overrideWithValue(transport),
      homeControllerProvider.overrideWith(_FlowHome.new),
      attendanceHistoryRepositoryProvider.overrideWithValue(history),
      attendanceProvider.overrideWith(
        () => AttendanceController(
          now: () => now,
          locationProvider: () async {
            if (locationFails) throw Exception('위치를 가져오지 못했어요.');
            return Position(
              latitude: 37,
              longitude: 126,
              timestamp: now,
              accuracy: 0,
              altitude: 0,
              altitudeAccuracy: 0,
              heading: 0,
              headingAccuracy: 0,
              speed: 0,
              speedAccuracy: 0,
            );
          },
        ),
      ),
    ],
  );
  return (
    container: container,
    controller: container.read(attendanceProvider.notifier),
    repository: history,
    transport: transport,
  );
}

class _BlockedRepository extends AttendanceHistoryRepository {
  final gate = Completer<void>();
  int attempts = 0;
  @override
  Future<void> save(String userId, AttendanceRequestRecord record) async {
    attempts++;
    await gate.future;
    throw StateError('Storage unavailable');
  }
}

Response<String> _response(String data) => Response<String>(
  data: data,
  statusCode: 200,
  requestOptions: RequestOptions(
    path: 'https://at.hongik.ac.kr/stud02_proc.jsp',
  ),
);

class _Transport implements SchoolTransport {
  int submissions = 0;
  bool failSubmission = false;
  Object? lastPayload;
  String submissionBody = "<script>alert('인증번호가 올바르지 않아요.')</script>";
  Completer<Response<String>>? pendingSubmission;
  @override
  Future<Response<T>> get<T>(
    String target, {
    Map<String, dynamic>? queryParameters,
    SchoolRequestOptions options = const SchoolRequestOptions(),
  }) async =>
      _response('''<table><tbody><tr>
<td>1</td><td>2</td><td>검증된 수업</td><td>Room</td><td>10:00</td>
<td><form action="stud02.jsp"><input name="lecture" value="1"></form></td>
</tr></tbody></table>''')
          as Response<T>;
  @override
  Future<Response<T>> post<T>(
    String target, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    SchoolRequestOptions options = const SchoolRequestOptions(),
  }) async {
    submissions++;
    lastPayload = data;
    if (failSubmission) {
      throw DioException(
        requestOptions: RequestOptions(path: target),
        type: DioExceptionType.connectionError,
      );
    }
    return (await pendingSubmission?.future ?? _response(submissionBody))
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
