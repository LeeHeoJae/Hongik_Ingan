import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hongik_ingan/features/attendance/application/attendance_controller.dart';
import 'package:hongik_ingan/features/home/application/home_controller.dart';
import 'package:hongik_ingan/features/cafeteria_menu/application/cafeteria_menu_controller.dart';
import 'package:hongik_ingan/features/seat/application/seat_controller.dart';
import 'package:hongik_ingan/features/seat/domain/seat.dart';
import 'layouts/home_service_workspace.dart';
import 'widgets/home_campus_summary.dart';

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
              ),
            ),
          );
          if (attendance.phase == AttendancePhase.fetchingLecture) {
            return const HomeServiceSummaryData(
              status: '수업 조회 중',
              secondary: '현재 수업을 확인하고 있어요.',
            );
          }
          if (attendance.error != null) {
            return HomeServiceSummaryData(
              status: '수업 조회 실패',
              secondary: attendance.error,
              facts: const [(label: '다음 동작', value: '다시 시도')],
            );
          }
          if (attendance.phase != AttendancePhase.idle) {
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
            final parameterNames = lecture.attendanceParams.keys.toList()
              ..sort();
            return HomeServiceSummaryData(
              eyebrow: '출결 가능',
              attentionKey: jsonEncode([
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
            SeatState(
              statuses: {if (seat.status != null) location: seat.status!},
              errors: {if (seat.error != null) location: seat.error!},
              loadingLocations: {if (seat.loading) location},
            ),
          );
        case HomeService.menu:
          final menu = summaryRef.watch(
            cafeteriaMenuControllerProvider.select(
              (state) => (menus: state.menus, isLoading: state.isLoading),
            ),
          );
          final now = summaryRef.watch(homeCampusTimeProvider);
          return HomeCampusSummary.menu(
            CafeteriaMenuState(
              baseDate: now,
              selectedDate: now,
              dates: const [],
              menus: menu.menus,
              isLoading: menu.isLoading,
            ),
            now,
          );
      }
    });
