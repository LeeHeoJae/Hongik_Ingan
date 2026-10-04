import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/core/network/school_request_options.dart';
import 'package:hongik_ingan/core/network/school_transport.dart';
import 'package:hongik_ingan/core/time/campus_clock.dart';
import 'package:hongik_ingan/features/cafeteria_menu/application/cafeteria_menu_controller.dart';
import 'package:hongik_ingan/features/cafeteria_menu/data/cafeteria_menu_service.dart';
import 'package:hongik_ingan/features/cafeteria_menu/domain/cafeteria_menu.dart';
import 'package:hongik_ingan/features/home/presentation/widgets/home_campus_summary.dart';

void main() {
  for (final oldResponseFirst in [false, true]) {
    test(
      'a Sunday response cannot replace Monday menus: $oldResponseFirst',
      () async {
        var now = DateTime(2026, 10, 4, 23, 59);
        final oldWeek = Completer<List<DailyMenu>>();
        final monday = Completer<DailyMenu>();
        final service = _MenuService(
          week: (_) => oldWeek.future,
          day: (_, _) => monday.future,
        );
        final container = _container(() => now, service);
        final controller = container.read(
          cafeteriaMenuControllerProvider.notifier,
        );
        final sundayRequest = controller.fetchInitialMenu();
        now = DateTime(2026, 10, 5, 0, 1);
        final mondayRequest = controller.fetchInitialMenu();
        final previousWeek = MenuDateRange.currentWeekdaysFor(
          DateTime(2026, 10, 4),
        ).map((date) => _menu(date, 'Previous week')).toList();

        if (oldResponseFirst) {
          oldWeek.complete(previousWeek);
          await sundayRequest;
          expect(
            container.read(cafeteriaMenuControllerProvider).isLoading,
            isTrue,
          );
          expect(
            container.read(cafeteriaMenuControllerProvider).dates.first,
            DateTime(2026, 10, 5),
          );
        }
        monday.complete(_menu(DateTime(2026, 10, 5), 'Monday menu'));
        await mondayRequest;
        expect(
          container.read(cafeteriaMenuControllerProvider).isLoading,
          isFalse,
        );
        if (!oldResponseFirst) {
          oldWeek.complete(previousWeek);
          await sundayRequest;
        }

        final state = container.read(cafeteriaMenuControllerProvider);
        expect(state.baseDate, DateTime(2026, 10, 5));
        expect(state.dates.first, DateTime(2026, 10, 5));
        expect(state.cacheDay, '2026-10-05');
        expect(HomeCampusSummary.menu(state, now).status, 'Monday menu');
      },
    );
  }

  test('a new weekend day starts its own weekly request', () async {
    var now = DateTime(2026, 10, 3, 23, 59);
    final weeks = <Completer<List<DailyMenu>>>[];
    final service = _MenuService(
      week: (_) {
        final response = Completer<List<DailyMenu>>();
        weeks.add(response);
        return response.future;
      },
    );
    final container = _container(() => now, service);
    final controller = container.read(cafeteriaMenuControllerProvider.notifier);
    final saturdayRequest = controller.fetchMenus();
    now = DateTime(2026, 10, 4, 0, 1);
    final sundayRequest = controller.fetchMenus();
    expect(weeks, hasLength(2));
    final dates = MenuDateRange.displayWeekdaysFor(now);
    weeks.last.complete(
      dates.map((date) => _menu(date, 'Sunday menu')).toList(),
    );
    await sundayRequest;
    weeks.first.complete(
      dates.map((date) => _menu(date, 'Saturday menu')).toList(),
    );
    await saturdayRequest;
    expect(
      container
          .read(cafeteriaMenuControllerProvider)
          .selectedCafeteria
          ?.meals
          .single
          .items,
      ['Sunday menu'],
    );
    expect(
      container.read(cafeteriaMenuControllerProvider).cacheDay,
      '2026-10-04',
    );
    expect(container.read(cafeteriaMenuControllerProvider).isLoading, isFalse);
  });

  test(
    'a pending day request is shared only within the same cache day',
    () async {
      var now = DateTime(2026, 10, 5, 23, 59);
      final responses = <Completer<DailyMenu>>[];
      final cacheDays = <String?>[];
      final service = _MenuService(
        day: (_, cacheDay) {
          cacheDays.add(cacheDay);
          final response = Completer<DailyMenu>();
          responses.add(response);
          return response.future;
        },
      );
      final container = _container(() => now, service);
      final controller = container.read(
        cafeteriaMenuControllerProvider.notifier,
      );
      final friday = DateTime(2026, 10, 9);
      final mondayRequest = controller.fetchMenuForDate(friday);
      final duplicate = controller.fetchMenuForDate(friday);
      expect(identical(mondayRequest, duplicate), isTrue);
      expect(responses, hasLength(1));
      now = DateTime(2026, 10, 6, 0, 1);
      final tuesdayRequest = controller.fetchMenuForDate(friday);
      expect(cacheDays, ['2026-10-05', '2026-10-06']);
      responses.last.complete(_menu(friday, 'Updated menu'));
      await tuesdayRequest;
      expect(
        container.read(cafeteriaMenuControllerProvider).isLoading,
        isFalse,
      );
      responses.first.complete(_menu(friday, 'Old menu'));
      await mondayRequest;
      controller.selectDate(friday);
      expect(
        container
            .read(cafeteriaMenuControllerProvider)
            .selectedCafeteria
            ?.meals
            .single
            .items,
        ['Updated menu'],
      );
      expect(container.read(cafeteriaMenuControllerProvider).fetchedAt, now);
      await controller.fetchMenuForDate(friday);
      expect(responses, hasLength(2));
    },
  );

  test('refreshing today leaves other menu dates due for refresh', () async {
    var now = DateTime(2026, 10, 5, 12);
    var revision = 'Old menu';
    final pages = <int>[];
    final service = _MenuService(
      day: (page, _) async {
        pages.add(page);
        final date = MenuDateRange.currentWeekdaysFor(now)[page - 1];
        return page == 5 ? DailyMenu.noMenu(date: date) : _menu(date, revision);
      },
    );
    final container = _container(() => now, service);
    final controller = container.read(cafeteriaMenuControllerProvider.notifier);
    await controller.fetchMenus();
    expect(pages, [1, 2, 3, 4, 5]);
    now = DateTime(2026, 10, 6, 12);
    revision = 'Updated menu';
    await controller.fetchInitialMenu();
    expect(pages, [1, 2, 3, 4, 5, 2]);
    await controller.fetchMenus();
    expect(pages, [1, 2, 3, 4, 5, 2, 1, 3, 4, 5]);
    controller.selectDate(DateTime(2026, 10, 8));
    expect(
      container
          .read(cafeteriaMenuControllerProvider)
          .selectedCafeteria
          ?.meals
          .single
          .items,
      ['Updated menu'],
    );
    await controller.fetchMenus();
    expect(pages, hasLength(10));
    await controller.refresh();
    expect(pages.skip(10), [1, 2, 3, 4, 5]);
  });

  test('a failed refresh does not make a menu date fresh', () async {
    DateTime clock() => DateTime(2026, 10, 5, 12);
    var calls = 0;
    final date = DateTime(2026, 10, 5);
    final service = _MenuService(
      day: (_, _) async {
        calls++;
        return calls == 2
            ? DailyMenu.failure(
                date: date,
                status: MenuDayStatus.networkError,
                message: 'Failed',
              )
            : _menu(date, 'Updated menu');
      },
    );
    final container = _container(clock, service);
    final controller = container.read(cafeteriaMenuControllerProvider.notifier);
    await controller.fetchInitialMenu();
    await controller.fetchInitialMenu(forceRefresh: true);
    expect(
      container.read(cafeteriaMenuControllerProvider).selectedMenu?.status,
      MenuDayStatus.networkError,
    );
    await controller.fetchInitialMenu();
    expect(calls, 3);
    expect(
      container.read(cafeteriaMenuControllerProvider).selectedMenu?.status,
      MenuDayStatus.loaded,
    );
  });
}

