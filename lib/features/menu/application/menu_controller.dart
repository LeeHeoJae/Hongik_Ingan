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
  final Map<DateTime, Future<void>> _inflightDayFetches = {};

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

  /// [baseDate] 기준으로 주간 메뉴 중 조회하지 않은 메뉴를 불러옴.
  ///
  /// 첫 화면에서 이미 조회한 오늘 메뉴를 유지한 채,
  /// 메뉴를 펼쳤을 때 나머지 날짜를 병렬로 채운다.
  /// 같은 기준일의 메뉴가 이미 있다면 다시 요청하지 않는다.
  /// 중복 네트워크 요청을 방지한다.
  /// [forceRefresh]가 참이면 기존 메뉴가 있어도 새로 조회한다.
  Future<void> fetchMenus({DateTime? baseDate, bool forceRefresh = false}) {
    if (_inflightFetch != null) {
      return _inflightFetch!;
    }
    final base = MenuDateRange.dateOnly(baseDate ?? DateTime.now());
    final cacheDay = currentKstCacheDay();
    final targets = MenuDateRange.displayWeekdaysFor(base)
        .where((date) => forceRefresh || !_hasReadableMenu(date, cacheDay))
        .toList(growable: false);
    if (targets.isEmpty) return Future<void>.value();

    final request = Future.wait(
      targets.map(
        (date) =>
            fetchMenuForDate(date, baseDate: base, forceRefresh: forceRefresh),
      ),
    );
    _inflightFetch = request;

    return request.whenComplete(() {
      if (identical(_inflightFetch, request)) {
        _inflightFetch = null;
      }
      _stopLoadingIfIdle();
    });
  }

  /// 첫 화면에 필요한 오늘의 메뉴만 조회.
  Future<void> fetchInitialMenu({bool forceRefresh = false}) {
    final base = MenuDateRange.dateOnly(DateTime.now());
    return fetchMenuForDate(
      MenuDateRange.initialSelectedDateFor(base),
      baseDate: base,
      forceRefresh: forceRefresh,
    );
  }

  /// [date]의 메뉴를 조회.
  Future<void> fetchMenuForDate(
    DateTime date, {
    DateTime? baseDate,
    bool forceRefresh = false,
  }) {
    final base = MenuDateRange.dateOnly(baseDate ?? DateTime.now());
    final dates = MenuDateRange.displayWeekdaysFor(base);
    final targetDate = MenuDateRange.dateOnly(date);
    if (!dates.any((item) => MenuDateRange.isSameDate(item, targetDate))) {
      return Future<void>.value();
    }

    final cacheDay = currentKstCacheDay();
    if (!forceRefresh && _hasReadableMenu(targetDate, cacheDay)) {
      return Future<void>.value();
    }

    final existing = _inflightDayFetches[targetDate];
    if (existing != null) {
      return existing;
    }

    late final Future<void> request;
    request =
        _performDayFetch(
          base: base,
          dates: dates,
          targetDate: targetDate,
          cacheDay: cacheDay,
          forceRefresh: forceRefresh,
        ).whenComplete(() {
          if (identical(_inflightDayFetches[targetDate], request)) {
            _inflightDayFetches.remove(targetDate);
          }
          _stopLoadingIfIdle();
        });
    _inflightDayFetches[targetDate] = request;
    return request;
  }

  /// [targetDate]의 메뉴 한 건을 조회해 현재 주간 메뉴 상태에 반영.
  ///
  /// 서버 응답 날짜가 요청 날짜와 다르거나 조회에 실패하면
  /// 해당 날짜만 오류 상태로 기록해 다른 날짜 메뉴는 유지한다.
  Future<void> _performDayFetch({
    required DateTime base,
    required List<DateTime> dates,
    required DateTime targetDate,
    required String cacheDay,
    required bool forceRefresh,
  }) async {
    final page = dates.indexWhere(
      (date) => MenuDateRange.isSameDate(date, targetDate),
    );
    if (page < 0) return;

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

    DailyMenu menu;
    try {
      final fetchedMenu = await _menuService.fetchDayMenu(
        page: page + 1,
        cacheMode: forceRefresh
            ? NetworkCacheMode.revalidate
            : NetworkCacheMode.preferCache,
        cacheDay: cacheDay,
      );
      if (!MenuDateRange.isSameDate(fetchedMenu.date, targetDate)) {
        menu = base.weekday >= DateTime.saturday
            ? DailyMenu.noMenu(date: targetDate)
            : DailyMenu.failure(
                date: targetDate,
                status: MenuDayStatus.parseFailed,
                message: '식당 메뉴 응답 날짜가 예상 날짜와 다릅니다.',
              );
      } else {
        menu = fetchedMenu;
      }
    } on MenuParseException catch (error) {
      menu = DailyMenu.failure(
        date: targetDate,
        status: MenuDayStatus.parseFailed,
        message: error.message,
      );
    } on MenuServiceException catch (error) {
      menu = DailyMenu.failure(
        date: targetDate,
        status: MenuDayStatus.networkError,
        message: error.message,
      );
    }

    final mergedMenus = _mergeMenu(state.menus, menu);
    final hasReadableMenu =
        menu.status == MenuDayStatus.loaded ||
        menu.status == MenuDayStatus.noMenu;
    state = state.copyWith(
      menus: mergedMenus,
      selectedCafeteriaName: MenuState._resolveCafeteriaName(
        _findMenuByDate(mergedMenus, state.selectedDate),
        state.selectedCafeteriaName,
      ),
      error: hasReadableMenu ? null : '식당 메뉴를 불러오지 못했어요.',
      fetchedAt: hasReadableMenu ? DateTime.now() : state.fetchedAt,
      cacheDay: hasReadableMenu ? cacheDay : state.cacheDay,
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

  bool _hasReadableMenu(DateTime date, String cacheDay) {
    if (state.cacheDay != cacheDay) return false;
    final menu = _findMenuByDate(state.menus, date);
    return menu != null &&
        (menu.status == MenuDayStatus.loaded ||
            menu.status == MenuDayStatus.noMenu);
  }

  List<DailyMenu> _mergeMenu(List<DailyMenu> currentMenus, DailyMenu menu) {
    final mergedMenus = <DailyMenu>[
      ...currentMenus.where(
        (item) => !MenuDateRange.isSameDate(item.date, menu.date),
      ),
      menu,
    ]..sort((left, right) => left.date.compareTo(right.date));
    return List.unmodifiable(mergedMenus);
  }

  void _stopLoadingIfIdle() {
    if (_inflightFetch != null || _inflightDayFetches.isNotEmpty) return;
    if (state.isLoading) {
      state = state.copyWith(isLoading: false);
    }
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
