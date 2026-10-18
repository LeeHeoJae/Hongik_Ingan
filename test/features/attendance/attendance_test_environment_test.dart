import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/features/attendance/application/attendance_controller.dart';
import 'package:hongik_ingan/features/attendance/debug/attendance_test_environment.dart';
import 'package:hongik_ingan/features/attendance/domain/attendance_submission_result.dart';
import 'package:hongik_ingan/features/home/application/home_controller.dart';
import 'package:hongik_ingan/features/attendance/application/attendance_data_source.dart';
import 'package:hongik_ingan/features/attendance/application/attendance_overview_provider.dart';
import 'package:hongik_ingan/features/attendance/application/attendance_history_provider.dart';
import '../../support/attendance_test_host.dart';

void main() {
  test('로그인 전에는 테스트를 예약하고 취소할 때 수업을 조회하지 않는다', () async {
    final host = AttendanceTestHost(loggedIn: false);
    addTearDown(host.dispose);
    final home = host.container.read(homeControllerProvider);
    await host.enable();
    expect(host.container.read(homeControllerProvider), same(home));
    expect(host.container.read(attendanceProvider).currentLecture, isNull);
    expect(host.transport.lectureRequests, 0);

    (host.container.read(homeControllerProvider.notifier) as TestHomeController)
        .updateLoginOptions();
    expect(
      host.container.read(attendanceDataSourceOverrideProvider),
      isNotNull,
    );
    expect(host.container.read(homeControllerProvider).isLoggedIn, isFalse);

    await host.container
        .read(attendanceTestControllerProvider.notifier)
        .disable();
    expect(host.container.read(attendanceDataSourceOverrideProvider), isNull);
    expect(host.container.read(attendanceProvider).currentLecture, isNull);
    expect(host.realTransport.requests, isEmpty);
    expect(host.realHistory.writes, 0);
  });

  test('로그인 전 예약한 테스트 소스가 로그인 직후 첫 수업 조회에 적용된다', () async {
    final host = AttendanceTestHost(loggedIn: false);
    addTearDown(host.dispose);
    await host.enable();
    final source = host.container.read(attendanceDataSourceOverrideProvider);
    await host.container
        .read(homeControllerProvider.notifier)
        .login('OTHER_USER', 'password');
    await host.container.read(attendanceProvider.notifier).fetchLecture();
    expect(
      host.container.read(attendanceDataSourceOverrideProvider),
      same(source),
    );
    expect(
      host.container.read(attendanceTestControllerProvider),
      AttendanceTestScenario.normal,
    );
    expect(host.container.read(homeControllerProvider).userId, 'OTHER_USER');
    expect(
      host.container.read(attendanceProvider).currentLecture?.name,
      '모바일 앱 프로그래밍',
    );
    expect(host.transport.lectureRequests, 1);
    expect(host.realTransport.requests, isEmpty);
  });

  Future<AttendanceTestHost> environment([
    AttendanceTestScenario scenario = AttendanceTestScenario.normal,
  ]) async {
    final result = AttendanceTestHost();
    addTearDown(result.dispose);
    await result.enable(scenario);
    return result;
  }

  test('실제 조회·제출·응답 해석·재조회와 메모리 기록 저장을 실행한다', () async {
    final sandbox = await environment();
    final controller = sandbox.container.read(attendanceProvider.notifier);
    expect(controller.runtimeType, AttendanceController);
    await controller.fetchLecture();
    expect(
      sandbox.container.read(attendanceProvider).currentLecture?.name,
      '모바일 앱 프로그래밍',
    );
    final result = await controller.performAttendance(
      userId: AttendanceTestHost.userId,
      requestAuthCode: () async => '1234',
      canContinue: () => true,
    );
    await controller.fetchLecture();
    await sandbox.container.pump();
    expect(result?.message, '출석이 완료됐어요.');
    expect(result?.status, AttendanceSubmissionStatus.notice);
    expect(sandbox.transport.lectureRequests, 2);
    expect(sandbox.transport.submissions.single, {
      'yy': '2026',
      'hakgi': '2',
      'haksu': '123456',
      'bunban': '1',
      'key': '1234',
      'latitude': '37.551',
      'longitude': '126.925',
    });
    final state = sandbox.container.read(attendanceProvider);
    expect(state.currentLecture, isNull);
    expect(state.submissionResult, same(result));
    final records = await sandbox.history.load(AttendanceTestHost.userId);
    expect(records, hasLength(1));
    expect(records.single.hasKnownResult, isTrue);
    expect(records.single.message, result?.message);
    expect(records.single.courseKey?.courseCode, '123456');
    await controller.refreshLectureForInput();
    expect(sandbox.container.read(attendanceProvider).submissionResult, isNull);
  });

  test('다른 번호도 실제 서버 안내와 같은 경로로 해석한다', () async {
    final sandbox = await environment();
    final controller = sandbox.container.read(attendanceProvider.notifier);
    await controller.fetchLecture();
    final result = await controller.performAttendance(
      requestAuthCode: () async => '0000',
      canContinue: () => true,
    );
    await controller.fetchLecture();
    expect(result?.message, '인증번호가 올바르지 않아요.');
    // Server notices are not reclassified based on their wording.
    expect(result?.status, AttendanceSubmissionStatus.notice);
    expect(sandbox.transport.submissions.single['key'], '0000');
    await controller.refreshLectureForInput();
    expect(
      sandbox.container.read(attendanceProvider).currentLecture,
      isNotNull,
    );
  });

  test('상황 변경은 같은 컨테이너와 컨트롤러에서 출결 상태만 갱신한다', () async {
    final sandbox = await environment();
    final container = sandbox.container;
    final controller = container.read(attendanceProvider.notifier);
    final session = container.read(homeControllerProvider);
    await controller.fetchLecture();
    await controller.performAttendance(
      userId: AttendanceTestHost.userId,
      requestAuthCode: () async => '1234',
      canContinue: () => true,
    );
    await controller.fetchLecture();
    await sandbox.changeScenario(AttendanceTestScenario.empty);
    expect(container.read(attendanceProvider).currentLecture, isNull);
    expect(container.read(attendanceProvider).submissionResult, isNull);
    await sandbox.changeScenario(AttendanceTestScenario.fetchFailure);
    expect(container.read(attendanceProvider).error, isNotNull);
    await sandbox.changeScenario(AttendanceTestScenario.normal);
    expect(container.read(attendanceProvider).currentLecture, isNotNull);
    expect(container.read(attendanceProvider).error, isNull);
    expect(sandbox.container, same(container));
    expect(container.read(attendanceProvider.notifier), same(controller));
    expect(container.read(homeControllerProvider), same(session));
    expect(await sandbox.history.load(AttendanceTestHost.userId), hasLength(1));
    expect(sandbox.transport.submissions, hasLength(1));
  });

  test('상황 변경 후 위치와 제출도 새 시나리오를 사용한다', () async {
    final sandbox = await environment();
    final controller = sandbox.container.read(attendanceProvider.notifier);
    await sandbox.changeScenario(AttendanceTestScenario.locationFailure);
    await expectLater(
      controller.performAttendance(
        requestAuthCode: () async => '1234',
        canContinue: () => true,
      ),
      throwsException,
    );
    expect(sandbox.transport.submissions, isEmpty);
    await sandbox.changeScenario(AttendanceTestScenario.unconfirmed);
    final result = await controller.performAttendance(
      requestAuthCode: () async => '1234',
      canContinue: () => true,
    );
    await controller.fetchLecture();
    expect(result?.isUnconfirmed, isTrue);
    expect(sandbox.transport.submissions, hasLength(1));
  });

  test('입력 취소와 중복 요청은 서버 제출이나 기록을 만들지 않는다', () async {
    final sandbox = await environment();
    final controller = sandbox.container.read(attendanceProvider.notifier);
    await controller.fetchLecture();
    final code = Completer<String?>();
    final first = controller.performAttendance(
      userId: AttendanceTestHost.userId,
      requestAuthCode: () => code.future,
      canContinue: () => true,
    );
    var secondInputOpened = false;
    final second = await controller.performAttendance(
      requestAuthCode: () async {
        secondInputOpened = true;
        return '1234';
      },
      canContinue: () => true,
    );
    expect(second, isNull);
    expect(secondInputOpened, isFalse);
    code.complete(null);
    expect(await first, isNull);
    expect(sandbox.transport.submissions, isEmpty);
    expect(await sandbox.history.load(AttendanceTestHost.userId), isEmpty);
    expect(
      sandbox.container.read(attendanceProvider).phase,
      AttendancePhase.idle,
    );
  });

  for (final scenario in [
    AttendanceTestScenario.empty,
    AttendanceTestScenario.fetchFailure,
  ]) {
    test('${scenario.label}는 실제 조회 결과로 입력을 막는다', () async {
      final sandbox = await environment(scenario);
      final controller = sandbox.container.read(attendanceProvider.notifier);
      await controller.fetchLecture();
      final state = sandbox.container.read(attendanceProvider);
      expect(state.hasCheckedLecture, isTrue);
      expect(state.currentLecture, isNull);
      expect(
        state.error != null,
        scenario == AttendanceTestScenario.fetchFailure,
      );
      expect(
        await controller.performAttendance(
          requestAuthCode: () async => fail('번호 입력을 열면 안 됩니다.'),
          canContinue: () => true,
        ),
        isNull,
      );
      expect(sandbox.transport.submissions, isEmpty);
    });
  }

  test('위치 확인 실패는 제출과 기록 저장 전에 종료한다', () async {
    final sandbox = await environment(AttendanceTestScenario.locationFailure);
    final controller = sandbox.container.read(attendanceProvider.notifier);
    await controller.fetchLecture();
    await expectLater(
      controller.performAttendance(
        userId: AttendanceTestHost.userId,
        requestAuthCode: () async => '1234',
        canContinue: () => true,
      ),
      throwsException,
    );
    expect(sandbox.transport.submissions, isEmpty);
    expect(await sandbox.history.load(AttendanceTestHost.userId), isEmpty);
    expect(
      sandbox.container.read(attendanceProvider).phase,
      AttendancePhase.idle,
    );
  });

  test('처리 여부 확인 불가 후 자동 재제출하지 않고 재입력 확인을 거친다', () async {
    final sandbox = await environment(AttendanceTestScenario.unconfirmed);
    final controller = sandbox.container.read(attendanceProvider.notifier);
    await controller.fetchLecture();
    Future<AttendanceSubmissionResult?> submit({bool? confirm}) =>
        controller.performAttendance(
          userId: AttendanceTestHost.userId,
          requestAuthCode: () async => '1234',
          canContinue: () => true,
          confirmUnconfirmedRetry: confirm == null
              ? null
              : (_) async => confirm,
        );
    final result = await submit();
    await controller.fetchLecture();
    await sandbox.container.pump();
    expect(result?.isUnconfirmed, isTrue);
    expect(sandbox.transport.submissions, hasLength(1));
    expect(
      (await sandbox.history.load(
        AttendanceTestHost.userId,
      )).single.isUnconfirmed,
      isTrue,
    );
    await controller.refreshLectureForInput();
    expect(await submit(confirm: false), isNull);
    expect(sandbox.transport.submissions, hasLength(1));
    await submit(confirm: true);
    await controller.fetchLecture();
    expect(sandbox.transport.submissions, hasLength(2));
  });

  test('테스트 세션과 기록은 독립되며 미정의 요청은 차단한다', () async {
    final first = await environment();
    final second = await environment();
    final controller = first.container.read(attendanceProvider.notifier);
    await controller.fetchLecture();
    await controller.performAttendance(
      userId: AttendanceTestHost.userId,
      requestAuthCode: () async => '1234',
      canContinue: () => true,
    );
    await controller.fetchLecture();
    await first.container.read(homeControllerProvider.notifier).logout();
    expect(first.container.read(homeControllerProvider).isLoggedIn, isFalse);
    expect(second.container.read(homeControllerProvider).isLoggedIn, isTrue);
    expect(second.container.read(attendanceProvider).hasCheckedLecture, isTrue);
    expect(await second.history.load(AttendanceTestHost.userId), isEmpty);
    await expectLater(
      first.transport.get<String>('https://at.hongik.ac.kr/login.jsp'),
      throwsUnsupportedError,
    );
    await expectLater(
      first.transport.post<String>('https://example.com/'),
      throwsUnsupportedError,
    );
    expect(second.transport.submissions, isEmpty);
  });

  test('테스트를 끄면 같은 로그인과 컨트롤러에서 실제 출결 소스로 복귀한다', () async {
    final host = await environment();
    final container = host.container;
    final controller = container.read(attendanceProvider.notifier);
    final session = container.read(homeControllerProvider);
    final source = container.read(attendanceDataSourceOverrideProvider)!;
    await controller.performAttendance(
      userId: AttendanceTestHost.userId,
      requestAuthCode: () async => '1234',
      canContinue: () => true,
    );
    await controller.fetchLecture();
    expect(host.realTransport.requests, isEmpty);
    expect(host.realHistory.writes, 0);
    expect(
      container.read(attendanceHistoryRepositoryProvider),
      same(source.historyRepository),
    );
    await container.read(attendanceTestControllerProvider.notifier).disable();
    expect(container.read(attendanceDataSourceOverrideProvider), isNull);
    expect(container.read(attendanceProvider.notifier), same(controller));
    expect(container.read(homeControllerProvider), same(session));
    expect(container.read(attendanceProvider).currentLecture?.name, '실제 수업');
    expect(
      container.read(attendanceHistoryRepositoryProvider),
      same(host.realHistory),
    );
    expect(await host.realHistory.load(AttendanceTestHost.userId), isEmpty);
    expect(
      await source.historyRepository.load(AttendanceTestHost.userId),
      hasLength(1),
    );
    expect(host.realTransport.lectureRequests, 1);
  });

  for (final switchAccount in [false, true]) {
    test('로그아웃·계정 전환은 테스트 소스를 해제한다: $switchAccount', () async {
      final host = await environment();
      final home =
          host.container.read(homeControllerProvider.notifier)
              as TestHomeController;
      if (switchAccount) {
        home.switchAccount();
      } else {
        await home.logout();
      }
      expect(host.container.read(attendanceDataSourceOverrideProvider), isNull);
      expect(host.container.read(attendanceTestControllerProvider), isNull);
      expect(host.realTransport.requests, isEmpty);
      expect(host.realHistory.writes, 0);
    });
  }

  test('학교 출결 내역도 테스트 소스로 조회하고 끄면 캐시를 비운다', () async {
    final host = await environment();
    final subscription = host.container.listen(
      attendanceOverviewProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);
    await host.container
        .read(attendanceOverviewProvider.notifier)
        .loadCourses();
    expect(subscription.read().courses.requireValue.single.name, '모바일 앱 프로그래밍');
    expect(host.realTransport.requests, isEmpty);
    await host.container
        .read(attendanceTestControllerProvider.notifier)
        .disable();
    await host.container
        .read(attendanceOverviewProvider.notifier)
        .loadCourses();
    expect(
      host.realTransport.requests.any(
        (target) => target.endsWith('stud04.jsp'),
      ),
      isTrue,
    );
  });

  test('제출 중에는 테스트 종료나 시나리오 변경으로 실제 소스를 섞지 않는다', () async {
    final host = await environment();
    final controller = host.container.read(attendanceProvider.notifier);
    final code = Completer<String?>();
    final request = controller.performAttendance(
      userId: AttendanceTestHost.userId,
      requestAuthCode: () => code.future,
      canContinue: () => true,
    );
    final test = host.container.read(attendanceTestControllerProvider.notifier);
    await test.disable();
    await test.changeScenario(AttendanceTestScenario.empty);
    expect(
      host.container.read(attendanceTestControllerProvider),
      AttendanceTestScenario.normal,
    );
    code.complete('1234');
    await request;
    await controller.fetchLecture();
    expect(host.transport.submissions, hasLength(1));
    expect(host.realTransport.requests, isEmpty);
    expect(host.realHistory.writes, 0);
  });

  test('테스트 제출 응답이 로그아웃 뒤 도착해도 실제 기록 저장소를 사용하지 않는다', () async {
    final host = AttendanceTestHost(latency: const Duration(milliseconds: 20));
    addTearDown(host.dispose);
    await host.enable();
    final source = host.container.read(attendanceDataSourceOverrideProvider)!;
    final submitting = Completer<void>();
    final subscription = host.container.listen(attendanceProvider, (_, next) {
      if (next.phase == AttendancePhase.submitting && !submitting.isCompleted) {
        submitting.complete();
      }
    });
    addTearDown(subscription.close);
    final request = host.container
        .read(attendanceProvider.notifier)
        .performAttendance(
          userId: AttendanceTestHost.userId,
          requestAuthCode: () async => '1234',
          canContinue: () => true,
        );
    await submitting.future;
    await host.container.read(homeControllerProvider.notifier).logout();
    expect(await request, isNull);
    expect(host.container.read(attendanceDataSourceOverrideProvider), isNull);
    expect(host.realTransport.requests, isEmpty);
    expect(host.realHistory.writes, 0);
    final records = await source.historyRepository.load(
      AttendanceTestHost.userId,
    );
    expect(records, hasLength(1));
    expect(records.single.hasKnownResult, isTrue);
  });
}
