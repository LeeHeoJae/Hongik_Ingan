import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import '../core/logger.dart';
import '../core/web_proxy.dart';
import '../models/food_menu.dart';

class FoodMenuServiceException implements Exception {
  const FoodMenuServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class FoodMenuParseException extends FoodMenuServiceException {
  const FoodMenuParseException(super.message);
}

class FoodMenuService {
  FoodMenuService({Dio? dio, String? baseUrl})
    : _dio = dio ?? _createDio(),
      _baseUrl = baseUrl ?? 'https://apps.hongik.ac.kr/food/food_m.php';

  final Dio _dio;
  final String _baseUrl;

  static Dio _createDio() {
    return Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 7),
        receiveTimeout: const Duration(seconds: 7),
        responseType: ResponseType.plain,
        headers: {
          'Accept': 'text/html,*/*',
          if (!kIsWeb)
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      ),
    );
  }

  Future<List<DailyFoodMenu>> fetchFiveDayMenus({DateTime? baseDate}) async {
    final dates = FoodMenuDateRange.around(baseDate ?? DateTime.now());
    return Future.wait(
      List.generate(dates.length, (index) {
        return fetchDayMenu(page: index + 1, date: dates[index]);
      }),
    );
  }

  Future<DailyFoodMenu> fetchDayMenu({
    required int page,
    required DateTime date,
  }) async {
    try {
      final requestUrl = webProxyUrl(_baseUrl, {'p': page.toString()});
      final response = await _dio.get<String>(
        requestUrl,
        queryParameters: kIsWeb ? null : {'p': page},
      );
      if ((response.statusCode ?? 500) >= 400) {
        throw const FoodMenuServiceException('식당 메뉴 서버가 정상 응답을 보내지 않았습니다.');
      }

      final body = response.data;
      if (body == null || body.trim().isEmpty) {
        throw const FoodMenuParseException('식당 메뉴 응답이 비어 있습니다.');
      }
      return parseMenu(date: date, html: body);
    } on FoodMenuServiceException {
      rethrow;
    } on DioException catch (e) {
      logMsg('식당 메뉴 요청 실패: ${e.message}', level: .error);
      throw const FoodMenuServiceException(
        '식당 메뉴 페이지에 연결할 수 없습니다. 잠시 후 다시 시도해주세요.',
      );
    } catch (e) {
      logMsg('식당 메뉴 처리 실패: $e', level: .error);
      throw const FoodMenuParseException('식당 메뉴 페이지 형식이 변경되어 메뉴를 읽지 못했습니다.');
    }
  }

  DailyFoodMenu parseMenu({required DateTime date, required String html}) {
    final normalizedDate = FoodMenuDateRange.dateOnly(date);
    final document = html_parser.parse(html);
    final title = document.querySelector('td.title strong');
    final tableBody = document.querySelector('tbody');
    if (title == null || tableBody == null) {
      throw const FoodMenuParseException('식당 메뉴 표를 찾지 못했습니다.');
    }

    final cafeterias = <CafeteriaMenu>[];
    String? currentName;
    String currentPriceInfo = '';
    var currentMeals = <MealMenu>[];

    void closeCurrentCafeteria() {
      if (currentName == null) {
        return;
      }
      cafeterias.add(
        CafeteriaMenu(
          name: currentName!,
          priceInfo: currentPriceInfo,
          meals: List.unmodifiable(currentMeals),
        ),
      );
      currentName = null;
      currentPriceInfo = '';
      currentMeals = <MealMenu>[];
    }

    for (final row in tableBody.children.where(_isTableRow)) {
      final cafeteriaHeader = row.querySelector('td.time strong');
      if (cafeteriaHeader != null) {
        closeCurrentCafeteria();
        final lines = _linesFromHtml(cafeteriaHeader.innerHtml);
        if (lines.isNotEmpty) {
          currentName = lines.first;
          currentPriceInfo = lines.skip(1).join(' ');
        }
        continue;
      }

      final mealHeader = row.querySelector('th');
      final menuCell = row.querySelector('td');
      if (currentName == null || mealHeader == null || menuCell == null) {
        continue;
      }

      final mealHeaderText = _normalizeText(mealHeader.text);
      final mealType = mealTypeFromText(mealHeaderText);
      if (mealType == null) {
        continue;
      }

      final items = _linesFromHtml(menuCell.innerHtml);
      if (items.isEmpty) {
        continue;
      }

      currentMeals.add(
        MealMenu(
          type: mealType,
          time: _parseMealTime(mealHeaderText),
          items: List.unmodifiable(items),
        ),
      );
    }
    closeCurrentCafeteria();

    final menu = DailyFoodMenu(
      date: normalizedDate,
      weekday: FoodMenuDateRange.weekdayLabel(normalizedDate),
      cafeterias: List.unmodifiable(cafeterias),
    );
    return menu.hasMenu ? menu : menu.asNoMenu();
  }

  static bool _isTableRow(dom.Element element) {
    return element.localName == 'tr';
  }

  static String _parseMealTime(String mealHeaderText) {
    return RegExp(r'\(([^)]+)\)').firstMatch(mealHeaderText)?.group(1) ?? '';
  }

  static List<String> _linesFromHtml(String rawHtml) {
    final htmlWithLineBreaks = rawHtml.replaceAll(
      RegExp(r'<br\s*/?>', caseSensitive: false),
      '\n',
    );
    final text = html_parser.parseFragment(htmlWithLineBreaks).text ?? '';
    return const LineSplitter()
        .convert(text)
        .map(_normalizeText)
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
  }

  static String _normalizeText(String text) {
    return text
        .replaceAll('\u00A0', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
