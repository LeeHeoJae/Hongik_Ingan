import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hongik_ingan/features/attendance/application/attendance_controller.dart';
import 'package:hongik_ingan/features/home/application/home_controller.dart';
import 'package:hongik_ingan/features/cafeteria_menu/application/cafeteria_menu_controller.dart';
import 'package:hongik_ingan/features/cafeteria_menu/data/meal_choice_service.dart';
import 'package:hongik_ingan/core/time/campus_clock.dart';
import 'package:hongik_ingan/features/seat/application/seat_controller.dart';
import 'package:hongik_ingan/features/seat/domain/seat.dart';
import 'layouts/home_service_workspace.dart';
import 'widgets/home_campus_summary.dart';

final _summaryPollProvider = StreamProvider.autoDispose
    .family<LunchPoll?, String>((ref, date) {
      final service = ref.watch(mealChoiceServiceProvider);
      final controller = StreamController<LunchPoll?>();
      final subscription = service.updates.listen((update) {
        if (update.date == date && !controller.isClosed) {
          controller.add(update.poll);
        }
      });
      var active = true;
      Future<void> refresh() async {
        if (service.choicePending(date)) return;
        final revision = service.revision(date);
        try {
          final poll = await service.fetch(date);
          if (active &&
              !service.choicePending(date) &&
              service.revision(date) == revision) {
            service.publish(date, poll);
          }
        } catch (_) {
          if (active &&
              !service.choicePending(date) &&
              service.revision(date) == revision) {
            service.publish(date, null);
          }
        }
      }

      controller.add(service.published(date));
      unawaited(refresh());
      final timer = Timer.periodic(
        const Duration(seconds: 60),
        (_) => unawaited(refresh()),
      );
      ref.onDispose(() {
        active = false;
        timer.cancel();
        subscription.cancel();
        controller.close();
      });
      return controller.stream;
    });

final homeServiceSummaryProvider = Provider.autoDispose
    .family<HomeServiceSummaryData, HomeService>((summaryRef, service) {
      switch (service) {
        case HomeService.attendance:
          final home = summaryRef.watch(
            homeControllerProvider.select(
              (state) => (
                isLoggedIn: state.isLoggedIn,
                isLoading: state.isLoading,
                statusMessage: state.statusMessage,
                recoveryPhase: state.recoveryPhase,
              ),
            ),
          );
          if (!home.isLoggedIn) {
            return HomeServiceSummaryData(
              status: home.isLoading ? '로그인 확인 중' : '로그인 필요',
              secondary: home.isLoading
                  ? home.statusMessage
                  : '출결을 이용하려면 로그인해 주세요.',
            );
          }
          final attendance = summaryRef.watch(
            attendanceProvider.select(
              (state) => (
                phase: state.phase,
                error: state.error,
                currentLecture: state.currentLecture,
                hasCheckedLecture: state.hasCheckedLecture,
                isRetryingFailedLecture: state.isRetryingFailedLecture,
                submissionResult: state.submissionResult,
                isLectureStale: state.isLectureStale,
                sessionExpired: state.sessionExpired,
              ),
            ),
          );
          final result = attendance.submissionResult;
          if (result != null) {
            return HomeServiceSummaryData(
              status: result.isUnconfirmed ? '출결 처리 여부 확인 불가' : '출결 안내',
              secondary: result.message,
              facts: const [(label: '다음 동작', value: '수업 다시 확인')],
            );
          }
          if (home.recoveryPhase.message case final message?) {
            return HomeServiceSummaryData(
              status: message,
              secondary: attendance.currentLecture != null ? '이전 조회 정보' : null,
            );
          }
          if (attendance.isLectureStale && !attendance.sessionExpired) {
            return HomeServiceSummaryData(
              status: attendance.error == null ? '수업 정보 확인 중' : '학교 연결 지연',
              secondary:
                  attendance.error ??
                  (attendance.currentLecture != null
                      ? '이전 조회 정보'
                      : '현재 수업을 확인하고 있어요.'),
              facts: const [(label: '다음 동작', value: '수업 새로고침')],
            );
          }
          if (attendance.phase == AttendancePhase.fetchingLecture &&
              (!attendance.hasCheckedLecture ||
                  attendance.isRetryingFailedLecture)) {
            return const HomeServiceSummaryData(
              status: '수업 조회 중',
              secondary: '현재 수업을 확인하고 있어요.',
            );
          }
          if (attendance.error != null || attendance.sessionExpired) {
            return HomeServiceSummaryData(
              status: '수업 조회 실패',
              secondary: attendance.error ?? '출결 서버 세션이 만료됐어요.',
              facts: const [(label: '다음 동작', value: '다시 시도')],
            );
          }
          if (attendance.phase != AttendancePhase.idle &&
              attendance.phase != AttendancePhase.fetchingLecture) {
            final progress = switch (attendance.phase) {
              AttendancePhase.enteringCode => '번호 입력 중',
              AttendancePhase.locating => '위치 확인 중',
              AttendancePhase.submitting => '출석 제출 중',
              _ => '출결 진행 중',
            };
            return HomeServiceSummaryData(
              status: progress,
              secondary: attendance.currentLecture?.name,
            );
          }
          final lecture = attendance.currentLecture;
          if (lecture != null) {
            final refreshing =
                attendance.phase == AttendancePhase.fetchingLecture;
            final parameterNames = lecture.attendanceParams.keys.toList()
              ..sort();
            return HomeServiceSummaryData(
              eyebrow: refreshing ? '수업 확인 중' : '출결 가능',
              attentionKey: refreshing
                  ? null
                  : jsonEncode([
                      lecture.name,
                      lecture.time,
                      for (final name in parameterNames)
                        [name, lecture.attendanceParams[name]],
                    ]),
              status: lecture.name,
              secondary: lecture.time,
              facts: const [(label: '다음 동작', value: '출결 번호 입력')],
            );
          }
          return HomeServiceSummaryData(
            status: attendance.hasCheckedLecture ? '출결 가능한 수업 없음' : '수업 확인 전',
            secondary: attendance.hasCheckedLecture
                ? '새로고침으로 다시 확인할 수 있어요.'
                : '조회된 수업 정보가 아직 없어요.',
          );
        case HomeService.seat:
          const location = SeatLocation.tBuilding;
          final seat = summaryRef.watch(
            seatControllerProvider.select(
              (state) => (
                status: state.statuses[location],
                error: state.errors[location],
                loading: state.loadingLocations.contains(location),
              ),
            ),
          );
          return HomeCampusSummary.seats(
            status: seat.status,
            error: seat.error,
            loading: seat.loading,
          );
        case HomeService.menu:
          final menu = summaryRef.watch(
            cafeteriaMenuControllerProvider.select(
              (state) => (menus: state.menus, isLoading: state.isLoading),
            ),
          );
          final now = summaryRef.watch(homeCampusTimeProvider);
          final summary = HomeCampusSummary.menu(
            menu.menus,
            now,
            isLoading: menu.isLoading,
          );
          if (!summary.hasMenuChoices) return summary;
          final poll = summaryRef
              .watch(_summaryPollProvider(campusDateKey(now)))
              .value;
          return HomeCampusSummary.menu(
            menu.menus,
            now,
            isLoading: menu.isLoading,
            poll: poll,
          );
      }
    });
