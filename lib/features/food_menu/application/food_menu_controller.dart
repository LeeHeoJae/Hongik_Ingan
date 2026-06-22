import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:hongik_ingan/features/food_menu/data/food_menu_service.dart';
import 'package:hongik_ingan/features/food_menu/domain/food_menu.dart';

part 'food_menu_controller.g.dart';

const Object _unset = Object();

class FoodMenuState {
  const FoodMenuState({
    required this.baseDate,
    required this.selectedDate,
    required this.dates,
    this.isLoading = false,
    this.menus = const [],
    this.selectedCafeteriaName,
    this.error,
  });

  final DateTime baseDate;
  final DateTime selectedDate;
  final List<DateTime> dates;
  final bool isLoading;
  final List<DailyFoodMenu> menus;
  final String? selectedCafeteriaName;
  final String? error;

  DailyFoodMenu? get selectedMenu {
    for (final menu in menus) {
      if (FoodMenuDateRange.isSameDate(menu.date, selectedDate)) {
        return menu;
      }
    }
    return null;
  }

  CafeteriaMenu? get selectedCafeteria {
    final menu = selectedMenu;
    if (menu == null || menu.cafeterias.isEmpty) {
      return null;
    }
    for (final cafeteria in menu.cafeterias) {
      if (cafeteria.name == selectedCafeteriaName) {
        return cafeteria;
      }
    }
    return _defaultCafeteria(menu) ?? menu.cafeterias.first;
  }

  FoodMenuState copyWith({
    DateTime? baseDate,
    DateTime? selectedDate,
    List<DateTime>? dates,
    bool? isLoading,
    List<DailyFoodMenu>? menus,
    Object? selectedCafeteriaName = _unset,
    Object? error = _unset,
  }) {
    return FoodMenuState(
      baseDate: baseDate ?? this.baseDate,
      selectedDate: selectedDate ?? this.selectedDate,
      dates: dates ?? this.dates,
      isLoading: isLoading ?? this.isLoading,
      menus: menus ?? this.menus,
      selectedCafeteriaName: identical(selectedCafeteriaName, _unset)
          ? this.selectedCafeteriaName
          : selectedCafeteriaName as String?,
      error: identical(error, _unset) ? this.error : error as String?,
    );
  }

  static CafeteriaMenu? _defaultCafeteria(DailyFoodMenu? menu) {
    if (menu == null || menu.cafeterias.isEmpty) {
      return null;
    }
    for (final cafeteria in menu.cafeterias) {
      if (cafeteria.name.contains('학생')) {
        return cafeteria;
      }
    }
    return menu.cafeterias.first;
  }
}

@Riverpod(keepAlive: true)
class FoodMenuController extends _$FoodMenuController {
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

  Future<void> fetchMenus({
    DateTime? baseDate,
    bool forceRefresh = false,
  }) async {
    final base = FoodMenuDateRange.dateOnly(baseDate ?? DateTime.now());
    final dates = FoodMenuDateRange.around(base);
    if (!forceRefresh && !baseDateHasChanged(base) && state.menus.isNotEmpty) {
      return;
    }

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
      selectedCafeteriaName: FoodMenuState._defaultCafeteria(
        _menuForDate(menus, selectedDate),
      )?.name,
      error: hasReadableDay ? null : '식당 메뉴를 불러오지 못했습니다.',
    );
  }

  void selectDate(DateTime date) {
    final selectedDate = FoodMenuDateRange.dateOnly(date);
    state = state.copyWith(
      selectedDate: selectedDate,
      selectedCafeteriaName: FoodMenuState._defaultCafeteria(
        _menuForDate(state.menus, selectedDate),
      )?.name,
    );
  }

  void selectCafeteria(String name) {
    state = state.copyWith(selectedCafeteriaName: name);
  }

  Future<void> refresh() {
    return fetchMenus(baseDate: state.baseDate, forceRefresh: true);
  }

  bool baseDateHasChanged(DateTime baseDate) {
    return !FoodMenuDateRange.isSameDate(baseDate, state.baseDate);
  }

  DailyFoodMenu? _menuForDate(List<DailyFoodMenu> menus, DateTime date) {
    for (final menu in menus) {
      if (FoodMenuDateRange.isSameDate(menu.date, date)) {
        return menu;
      }
    }
    return null;
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
