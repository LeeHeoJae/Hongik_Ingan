import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/core/network/school_request_options.dart';
import 'package:hongik_ingan/core/network/school_transport.dart';
import 'package:hongik_ingan/core/network/school_transport_provider.dart';
import 'package:hongik_ingan/core/time/campus_clock.dart';
import 'package:hongik_ingan/features/cafeteria_menu/application/cafeteria_menu_controller.dart';
import 'package:hongik_ingan/features/cafeteria_menu/data/cafeteria_menu_service.dart';
import 'package:hongik_ingan/features/cafeteria_menu/domain/cafeteria_menu.dart';
import 'package:hongik_ingan/features/home/presentation/widgets/home_campus_summary.dart';

void main() {
  for (final scenario in [
    (
      instant: DateTime.utc(2026, 10, 2, 14, 59),
      selected: DateTime(2026, 10, 2),
      cacheDay: '2026-10-02',
    ),
    (
      instant: DateTime.utc(2026, 10, 2, 16, 30),
      selected: DateTime(2026, 10, 5),
      cacheDay: '2026-10-03',
    ),
    (
      instant: DateTime.utc(2026, 12, 31, 16, 30),
      selected: DateTime(2027, 1, 1),
      cacheDay: '2027-01-01',
    ),
  ]) {
    test(
      '요약과 초기·주간 조회, 캐시, 연도 해석은 같은 한국 날짜를 사용한다: ${scenario.cacheDay}',
      () async {
        DateTime clock() => toCampusTime(scenario.instant);
        final transport = _MenuTransport(clock);
        final container = ProviderContainer.test(
          overrides: [
            campusClockProvider.overrideWithValue(clock),
            schoolTransportProvider.overrideWithValue(transport),
          ],
        );
        addTearDown(container.dispose);
        final controller = container.read(
          cafeteriaMenuControllerProvider.notifier,
        );
        final initial = container.read(cafeteriaMenuControllerProvider);
        expect(initial.selectedDate, scenario.selected);
        expect(initial.baseDate, MenuDateRange.dateOnly(clock()));
        expect(initial.dates, MenuDateRange.displayWeekdaysFor(clock()));
        expect(
          campusDateKey(container.read(homeCampusTimeProvider)),
          scenario.cacheDay,
        );

        await controller.fetchInitialMenu();
        final loaded = container.read(cafeteriaMenuControllerProvider);
        expect(loaded.selectedMenu?.date, scenario.selected);
        expect(loaded.selectedMenu?.status, MenuDayStatus.loaded);
        expect(loaded.cacheDay, scenario.cacheDay);
        expect(transport.pages, [initial.dates.indexOf(scenario.selected) + 1]);

        await controller.fetchMenus();
        final week = container.read(cafeteriaMenuControllerProvider);
        expect(week.menus.map((menu) => menu.date), initial.dates);
        expect(
          week.menus.every((menu) => menu.status == MenuDayStatus.loaded),
          isTrue,
        );
        expect(transport.pages, hasLength(5));
        expect(transport.pages, containsAll([1, 2, 3, 4, 5]));
        expect(
          transport.cacheDays.every((key) => key == scenario.cacheDay),
          isTrue,
        );
        expect(currentKstCacheDay(scenario.instant), scenario.cacheDay);
      },
    );
  }

  test('열어 둔 화면이 한국의 토요일이 되면 날짜 조회도 다음 주를 요청한다', () async {
    var instant = DateTime.utc(2026, 10, 2, 14, 59);
    DateTime clock() => toCampusTime(instant);
    final transport = _MenuTransport(clock);
    final container = ProviderContainer.test(
      overrides: [
        campusClockProvider.overrideWithValue(clock),
        schoolTransportProvider.overrideWithValue(transport),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(cafeteriaMenuControllerProvider.notifier);
    await controller.fetchInitialMenu();
    instant = DateTime.utc(2026, 10, 2, 15);
    final monday = DateTime(2026, 10, 5);
    await controller.fetchMenuForDate(monday);
    final state = container.read(cafeteriaMenuControllerProvider);
    expect(state.baseDate, DateTime(2026, 10, 3));
    expect(state.selectedDate, monday);
    expect(state.selectedMenu?.status, MenuDayStatus.loaded);
    expect(state.cacheDay, '2026-10-03');
    expect(transport.pages, [5, 1]);
    expect(transport.cacheDays, ['2026-10-02', '2026-10-03']);
    expect(HomeCampusSummary.menu(state, clock()).status, '점심 메뉴');
  });

  test('서비스의 직접 조회도 한국 날짜를 캐시와 파서에 사용한다', () async {
    DateTime clock() => toCampusTime(DateTime.utc(2026, 12, 31, 16, 30));
    final transport = _MenuTransport(clock);
    final service = CafeteriaMenuService(transport, clock: clock);
    expect((await service.fetchDayMenu(page: 5)).date, DateTime(2027, 1, 1));
    final week = await service.fetchMenus(baseDate: clock());
    expect(week.first.date, DateTime(2026, 12, 28));
    expect(week.last.date, DateTime(2027, 1, 1));
    expect(week.every((menu) => menu.status == MenuDayStatus.loaded), isTrue);
    expect(transport.cacheDays, everyElement('2027-01-01'));
  });
}

class _MenuTransport implements SchoolTransport {
  _MenuTransport(this.clock);
  final DateTime Function() clock;
  final List<int> pages = [];
  final List<String?> cacheDays = [];

  @override
  Future<Response<T>> get<T>(
    String target, {
    Map<String, dynamic>? queryParameters,
    SchoolRequestOptions options = const SchoolRequestOptions(),
  }) async {
    final page = int.parse(queryParameters!['p'] as String);
    pages.add(page);
    cacheDays.add(options.cacheDay);
    final date = MenuDateRange.displayWeekdaysFor(clock())[page - 1];
    return Response<String>(
          data:
              '''<table><tbody>
        <tr><td class="title">${date.month}월 ${date.day}일</td></tr>
        <tr><td class="time"><strong>제2기숙사</strong></td></tr>
        <tr><th>중식(11:30~14:00)</th><td>점심 메뉴</td></tr>
        </tbody></table>''',
          statusCode: 200,
          requestOptions: RequestOptions(path: target),
        )
        as Response<T>;
  }

  @override
  Future<Response<T>> post<T>(
    String target, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    SchoolRequestOptions options = const SchoolRequestOptions(),
  }) => throw UnimplementedError();

  @override
  Future<void> clearAuthSession() async {}
  @override
  Future<bool> hasAuthSession() async => false;
  @override
  Future<bool> hasCookie(Uri target, String name) async => false;
  @override
  Future<void> saveAuthCookies(List<Cookie> cookies) async {}
}
