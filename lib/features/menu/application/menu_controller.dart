import 'package:hongik_ingan/features/menu/data/menu_service.dart';
import 'package:hongik_ingan/features/menu/domain/menu.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'menu_controller.g.dart';

const Object _unset = Object();

class MenuState {
  const MenuState({
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
  final List<DailyMenu> menus;
  final String? selectedCafeteriaName;
  final String? error;

  DailyMenu? get selectedMenu {
    for (final menu in menus) {
      if (MenuDateRange.isSameDate(menu.date, selectedDate)) {
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

  MenuState copyWith({
    DateTime? baseDate,
    DateTime? selectedDate,
    List<DateTime>? dates,
    bool? isLoading,
    List<DailyMenu>? menus,
    Object? selectedCafeteriaName = _unset,
    Object? error = _unset,
  }) {
    return MenuState(
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

  static CafeteriaMenu? _defaultCafeteria(DailyMenu? menu) {
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
class MenuController extends _$MenuController {
  late final MenuService _service;

  @override
  MenuState build() {
    _service = MenuService();
    final today = MenuDateRange.dateOnly(DateTime.now());
    return MenuState(
      baseDate: today,
      selectedDate: today,
      dates: MenuDateRange.around(today),
    );
  }

  Future<void> fetchMenus({
    DateTime? baseDate,
    bool forceRefresh = false,
  }) async {
    final base = MenuDateRange.dateOnly(baseDate ?? DateTime.now());
    final dates = MenuDateRange.around(base);
    if (!forceRefresh && !baseDateHasChanged(base) && state.menus.isNotEmpty) {
      return;
    }

    final selectedDate =
        dates.any((date) => MenuDateRange.isSameDate(date, state.selectedDate))
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
          menu.status == MenuDayStatus.loaded ||
          menu.status == MenuDayStatus.noMenu,
    );
    state = state.copyWith(
      isLoading: false,
      menus: menus,
      selectedCafeteriaName: MenuState._defaultCafeteria(
        _menuForDate(menus, selectedDate),
      )?.name,
      error: hasReadableDay ? null : '식당 메뉴를 불러오지 못했습니다.',
    );
  }

  void selectDate(DateTime date) {
    final selectedDate = MenuDateRange.dateOnly(date);
    state = state.copyWith(
      selectedDate: selectedDate,
      selectedCafeteriaName: MenuState._defaultCafeteria(
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
    return !MenuDateRange.isSameDate(baseDate, state.baseDate);
  }

  DailyMenu? _menuForDate(List<DailyMenu> menus, DateTime date) {
    for (final menu in menus) {
      if (MenuDateRange.isSameDate(menu.date, date)) {
        return menu;
      }
    }
    return null;
  }

  Future<DailyMenu> _fetchDaySafely({
    required int page,
    required DateTime date,
  }) async {
    try {
      return await _service.fetchDayMenu(page: page, date: date);
    } on MenuParseException catch (e) {
      return DailyMenu.failure(
        date: date,
        status: MenuDayStatus.parseFailed,
        message: e.message,
      );
    } on MenuServiceException catch (e) {
      return DailyMenu.failure(
        date: date,
        status: MenuDayStatus.networkError,
        message: e.message,
      );
    }
  }
}
