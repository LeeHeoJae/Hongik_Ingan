import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hongik_ingan/core/logging/logger.dart';
import 'package:hongik_ingan/core/network/school_log_interceptor.dart';
import 'package:hongik_ingan/core/network/school_request_options.dart';
import 'package:hongik_ingan/core/network/school_transport.dart';
import 'package:hongik_ingan/core/network/school_transport_provider.dart';
import 'package:hongik_ingan/core/time/campus_clock.dart';
import 'package:hongik_ingan/features/cafeteria_menu/data/cafeteria_menu_exception.dart';
import 'package:hongik_ingan/features/cafeteria_menu/data/cafeteria_menu_parser.dart';
import 'package:hongik_ingan/features/cafeteria_menu/domain/cafeteria_menu.dart';

export 'cafeteria_menu_exception.dart';

/// YYYY-MM-DD 형태의 한국 날짜를 반환.
String currentKstCacheDay([DateTime? now]) {
  return campusDateKey(toCampusTime(now ?? DateTime.now()));
}

final cafeteriaMenuServiceProvider = Provider<CafeteriaMenuService>((ref) {
  final transport = ref.watch(schoolTransportProvider);
  return CafeteriaMenuService(transport, clock: ref.watch(campusClockProvider));
});

class CafeteriaMenuService {
  CafeteriaMenuService(this._transport, {DateTime Function()? clock})
    : _clock = clock ?? currentCampusTime;

  static const String _baseUrl = 'https://apps.hongik.ac.kr/food/food_m.php';

  final SchoolHttpTransport _transport;
  final DateTime Function() _clock;

  /// [baseDate] 기준 해당 주의 5일치 메뉴를 반환.
  Future<List<DailyMenu>> fetchMenus({
    required DateTime baseDate,
    NetworkCacheMode cacheMode = NetworkCacheMode.preferCache,
  }) async {
    final base = MenuDateRange.dateOnly(baseDate);
    if (base.weekday >= DateTime.saturday) {
      return _fetchWeekendMenus(base: base, cacheMode: cacheMode);
    }
    final displayDates = MenuDateRange.displayWeekdaysFor(base);
    final weekStart = displayDates.first;
    final cacheDay = campusDateKey(_clock());

    final pageMenus = await Future.wait(
      List.generate(5, (index) {
        final page = index + 1;
        final expectedDate = weekStart.add(Duration(days: index));
        return fetchValidatedDayMenu(
          page: page,
          expectedDate: expectedDate,
          cacheMode: cacheMode,
          cacheDay: cacheDay,
        );
      }),
    );

    final menusByDate = <DateTime, DailyMenu>{
      for (final menu in pageMenus) MenuDateRange.dateOnly(menu.date): menu,
    };
    return List.unmodifiable(
      displayDates.map((date) {
        return menusByDate[MenuDateRange.dateOnly(date)] ??
            DailyMenu.noMenu(date: date);
      }),
    );
  }

  Future<List<DailyMenu>> _fetchWeekendMenus({
    required DateTime base,
    required NetworkCacheMode cacheMode,
  }) async {
    final dates = MenuDateRange.displayWeekdaysFor(base);
    final monday = dates.first;
    try {
      final response = await _transport.get<String>(
        'https://www.hongik.ac.kr/sso/APICipher2.jsp',
        queryParameters: {
          'data': jsonEncode({
            'url': '/homepage/get_food_list.php',
            'url2': '&CAMPUS=0&YEAR=${monday.year}&MONTH=${monday.month}&DAY=',
            'url3': monday.day.toString(),
          }),
        },
        options: SchoolRequestOptions(
          responseType: ResponseType.plain,
          headers: const {'Accept': 'application/json,*/*'},
          cacheMode: cacheMode,
          cacheDay: campusDateKey(_clock()),
        ),
      );
      if ((response.statusCode ?? 500) >= 400) {
        throw const CafeteriaMenuServiceException('식당 메뉴 서버가 정상 응답을 보내지 않았어요.');
      }
      final menus = CafeteriaMenuParser.parseWeek(json: response.data ?? '');
      if (menus.isEmpty) {
        return fetchMenus(
          baseDate: MenuDateRange.currentWeekdaysFor(base).first,
          cacheMode: cacheMode,
        );
      }
      if (menus.any((menu) => !dates.contains(menu.date))) {
        throw const CafeteriaMenuParseException('식당 메뉴 응답 날짜가 예상 날짜와 다릅니다.');
      }
      return List.unmodifiable(
        dates.map(
          (date) => menus.firstWhere(
            (menu) => MenuDateRange.isSameDate(menu.date, date),
            orElse: () => DailyMenu.noMenu(date: date),
          ),
        ),
      );
    } on CafeteriaMenuServiceException catch (error) {
      return _failedWeek(dates, error);
    } on DioException {
      return _failedWeek(
        dates,
        const CafeteriaMenuServiceException(
          '식당 메뉴 페이지에 연결할 수 없어요. 잠시 후 다시 시도해 주세요.',
        ),
      );
    } catch (_) {
      return _failedWeek(
        dates,
        const CafeteriaMenuParseException('식당 메뉴 페이지 형식이 변경되어 메뉴를 읽지 못했어요.'),
      );
    }
  }