ProviderContainer _container(
  DateTime Function() clock,
  CafeteriaMenuService service,
) {
  final container = ProviderContainer.test(
    overrides: [
      campusClockProvider.overrideWithValue(clock),
      cafeteriaMenuServiceProvider.overrideWithValue(service),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

DailyMenu _menu(DateTime date, String item) => DailyMenu(
  date: date,
  weekday: MenuDateRange.weekdayLabel(date),
  cafeterias: [
    CafeteriaMenu(
      name: '학생식당',
      priceInfo: '',
      meals: [
        MealMenu(type: MealType.lunch, time: '11:30~14:00', items: [item]),
      ],
    ),
  ],
);

class _MenuService extends CafeteriaMenuService {
  _MenuService({this.week, this.day}) : super(_UnusedTransport());

  final Future<List<DailyMenu>> Function(DateTime baseDate)? week;
  final Future<DailyMenu> Function(int page, String? cacheDay)? day;

  @override
  Future<List<DailyMenu>> fetchMenus({
    required DateTime baseDate,
    NetworkCacheMode cacheMode = NetworkCacheMode.preferCache,
  }) => week!(baseDate);

  @override
  Future<DailyMenu> fetchDayMenu({
    required int page,
    NetworkCacheMode cacheMode = NetworkCacheMode.preferCache,
    String? cacheDay,
  }) => day!(page, cacheDay);
}

class _UnusedTransport implements SchoolHttpTransport {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
