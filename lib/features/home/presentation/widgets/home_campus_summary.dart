import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hongik_ingan/core/time/campus_clock.dart';
import 'package:hongik_ingan/features/cafeteria_menu/domain/cafeteria_menu.dart';
import 'package:hongik_ingan/features/cafeteria_menu/presentation/cafeteria_menu_display_formatter.dart';
import 'package:hongik_ingan/features/seat/domain/seat.dart';

import '../layouts/home_service_workspace.dart';

// Use the campus time zone even when the browser is in another time zone.
final homeCampusTimeProvider = Provider.autoDispose<DateTime>((ref) {
  final now = ref.watch(campusClockProvider)();
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

  static HomeServiceSummaryData menu(
    List<DailyMenu> menus,
    DateTime now, {
    required bool isLoading,
  }) {
    if (now.weekday >= DateTime.saturday) {
      return const HomeServiceSummaryData(status: '오늘은 등록된 메뉴가 없어요');
    }
    final date = MenuDateRange.dateOnly(now);
    DailyMenu? day;
    for (final candidate in menus) {
      if (MenuDateRange.isSameDate(candidate.date, date)) {
        day = candidate;
        break;
      }
    }
    if (day == null) {
      return HomeServiceSummaryData(status: isLoading ? '메뉴 확인 중' : '메뉴 조회 전');
    }
    if (day.status == MenuDayStatus.networkError ||
        day.status == MenuDayStatus.parseFailed) {
      return HomeServiceSummaryData(status: '메뉴 조회 실패', secondary: day.message);
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
      return HomeServiceSummaryData(status: day.message ?? '등록된 메뉴가 없어요');
    }
    meals.sort((a, b) => _endMinute(a).compareTo(_endMinute(b)));
    final minute = now.hour * 60 + now.minute;
    MealType? type;
    for (final meal in meals) {
      if (minute < _endMinute(meal)) {
        type = meal.type;
        break;
      }
    }
    if (type == null) {
      return const HomeServiceSummaryData(status: '오늘 식사 종료');
    }
    final currentMeals = meals.where((meal) => meal.type == type).toList();
    final showChoices = type == MealType.lunch && currentMeals.length > 1;
    return HomeServiceSummaryData(
      eyebrow: type.label,
      status: [
        for (var index = 0; index < currentMeals.length; index++)
          if (showChoices)
            '${String.fromCharCode(65 + index)}안 · ${_mealSummary(currentMeals[index], limit: 3)}'
          else
            _mealSummary(
              currentMeals[index],
              limit: type == MealType.lunch ? null : 3,
            ),
      ].join('\n'),
    );
  }

  static final _plainRice = RegExp(r'^(백미|쌀|흰쌀|흰|잡곡|혼합잡곡|현미|보리|흑미)?밥$');
  static final _whitespace = RegExp(r'\s+');
  static const _plainKimchi = {
    '김치',
    '배추김치',
    '포기김치',
    '총각김치',
    '알타리김치',
    '열무김치',
    '열무물김치',
    '갓김치',
    '백김치',
    '나박김치',
    '얼갈이김치',
    '파김치',
    '오이김치',
    '볶음김치',
    '깍두기',
    '석박지',
    '섞박지',
    '동치미',
    '오이소박이',
  };

  static String _mealSummary(MealMenu meal, {int? limit}) {
    final items = meal.items.where((item) {
      final name = item.replaceAll(_whitespace, '');
      return !_plainRice.hasMatch(name) && !_plainKimchi.contains(name);
    }).toList();
    if (items.isEmpty) return '밥·김치만 등록되어 있어요';
    final visible = (limit == null ? items : items.take(limit)).join(' · ');
    final hiddenCount = limit == null ? 0 : items.length - limit;
    return hiddenCount > 0 ? '$visible · 외 $hiddenCount개' : visible;
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

  static HomeServiceSummaryData seats({
    required SeatStatus? status,
    required String? error,
    required bool loading,
  }) {
    const label = 'T동 노트북 열람실';
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
      availableSeats: available,
      secondary: loading && error == null ? '좌석 갱신 중' : null,
      warning: error != null ? '갱신 실패 · 이전 정보' : null,
      compactWarning: error != null ? '이전 정보' : null,
      facts: [
        for (final room in rooms)
          (label: room.name, value: '${room.availableSeats}석'),
      ],
    );
  }
}
