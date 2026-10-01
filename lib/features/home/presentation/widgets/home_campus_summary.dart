import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hongik_ingan/features/cafeteria_menu/application/cafeteria_menu_controller.dart';
import 'package:hongik_ingan/features/cafeteria_menu/domain/cafeteria_menu.dart';
import 'package:hongik_ingan/features/cafeteria_menu/presentation/cafeteria_menu_display_formatter.dart';
import 'package:hongik_ingan/features/seat/application/seat_controller.dart';
import 'package:hongik_ingan/features/seat/domain/seat.dart';

import '../layouts/home_service_workspace.dart';

// Use the campus time zone even when the browser is in another time zone.
final homeCampusTimeProvider = Provider.autoDispose<DateTime>((ref) {
  final now = DateTime.now().toUtc().add(const Duration(hours: 9));
  final untilNextMinute =
      const Duration(minutes: 1) -
      Duration(
        seconds: now.second,
        milliseconds: now.millisecond,
        microseconds: now.microsecond,
      );
  final timer = Timer(untilNextMinute, ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return now;
});

final class HomeCampusSummary {
  const HomeCampusSummary._();

  static HomeServiceSummaryData menu(CafeteriaMenuState state, DateTime now) {
    final weekend = now.weekday >= DateTime.saturday;
    final date = MenuDateRange.initialSelectedDateFor(now);
    DailyMenu? day;
    for (final candidate in state.menus) {
      if (MenuDateRange.isSameDate(candidate.date, date)) {
        day = candidate;
        break;
      }
    }
    final dayLabel = weekend ? '다음 월요일' : null;
    if (day == null) {
      return HomeServiceSummaryData(
        eyebrow: dayLabel,
        status: state.isLoading ? '메뉴 확인 중' : '등록된 메뉴가 없어요',
      );
    }
    if (day.status == MenuDayStatus.networkError ||
        day.status == MenuDayStatus.parseFailed) {
      return HomeServiceSummaryData(
        eyebrow: dayLabel,
        status: '메뉴 조회 실패',
        secondary: day.message,
      );
    }
    CafeteriaMenu? cafeteria;
    for (final candidate in day.cafeterias) {
      if (candidate.isDormitory) {
        cafeteria = candidate;
        break;
      }
    }
    final meals =
        cafeteria?.meals.where((meal) => meal.items.isNotEmpty).toList() ??
        <MealMenu>[];
    if (meals.isEmpty) {
      return HomeServiceSummaryData(
        eyebrow: dayLabel,
        status: day.message ?? '등록된 메뉴가 없어요',
      );
    }
    meals.sort((a, b) => _endMinute(a).compareTo(_endMinute(b)));
    final minute = now.hour * 60 + now.minute;
    MealType? type;
    for (final meal in meals) {
      if (weekend || minute < _endMinute(meal)) {
        type = meal.type;
        break;
      }
    }
    if (type == null) {
      return const HomeServiceSummaryData(status: '오늘 식사 종료');
    }
    return HomeServiceSummaryData(
      eyebrow: weekend ? '다음 월요일 · ${type.label}' : type.label,
      status: meals
          .where((meal) => meal.type == type)
          .map((meal) => meal.items.join(' · '))
          .join('\n'),
    );
  }

  static int _endMinute(MealMenu meal) {
    int? parse(String value) {
      final times = RegExp(r'(\d{1,2})[:：](\d{2})').allMatches(value).toList();
      if (times.length < 2) return null;
      final hour = int.parse(times.last.group(1)!);
      final minute = int.parse(times.last.group(2)!);
      if (hour > 23 || minute > 59) return null;
      return hour * 60 + minute;
    }

    return parse(meal.time) ??
        parse(CafeteriaMenuDisplayFormatter.mealTitle(meal.type, ''))!;
  }

  static HomeServiceSummaryData seats(SeatState state) {
    const location = SeatLocation.tBuilding;
    const label = 'T동 노트북 열람실';
    final status = state.statuses[location];
    final error = state.errors[location];
    final loading = state.loadingLocations.contains(location);
    if (status == null) {
      return HomeServiceSummaryData(
        eyebrow: label,
        status: loading
            ? '좌석 확인 중'
            : error != null
            ? '좌석 조회 실패'
            : '좌석 조회 전',
        secondary: error,
      );
    }
    final rooms = status.rooms
        .where((room) => room.name.contains('노트북'))
        .toList();
    if (rooms.isEmpty) {
      return const HomeServiceSummaryData(
        eyebrow: label,
        status: '노트북 좌석 정보 없음',
      );
    }
    final available = rooms.fold<int>(
      0,
      (sum, room) => sum + room.availableSeats,
    );
    return HomeServiceSummaryData(
      eyebrow: label,
      status: '$available석 남음',
      secondary: error != null
          ? '갱신 실패 · 이전 정보'
          : loading
          ? '좌석 갱신 중'
          : null,
      facts: [
        for (final room in rooms)
          (label: room.name, value: '${room.availableSeats}석'),
      ],
    );
  }
}
