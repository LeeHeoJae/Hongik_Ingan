import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/food_menu.dart';
import '../services/food_menu_service.dart';

final foodMenuControllerProvider =
    NotifierProvider.autoDispose<FoodMenuController, FoodMenuState>(
      FoodMenuController.new,
    );

const Object _unset = Object();

class FoodMenuState {
  const FoodMenuState({
    required this.baseDate,
    required this.selectedDate,
    required this.dates,
    this.isLoading = false,
    this.menus = const [],
    this.error,
  });

  final DateTime baseDate;
  final DateTime selectedDate;
  final List<DateTime> dates;
  final bool isLoading;
  final List<DailyFoodMenu> menus;
  final String? error;

  DailyFoodMenu? get selectedMenu {
    for (final menu in menus) {
      if (FoodMenuDateRange.isSameDate(menu.date, selectedDate)) {
        return menu;
      }
    }
    return null;
  }

  FoodMenuState copyWith({
    DateTime? baseDate,
    DateTime? selectedDate,
    List<DateTime>? dates,
    bool? isLoading,
    List<DailyFoodMenu>? menus,
    Object? error = _unset,
  }) {
    return FoodMenuState(
      baseDate: baseDate ?? this.baseDate,
      selectedDate: selectedDate ?? this.selectedDate,
      dates: dates ?? this.dates,
      isLoading: isLoading ?? this.isLoading,
      menus: menus ?? this.menus,
      error: identical(error, _unset) ? this.error : error as String?,
    );
  }
}

class FoodMenuController extends Notifier<FoodMenuState> {
  late final FoodMenuService _service;

  @override
  FoodMenuState build() {
    _service = FoodMenuService();
    final today = FoodMenuDateRange.dateOnly(DateTime.now());
    return FoodMenuState(
      baseDate: today,
      selectedDate: today,
      dates: FoodMenuDateRange.around(today),
    );
  }

  Future<void> fetchMenus({DateTime? baseDate}) async {
    final base = FoodMenuDateRange.dateOnly(baseDate ?? DateTime.now());
    final dates = FoodMenuDateRange.around(base);
    final selectedDate =
        dates.any(
          (date) => FoodMenuDateRange.isSameDate(date, state.selectedDate),
        )
        ? state.selectedDate
        : base;

    state = state.copyWith(
      baseDate: base,
      selectedDate: selectedDate,
      dates: dates,
      isLoading: true,
      error: null,
    );

    final menus = await Future.wait(
      List.generate(dates.length, (index) {
        return _fetchDaySafely(page: index + 1, date: dates[index]);
      }),
    );

    final hasReadableDay = menus.any(
      (menu) =>
          menu.status == FoodMenuDayStatus.loaded ||
          menu.status == FoodMenuDayStatus.noMenu,
    );
    state = state.copyWith(
      isLoading: false,
      menus: menus,
      error: hasReadableDay ? null : '식당 메뉴를 불러오지 못했습니다.',
    );
  }

  void selectDate(DateTime date) {
    state = state.copyWith(selectedDate: FoodMenuDateRange.dateOnly(date));
  }

  Future<void> refresh() {
    return fetchMenus(baseDate: state.baseDate);
  }

  Future<DailyFoodMenu> _fetchDaySafely({
    required int page,
    required DateTime date,
  }) async {
    try {
      return await _service.fetchDayMenu(page: page, date: date);
    } on FoodMenuParseException catch (e) {
      return DailyFoodMenu.failure(
        date: date,
        status: FoodMenuDayStatus.parseFailed,
        message: e.message,
      );
    } on FoodMenuServiceException catch (e) {
      return DailyFoodMenu.failure(
        date: date,
        status: FoodMenuDayStatus.networkError,
        message: e.message,
      );
    }
  }
}
