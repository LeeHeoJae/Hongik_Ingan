import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hongik_ingan/core/logging/logger.dart';
import 'package:hongik_ingan/core/network/school_request_options.dart';
import 'package:hongik_ingan/core/network/school_transport.dart';
import 'package:hongik_ingan/features/menu/data/menu_exception.dart';
import 'package:hongik_ingan/features/menu/data/menu_parser.dart';
import 'package:hongik_ingan/features/menu/domain/menu.dart';

import '../../../core/network/school_transport_provider.dart';

export 'menu_exception.dart';

final menuServiceProvider = Provider<MenuService>((ref) {
  final transport = ref.watch(schoolTransportProvider);
  return MenuService(transport);
});

class MenuService {
  MenuService(this._transport);

  static const String _baseUrl = 'https://apps.hongik.ac.kr/food/food_m.php';

  final SchoolHttpTransport _transport;

  /// [baseDate] 주의 5일치 메뉴를 반환.
  Future<List<DailyMenu>> fetchMenus({required DateTime baseDate}) async {
    final base = MenuDateRange.dateOnly(baseDate);
    final displayDates = MenuDateRange.displayWeekdaysFor(base);
    final weekStart = displayDates.first;
    final isWeekendRequest = base.weekday >= DateTime.saturday;

    final pageMenus = await Future.wait(
      List.generate(5, (index) {
        final page = index + 1;
        final expectedDate = weekStart.add(Duration(days: index));
        return _fetchPageSafely(
          page: page,
          expectedDate: expectedDate,
          treatDateMismatchAsNoMenu: isWeekendRequest,
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

  /// 식단 페이지 한 건을 요청해 [DailyMenu]로 제공.
  ///
  /// [page]는 학교 식단 페이지에 전달할 p 쿼리 값이다.
  Future<DailyMenu> fetchDayMenu({required int page}) async {
    try {
      final response = await _transport.get<String>(
        _baseUrl,
        queryParameters: {'p': page.toString()},
        options: const SchoolRequestOptions(
          responseType: ResponseType.plain,
          headers: {'Accept': 'text/html,*/*'},
        ),
      );
      if ((response.statusCode ?? 500) >= 400) {
        throw const MenuServiceException('식당 메뉴 서버가 정상 응답을 보내지 않았습니다.');
      }

      final body = response.data;
      if (body == null || body.trim().isEmpty) {
        throw const MenuParseException('식당 메뉴 응답이 비어 있습니다.');
      }
      return MenuParser.parse(html: body);
    } on MenuServiceException {
      rethrow;
    } on DioException catch (e) {
      logMsg('식당 메뉴 요청 실패: ${e.message}', level: .error);
      throw const MenuServiceException(
        '식당 메뉴 페이지에 연결할 수 없습니다. 잠시 후 다시 시도해주세요.',
      );
    } catch (e) {
      logMsg('식당 메뉴 처리 실패: $e', level: .error);
      throw const MenuParseException('식당 메뉴 페이지 형식이 변경되어 메뉴를 읽지 못했습니다.');
    }
  }

  Future<DailyMenu> _fetchPageSafely({
    required int page,
    required DateTime expectedDate,
    required bool treatDateMismatchAsNoMenu,
  }) async {
    try {
      final menu = await fetchDayMenu(page: page);
      if (!MenuDateRange.isSameDate(menu.date, expectedDate)) {
        if (treatDateMismatchAsNoMenu) {
          return DailyMenu.noMenu(date: expectedDate);
        }
        return DailyMenu.failure(
          date: expectedDate,
          status: MenuDayStatus.parseFailed,
          message: '식당 메뉴 응답 날짜가 예상 날짜와 다릅니다.',
        );
      }
      return menu;
    } on MenuParseException catch (error) {
      return DailyMenu.failure(
        date: expectedDate,
        status: MenuDayStatus.parseFailed,
        message: error.message,
      );
    } on MenuServiceException catch (error) {
      return DailyMenu.failure(
        date: expectedDate,
        status: MenuDayStatus.networkError,
        message: error.message,
      );
    }
  }
}
