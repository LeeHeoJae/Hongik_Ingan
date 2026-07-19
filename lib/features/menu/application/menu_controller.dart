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

  /// 현재 [menu]에서 실제로 선택 가능한 식당 이름을 반환.
  ///
  /// [preferredName]가 존재한다면 [preferredName]을 반환하고,
  /// 존재하지 않는다면 유요한 식당을 반환한다.
  static String? _resolveCafeteriaName(DailyMenu? menu, String? preferredName) {
    if (menu == null || menu.cafeterias.isEmpty) {
      return null;
    }
    if (preferredName != null &&
        menu.cafeterias.any((cafeteria) => cafeteria.name == preferredName)) {
      return preferredName;
    }
    return _defaultCafeteria(menu)?.name;
  }
}

@Riverpod(keepAlive: true)
class MenuController extends _$MenuController {
  late MenuService _menuService;

  Future<void>? _inflightFetch;

  @override
  MenuState build() {
    _menuService = ref.watch(menuServiceProvider);
    final today = MenuDateRange.dateOnly(DateTime.now());
    return MenuState(
      baseDate: today,
      selectedDate: MenuDateRange.initialSelectedDateFor(today),
      dates: MenuDateRange.displayWeekdaysFor(today),
    );
  }

  /// [baseDate] 기준으로 주간 메뉴를 불러옴.
  ///
  /// 같은 기준일의 메뉴가 이미 있다면 다시 요청하지 않는다.
  /// 중복 네트워크 요청을 방지한다.
  /// [forceRefresh]가 참이면 기존 메뉴가 있어도 새로 조회한다.
  Future<void> fetchMenus({DateTime? baseDate, bool forceRefresh = false}) {
    if (_inflightFetch != null && !forceRefresh) {
      return _inflightFetch!;
    }
    final request = _performFetch(
      baseDate: baseDate,
      forceRefresh: forceRefresh,
    );
    _inflightFetch = request;

    return request.whenComplete(() {
      if (identical(_inflightFetch, request)) {
        _inflightFetch = null;
      }
    });
  }

  /// 주간 메뉴 조회를 실제로 수행하고 화면 상태를 갱신.
  Future<void> _performFetch({
    DateTime? baseDate,
    bool forceRefresh = false,
  }) async {
    final base = MenuDateRange.dateOnly(baseDate ?? DateTime.now());
    final dates = MenuDateRange.displayWeekdaysFor(base);
    if (!forceRefresh && !_baseDateHasChanged(base) && state.menus.isNotEmpty) {
      return;
    }

    final selectedDate =
        dates.any((date) => MenuDateRange.isSameDate(date, state.selectedDate))
        ? state.selectedDate
        : MenuDateRange.initialSelectedDateFor(base);

    state = state.copyWith(
      baseDate: base,
      selectedDate: selectedDate,
      dates: dates,
      isLoading: true,
      error: null,
    );

    final preferredCafeteriaName = state.selectedCafeteriaName;
    final menus = await _menuService.fetchMenus(baseDate: base);

    final hasReadableDay = menus.any(
      (menu) =>
          menu.status == MenuDayStatus.loaded ||
          menu.status == MenuDayStatus.noMenu,
    );
    state = state.copyWith(
      isLoading: false,
      menus: menus,
      selectedCafeteriaName: MenuState._resolveCafeteriaName(
        _findMenuByDate(menus, selectedDate),
        preferredCafeteriaName,
      ),
      error: hasReadableDay ? null : '식당 메뉴를 불러오지 못했습니다.',
    );
  }

  void selectDate(DateTime date) {
    final selectedDate = MenuDateRange.dateOnly(date);
    state = state.copyWith(
      selectedDate: selectedDate,
      selectedCafeteriaName: MenuState._defaultCafeteria(
        _findMenuByDate(state.menus, selectedDate),
      )?.name,
    );
  }

  void selectCafeteria(String name) {
    state = state.copyWith(selectedCafeteriaName: name);
  }

  Future<void> refresh() {
    return fetchMenus(baseDate: state.baseDate, forceRefresh: true);
  }

  bool _baseDateHasChanged(DateTime baseDate) {
    return !MenuDateRange.isSameDate(baseDate, state.baseDate);
  }

  /// [menus] 중에서 [date]에 해당하는 날짜의 [DailyMenu]를 반환.
  DailyMenu? _findMenuByDate(List<DailyMenu> menus, DateTime date) {
    for (final menu in menus) {
      if (MenuDateRange.isSameDate(menu.date, date)) {
        return menu;
      }
    }
    return null;
  }
}