  List<DailyMenu> _failedWeek(
    List<DateTime> dates,
    CafeteriaMenuServiceException error,
  ) {
    return List.unmodifiable(
      dates.map(
        (date) => DailyMenu.failure(
          date: date,
          status: error is CafeteriaMenuParseException
              ? MenuDayStatus.parseFailed
              : MenuDayStatus.networkError,
          message: error.message,
        ),
      ),
    );
  }

  /// 식단 페이지 한 건을 요청해 [DailyMenu]로 제공.
  ///
  /// [page]는 학교 식단 페이지에 전달할 p 쿼리 값이다.
  Future<DailyMenu> fetchDayMenu({
    required int page,
    NetworkCacheMode cacheMode = NetworkCacheMode.preferCache,
    String? cacheDay,
  }) async {
    Response<String>? diagnosticResponse;
    try {
      final response = await _transport.get<String>(
        _baseUrl,
        queryParameters: {'p': page.toString()},
        options: SchoolRequestOptions(
          responseType: ResponseType.plain,
          headers: const {'Accept': 'text/html,*/*'},
          cacheMode: cacheMode,
          cacheDay: cacheDay ?? campusDateKey(_clock()),
        ),
      );
      diagnosticResponse = response;
      logResponseDiagnostics(response);
      if ((response.statusCode ?? 500) >= 400) {
        throw const CafeteriaMenuServiceException('식당 메뉴 서버가 정상 응답을 보내지 않았어요.');
      }

      final body = response.data;
      if (body == null || body.trim().isEmpty) {
        throw const CafeteriaMenuParseException('식당 메뉴 응답이 비어 있어요.');
      }
      return CafeteriaMenuParser.parse(html: body, referenceDate: _clock());
    } on CafeteriaMenuServiceException catch (e, stack) {
      logMsg(
        'cafeteria result=failure',
        level: LogLevel.error,
        error: e,
        stackTrace: stack,
        context: responseLogContext(diagnosticResponse),
      );
      rethrow;
    } on DioException catch (e, stack) {
      if (e.response case final response?) logResponseDiagnostics(response);
      logMsg(
        '식당 메뉴 요청 실패: ${e.message}',
        level: .error,
        error: e.type,
        stackTrace: stack,
        context: responseLogContext(e.response, request: e.requestOptions),
      );
      throw const CafeteriaMenuServiceException(
        '식당 메뉴 페이지에 연결할 수 없어요. 잠시 후 다시 시도해 주세요.',
      );
    } catch (e, stack) {
      logMsg(
        '식당 메뉴 처리 실패: $e',
        level: .error,
        error: e,
        stackTrace: stack,
        context: responseLogContext(diagnosticResponse),
      );
      throw const CafeteriaMenuParseException(
        '식당 메뉴 페이지 형식이 변경되어 메뉴를 읽지 못했어요.',
      );
    }
  }

  /// Fetches one page and maps date mismatches and expected errors to a day.
  Future<DailyMenu> fetchValidatedDayMenu({
    required int page,
    required DateTime expectedDate,
    required NetworkCacheMode cacheMode,
    required String cacheDay,
  }) async {
    try {
      final menu = await fetchDayMenu(
        page: page,
        cacheMode: cacheMode,
        cacheDay: cacheDay,
      );
      if (!MenuDateRange.isSameDate(menu.date, expectedDate)) {
        return DailyMenu.failure(
          date: expectedDate,
          status: MenuDayStatus.parseFailed,
          message: '식당 메뉴 응답 날짜가 예상 날짜와 다릅니다.',
        );
      }
      return menu;
    } on CafeteriaMenuParseException catch (error) {
      return DailyMenu.failure(
        date: expectedDate,
        status: MenuDayStatus.parseFailed,
        message: error.message,
      );
    } on CafeteriaMenuServiceException catch (error) {
      return DailyMenu.failure(
        date: expectedDate,
        status: MenuDayStatus.networkError,
        message: error.message,
      );
    }
  }
}
