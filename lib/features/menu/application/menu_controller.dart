import 'package:hongik_ingan/core/network/school_request_options.dart';
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
    this.fetchedAt,
    this.cacheDay,
  });

  final DateTime baseDate;
  final DateTime selectedDate;
  final List<DateTime> dates;
  final bool isLoading;
  final List<DailyMenu> menus;
  final String? selectedCafeteriaName;
  final String? error;
  final DateTime? fetchedAt;
  final String? cacheDay;

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
    Object? fetchedAt = _unset,
    Object? cacheDay = _unset,
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
      fetchedAt: identical(fetchedAt, _unset)
          ? this.fetchedAt
          : fetchedAt as DateTime?,
      cacheDay: identical(cacheDay, _unset)
          ? this.cacheDay
          : cacheDay as String?,
    );
  }

  static CafeteriaMenu? _defaultCafeteria(DailyMenu? menu) {
    if (menu == null || menu.cafeterias.isEmpty) {
      return null;
    }
    for (final cafeteria in menu.cafeterias) {
      if (cafeteria.isDormitory) {
        return cafeteria;
      }
    }
    return menu.cafeterias.first;
  }

  /// 현재 [menu]에서 실제로 선택 가능한 식당 이름을 반환.
  ///
  /// [preferredName]가 존재한다면 [preferredName]을 반환하고,
  /// 존재하지 않는다면 유효한 식당을 반환한다.
  /// 식당 정보가 없는 날에는 다음 날짜에서도 선호 식당을 유지할 수 있도록
  /// [preferredName]을 그대로 보존한다.
  static String? _resolveCafeteriaName(DailyMenu? menu, String? preferredName) {
    if (menu == null || menu.cafeterias.isEmpty) {
      return preferredName;
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
    final cacheDay = currentKstCacheDay();
    if (!forceRefresh &&
        !_baseDateHasChanged(base) &&
        state.menus.isNotEmpty &&
        state.cacheDay == cacheDay) {
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
    final previousMenus = state.menus;
    final previousCacheDay = state.cacheDay;
    final menus = await _menuService.fetchMenus(
      baseDate: base,
      cacheMode: forceRefresh
          ? NetworkCacheMode.revalidate
          : NetworkCacheMode.preferCache,
    );

    final hasReadableDay = menus.any(
      (menu) =>
          menu.status == MenuDayStatus.loaded ||
          menu.status == MenuDayStatus.noMenu,
    );
    final hasReadablePreviousDay = previousMenus.any(
      (menu) =>
          menu.status == MenuDayStatus.loaded ||
          menu.status == MenuDayStatus.noMenu,
    );
    final keepPreviousMenus =
        !hasReadableDay &&
        hasReadablePreviousDay &&
        previousCacheDay == cacheDay;
    final effectiveMenus = keepPreviousMenus ? previousMenus : menus;
    state = state.copyWith(
      isLoading: false,
      menus: effectiveMenus,
      selectedCafeteriaName: MenuState._resolveCafeteriaName(
        _findMenuByDate(effectiveMenus, selectedDate),
        preferredCafeteriaName,
      ),
      error: hasReadableDay ? null : '식당 메뉴를 불러오지 못했습니다.',
      fetchedAt: hasReadableDay ? DateTime.now() : state.fetchedAt,
      cacheDay: hasReadableDay ? cacheDay : state.cacheDay,
    );
  }

  void selectDate(DateTime date) {
    final selectedDate = MenuDateRange.dateOnly(date);
    final menu = _findMenuByDate(state.menus, selectedDate);
    state = state.copyWith(
      selectedDate: selectedDate,
      selectedCafeteriaName: MenuState._resolveCafeteriaName(
        menu,
        state.selectedCafeteriaName,
      ),
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
