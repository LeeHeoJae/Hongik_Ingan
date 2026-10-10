import 'dart:convert';

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
        final weekend = initial.baseDate.weekday >= DateTime.saturday;
        expect(
          transport.pages,
          weekend ? isEmpty : [initial.dates.indexOf(scenario.selected) + 1],
        );

        await controller.fetchMenus();
        final week = container.read(cafeteriaMenuControllerProvider);
        expect(week.menus.map((menu) => menu.date), initial.dates);
        expect(
          week.menus.every((menu) => menu.status == MenuDayStatus.loaded),
          isTrue,
        );
        if (weekend) {
          expect(transport.weekRequests, hasLength(1));
          expect(transport.weekRequests.single, {
            'url': '/homepage/get_food_list.php',
            'url2': '&CAMPUS=0&YEAR=2026&MONTH=10&DAY=',
            'url3': '5',
          });
        } else {
          expect(transport.pages, hasLength(5));
          expect(transport.pages, containsAll([1, 2, 3, 4, 5]));
        }
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
    expect(transport.pages, [5]);
    expect(transport.weekRequests, hasLength(1));
    expect(transport.cacheDays, ['2026-10-02', '2026-10-03']);
    expect(
      HomeCampusSummary.menu(
        state.menus,
        clock(),
        isLoading: state.isLoading,
      ).status,
      '오늘은 등록된 메뉴가 없어요',
    );
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

  for (final weekendDay in [3, 4]) {
    test('다음 주가 미공개이면 이번 주 실제 날짜와 메뉴를 표시한다: $weekendDay', () async {
      DateTime clock() => DateTime(2026, 10, weekendDay, 12);
      final transport = _MenuTransport(clock)..nextWeekAvailable = false;
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
      await controller.fetchInitialMenu();
      final state = container.read(cafeteriaMenuControllerProvider);
      expect(state.dates.first, DateTime(2026, 9, 28));
      expect(state.dates.last, DateTime(2026, 10, 2));
      expect(state.selectedDate, DateTime(2026, 10, 2));
      expect(state.isShowingCurrentWeek, isTrue);
      expect(state.menus.every((menu) => menu.hasMenu), isTrue);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
      expect(transport.pages, [1, 2, 3, 4, 5]);
      controller.selectDate(DateTime(2026, 9, 29));
      await controller.fetchMenus();
      expect(
        container.read(cafeteriaMenuControllerProvider).selectedDate,
        DateTime(2026, 9, 29),
      );
      expect(transport.weekRequests, hasLength(1));
    });
  }

  test('미공개 주는 새로고침하거나 5분 후 다시 열면 공개 여부를 재조회한다', () async {
    var now = DateTime(2026, 10, 3, 12);
    DateTime clock() => now;
    final transport = _MenuTransport(clock)..nextWeekAvailable = false;
    final container = ProviderContainer.test(
      overrides: [
        campusClockProvider.overrideWithValue(clock),
        schoolTransportProvider.overrideWithValue(transport),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(cafeteriaMenuControllerProvider.notifier);
    await Future.wait([controller.fetchInitialMenu(), controller.fetchMenus()]);
    expect(transport.weekRequests, hasLength(1));
    await controller.refresh();
    expect(transport.weekRequests, hasLength(2));
    expect(transport.modes.last, NetworkCacheMode.revalidate);
    transport.nextWeekAvailable = true;
    now = now.add(const Duration(minutes: 5));
    await controller.fetchMenus();
    final state = container.read(cafeteriaMenuControllerProvider);
    expect(transport.weekRequests, hasLength(3));
    expect(state.isShowingCurrentWeek, isFalse);
    expect(state.dates.first, DateTime(2026, 10, 5));
    expect(state.selectedDate, DateTime(2026, 10, 5));
    expect(state.menus.every((menu) => menu.hasMenu), isTrue);
  });

  test('주말 API 오류는 미공개로 취급하지 않고 조회 실패로 표시한다', () async {
    DateTime clock() => DateTime(2026, 10, 3);
    for (final malformed in [false, true]) {
      final transport = _MenuTransport(clock)
        ..failWeekRequest = !malformed
        ..malformedWeekResponse = malformed;
      final service = CafeteriaMenuService(transport, clock: clock);
      final menus = await service.fetchMenus(baseDate: clock());
      expect(
        menus.every(
          (menu) =>
              menu.status ==
              (malformed
                  ? MenuDayStatus.parseFailed
                  : MenuDayStatus.networkError),
        ),
        isTrue,
      );
      expect(transport.pages, isEmpty);
    }
  });

  test('다음 주가 모두 휴무여도 공개된 주를 이번 주로 대체하지 않는다', () async {
    DateTime clock() => DateTime(2026, 10, 3);
    final transport = _MenuTransport(clock)..weeklyMenuText = '한글날';
    final menus = await CafeteriaMenuService(
      transport,
      clock: clock,
    ).fetchMenus(baseDate: clock());
    expect(menus.first.date, DateTime(2026, 10, 5));
    expect(menus.every((menu) => menu.status == MenuDayStatus.noMenu), isTrue);
    expect(
      menus.every((menu) => menu.message == '공휴일에는 식당을 운영하지 않아요.'),
      isTrue,
    );
    expect(transport.pages, isEmpty);
  });

  test('날짜 지정 API의 다른 주 응답을 다음 주 메뉴로 표시하지 않는다', () async {
    DateTime clock() => DateTime(2026, 10, 3);
    final transport = _MenuTransport(clock)
      ..publishedWeekStart = DateTime(2026, 9, 28);
    final menus = await CafeteriaMenuService(
      transport,
      clock: clock,
    ).fetchMenus(baseDate: clock());
    expect(menus.first.date, DateTime(2026, 10, 5));
    expect(
      menus.every((menu) => menu.status == MenuDayStatus.parseFailed),
      isTrue,
    );
    expect(transport.pages, isEmpty);
  });

  test('연말 주말의 미공개 식단은 이전 연도의 이번 주로 돌아간다', () async {
    DateTime clock() => DateTime(2027, 1, 2);
    final transport = _MenuTransport(clock)..nextWeekAvailable = false;
    final menus = await CafeteriaMenuService(
      transport,
      clock: clock,
    ).fetchMenus(baseDate: clock());
    expect(menus.first.date, DateTime(2026, 12, 28));
    expect(menus.last.date, DateTime(2027, 1, 1));
    expect(menus.every((menu) => menu.hasMenu), isTrue);
    expect(
      transport.weekRequests.single['url2'],
      '&CAMPUS=0&YEAR=2027&MONTH=1&DAY=',
    );
  });
}

class _MenuTransport implements SchoolTransport {
  _MenuTransport(this.clock);
  final DateTime Function() clock;
  final List<int> pages = [];
  final List<String?> cacheDays = [];
  final List<Map<String, dynamic>> weekRequests = [];
  final List<NetworkCacheMode> modes = [];
  bool nextWeekAvailable = true;
  bool failWeekRequest = false;
  bool malformedWeekResponse = false;
  String weeklyMenuText = '점심 메뉴';
  DateTime? publishedWeekStart;

  @override
  Future<Response<T>> get<T>(
    String target, {
    Map<String, dynamic>? queryParameters,
    SchoolRequestOptions options = const SchoolRequestOptions(),
  }) async {
    cacheDays.add(options.cacheDay);
    modes.add(options.cacheMode);
    if (target.endsWith('/sso/APICipher2.jsp')) {
      weekRequests.add(
        jsonDecode(queryParameters!['data'] as String) as Map<String, dynamic>,
      );
      if (failWeekRequest) {
        throw DioException(requestOptions: RequestOptions(path: target));
      }
      return Response<String>(
            data: malformedWeekResponse
                ? '<html>Invalid response</html>'
                : !nextWeekAvailable
                ? '{}'
                : jsonEncode({
                    'result': 'Y',
                    'RESTINFO': [
                      {
                        'REST_NO': '3',
                        'WORK': Uri.encodeComponent('11:30~14:00(중식)'),
                      },
                    ],
                    'RESTDATA': [
                      for (final date in MenuDateRange.currentWeekdaysFor(
                        publishedWeekStart ??
                            MenuDateRange.displayWeekdaysFor(clock()).first,
                      ))
                        {
                          'MENU_DATE': campusDateKey(date).replaceAll('-', ''),
                          'REST_NO': '3',
                          'PRICELEVEL': '1',
                          'REST_NAME': Uri.encodeComponent('제2기숙사'),
                          'MENU': Uri.encodeComponent(weeklyMenuText),
                        },
                    ],
                  }),
            statusCode: 200,
            requestOptions: RequestOptions(path: target),
          )
          as Response<T>;
    }
    final page = int.parse(queryParameters!['p'] as String);
    pages.add(page);
    final date = MenuDateRange.currentWeekdaysFor(clock())[page - 1];
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
