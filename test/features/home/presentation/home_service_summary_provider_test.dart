import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/features/attendance/application/attendance_controller.dart';
import 'package:hongik_ingan/features/attendance/domain/attendance_submission_result.dart';
import 'package:hongik_ingan/features/attendance/domain/lecture.dart';
import 'package:hongik_ingan/features/home/application/home_controller.dart';
import 'package:hongik_ingan/features/home/presentation/home_service_summary_provider.dart';
import 'package:hongik_ingan/features/home/presentation/layouts/home_service_workspace.dart';
import 'package:hongik_ingan/features/seat/application/seat_controller.dart';
import 'package:hongik_ingan/features/seat/domain/seat.dart';

void main() {
  final lecture = Lecture(
    name: 'Synthetic lecture',
    time: '10:00',
    attendanceParams: const {'course': 'synthetic'},
  );
  for (final result in [
    const AttendanceSubmissionResult.unconfirmed('Check school records'),
    const AttendanceSubmissionResult.sessionExpired('Session expired'),
    const AttendanceSubmissionResult.ssoIntegrationError('SSO failed'),
    const AttendanceSubmissionResult.notice('Server notice'),
  ]) {
    test('summary preserves ${result.status.name} through lecture refresh', () {
      final home = _Home();
      final attendance = _Attendance();
      final container = ProviderContainer(
        overrides: [
          homeControllerProvider.overrideWith(() => home),
          attendanceProvider.overrideWith(() => attendance),
        ],
      );
      addTearDown(container.dispose);
      final provider = homeServiceSummaryProvider(HomeService.attendance);
      container.listen(provider, (_, _) {});
      home.change(const HomeState(isLoggedIn: true, userId: 'SYNTHETIC'));
      container.read(provider);
      for (final phase in [
        AttendancePhase.fetchingLecture,
        AttendancePhase.idle,
      ]) {
        attendance.change(
          AttendanceState(
            currentLecture: lecture,
            phase: phase,
            hasCheckedLecture: true,
            submissionResult: result,
          ),
        );
        final summary = container.read(provider);
        expect(
          summary.status,
          result.isUnconfirmed ? '출결 처리 여부 확인 불가' : '출결 안내',
        );
        expect(summary.secondary, result.message);
        expect(summary.facts, contains((label: '다음 동작', value: '수업 다시 확인')));
        expect(summary.attentionKey, isNull);
      }
      attendance.finishAttendanceFlow(attendance.submissionRevision);
      final restored = container.read(provider);
      expect(restored.status, lecture.name);
      expect(restored.facts, contains((label: '다음 동작', value: '출결 번호 입력')));
      expect(restored.attentionKey, isNotNull);
    });
  }

  test(
    'stale and expired lectures cannot advertise entry; recovery restores it',
    () {
      final home = _Home();
      final attendance = _Attendance();
      final container = ProviderContainer(
        overrides: [
          homeControllerProvider.overrideWith(() => home),
          attendanceProvider.overrideWith(() => attendance),
        ],
      );
      addTearDown(container.dispose);
      final provider = homeServiceSummaryProvider(HomeService.attendance);
      container.listen(provider, (_, _) {});
      home.change(const HomeState(isLoggedIn: true, userId: 'SYNTHETIC'));
      container.read(provider);
      for (final state in [
        AttendanceState(currentLecture: lecture, isLectureStale: true),
        AttendanceState(
          currentLecture: lecture,
          isLectureStale: true,
          error: 'Delayed',
        ),
        AttendanceState(
          currentLecture: lecture,
          sessionExpired: true,
          error: 'Expired',
        ),
      ]) {
        attendance.change(state);
        final summary = container.read(provider);
        expect(
          summary.facts,
          isNot(contains((label: '다음 동작', value: '출결 번호 입력'))),
        );
        expect(summary.attentionKey, isNull);
      }
      attendance.change(
        AttendanceState(currentLecture: lecture, hasCheckedLecture: true),
      );
      final summary = container.read(provider);
      expect(summary.facts, contains((label: '다음 동작', value: '출결 번호 입력')));
      expect(summary.attentionKey, isNotNull);
    },
  );

  test('seat selection and other buildings do not notify the home summary', () {
    final seats = _Seats();
    final container = ProviderContainer(
      overrides: [seatControllerProvider.overrideWith(() => seats)],
    );
    addTearDown(container.dispose);
    var changes = 0;
    final provider = homeServiceSummaryProvider(HomeService.seat);
    container.listen(provider, (_, _) => changes++, fireImmediately: true);
    expect(container.read(provider).status, '좌석 조회 전');
    seats.change(
      SeatState(
        selectedLocation: SeatLocation.values.last,
        loadingLocations: {SeatLocation.values.last},
      ),
    );
    expect(container.read(provider).status, '좌석 조회 전');
    expect(changes, 1);
    seats.change(SeatState(loadingLocations: {SeatLocation.tBuilding}));
    expect(container.read(provider).status, '좌석 확인 중');
    expect(changes, 2);
  });

  test(
    'login preferences do not notify attendance summary, login progress does',
    () {
      final home = _Home();
      final container = ProviderContainer(
        overrides: [homeControllerProvider.overrideWith(() => home)],
      );
      addTearDown(container.dispose);
      var changes = 0;
      final provider = homeServiceSummaryProvider(HomeService.attendance);
      container.listen(provider, (_, _) => changes++, fireImmediately: true);
      expect(container.read(provider).status, '로그인 필요');
      home.change(const HomeState(rememberMe: true, autoLogin: true));
      expect(container.read(provider).status, '로그인 필요');
      expect(changes, 1);
      home.change(const HomeState(isLoading: true, statusMessage: 'Checking'));
      expect(container.read(provider).secondary, 'Checking');
      expect(changes, 2);
    },
  );

  test('equivalent visible summaries compare by value including facts', () {
    final first = HomeServiceSummaryData(
      status: 'Ready',
      facts: List.of(const [(label: 'Next', value: 'Refresh')]),
    );
    final second = HomeServiceSummaryData(
      status: 'Ready',
      facts: List.of(const [(label: 'Next', value: 'Refresh')]),
    );
    expect(first, second);
    expect(first.hashCode, second.hashCode);
    expect(first, isNot(const HomeServiceSummaryData(status: 'Changed')));
  });
}

class _Seats extends SeatController {
  @override
  SeatState build() => SeatState();
  void change(SeatState value) => state = value;
}

class _Home extends HomeController {
  @override
  HomeState build() => const HomeState();
  void change(HomeState value) => state = value;
}

class _Attendance extends AttendanceController {
  @override
  AttendanceState build() => const AttendanceState();
  void change(AttendanceState value) => state = value;
}
