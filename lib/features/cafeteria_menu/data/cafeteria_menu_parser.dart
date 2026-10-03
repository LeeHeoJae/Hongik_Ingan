import 'dart:convert';

import 'package:hongik_ingan/core/time/campus_clock.dart';
import 'package:hongik_ingan/features/cafeteria_menu/data/cafeteria_menu_exception.dart';
import 'package:hongik_ingan/features/cafeteria_menu/domain/cafeteria_menu.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

final class CafeteriaMenuParser {
  const CafeteriaMenuParser._();

  /// Parses the date-addressable weekly feed used by the official website.
  static List<DailyMenu> parseWeek({required String json}) {
    final Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException {
      throw const CafeteriaMenuParseException('식당 메뉴 응답 형식이 올바르지 않아요.');
    }
    // The official endpoint returns an empty JSON object for an unpublished week.
    if (decoded == null || (decoded is Map && decoded.isEmpty)) return const [];
    if (decoded is! Map ||
        decoded['result'] != 'Y' ||
        decoded['RESTDATA'] is! List ||
        decoded['RESTINFO'] is! List) {
      throw const CafeteriaMenuParseException('식당 메뉴 응답 형식이 올바르지 않아요.');
    }
    final hoursByRestaurant = <String, String>{};
    for (final info in decoded['RESTINFO'] as List) {
      if (info is Map && info['REST_NO'] is String && info['WORK'] is String) {
        hoursByRestaurant[info['REST_NO'] as String] = Uri.decodeComponent(
          info['WORK'] as String,
        );
      }
    }
    final rowsByDate = <DateTime, List<Map>>{};
    for (final row in decoded['RESTDATA'] as List) {
      if (row is! Map ||
          row['MENU_DATE'] is! String ||
          row['REST_NO'] is! String ||
          row['PRICELEVEL'] is! String ||
          row['REST_NAME'] is! String ||
          row['MENU'] is! String) {
        throw const CafeteriaMenuParseException('식당 메뉴 응답 형식이 올바르지 않아요.');
      }
      final dateKey = row['MENU_DATE'] as String;
      if (!RegExp(r'^\d{8}$').hasMatch(dateKey)) {
        throw const CafeteriaMenuParseException('식당 메뉴 날짜 형식이 올바르지 않아요.');
      }
      final year = int.parse(dateKey.substring(0, 4));
      final month = int.parse(dateKey.substring(4, 6));
      final day = int.parse(dateKey.substring(6, 8));
      final date = DateTime(year, month, day);
      if (date.year != year || date.month != month || date.day != day) {
        throw const CafeteriaMenuParseException('식당 메뉴 날짜 형식이 올바르지 않아요.');
      }
      rowsByDate.putIfAbsent(date, () => []).add(row);
    }
    final menus = <DailyMenu>[];
    for (final entry in rowsByDate.entries) {
      final mealsByRestaurant = <String, List<MealMenu>>{};
      final names = <String, String>{};
      var hasHolidayNotice = false;
      for (final row in entry.value) {
        final restaurant = row['REST_NO'] as String;
        final type = switch ((restaurant, row['PRICELEVEL'])) {
          ('2', '0') || ('3', '1') || ('3', '2') => MealType.lunch,
          ('2', '1') || ('3', '3') => MealType.dinner,
          ('3', '0') => MealType.breakfast,
          _ => null,
        };
        if (type == null) {
          throw const CafeteriaMenuParseException('식당 메뉴의 식사 구분을 읽지 못했어요.');
        }
        names[restaurant] = Uri.decodeComponent(row['REST_NAME'] as String);
        final meals = mealsByRestaurant.putIfAbsent(restaurant, () => []);
        final rawItems = _linesFromHtml(
          Uri.decodeComponent(row['MENU'] as String),
        );
        hasHolidayNotice = hasHolidayNotice || rawItems.any(_isHolidayItem);
        final items = rawItems.where((item) => !_isNoMenuItem(item)).toList();
        if (items.isEmpty) continue;
        var time = '';
        for (final match in RegExp(
          r'(\d{1,2}:\d{2}\s*[~\-]\s*\d{1,2}:\d{2})\(([^)]+)\)',
        ).allMatches(hoursByRestaurant[restaurant] ?? '')) {
          if (_mealTypeFromText(match.group(2)!) == type) {
            time = match.group(1)!;
            break;
          }
        }
        meals.add(
          MealMenu(type: type, time: time, items: List.unmodifiable(items)),
        );
      }
      final menu = DailyMenu(
        date: entry.key,
        weekday: MenuDateRange.weekdayLabel(entry.key),
        cafeterias: List.unmodifiable([
          for (final entry in mealsByRestaurant.entries)
            CafeteriaMenu(
              name: names[entry.key]!,
              priceInfo: '',
              meals: List.unmodifiable(entry.value),
            ),
        ]),
        message: hasHolidayNotice ? '공휴일에는 식당을 운영하지 않아요.' : null,
      );
      menus.add(menu.hasMenu ? menu : menu.asNoMenu());
    }
    menus.sort((left, right) => left.date.compareTo(right.date));
    return List.unmodifiable(menus);
  }

  /// [html]을 파싱하여 [DailyMenu]로 변환.
  ///
  /// 식단이 없으면 상태를 [MenuDayStatus.noMenu]로 반환한다.
  static DailyMenu parse({required String html, DateTime? referenceDate}) {
    final document = html_parser.parse(html);
    final title = document.querySelector('td.title');
    final tableBody = document.querySelector('tbody');
    if (title == null || tableBody == null) {
      throw const CafeteriaMenuParseException('식당 메뉴 표를 찾지 못했어요.');
    }
    final menuDate = _parseMenuDate(
      title.text,
      referenceDate ?? currentCampusTime(),
    );

    final cafeterias = <CafeteriaMenu>[];
    String? currentName;
    String currentPriceInfo = '';
    var currentMeals = <MealMenu>[];
    var hasHolidayNotice = false;

    /// 현재 식당 정보를 저장하고 다음 식당을 읽을 상태로 초기화.
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
      final mealType = _mealTypeFromText(mealHeaderText);
      if (mealType == null) {
        continue;
      }

      final rawItems = _linesFromHtml(menuCell.innerHtml);
      hasHolidayNotice = hasHolidayNotice || rawItems.any(_isHolidayItem);
      final items = rawItems
          .where((item) => !_isNoMenuItem(item))
          .toList(growable: false);
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

    final menu = DailyMenu(
      date: menuDate,
      weekday: MenuDateRange.weekdayLabel(menuDate),
      cafeterias: List.unmodifiable(cafeterias),
      message: hasHolidayNotice ? '공휴일에는 식당을 운영하지 않아요.' : null,
    );
    return menu.hasMenu ? menu : menu.asNoMenu();
  }

  /// response 제목의 날짜를 검증 후 실제 날짜로 해석.
  static DateTime _parseMenuDate(String titleText, DateTime now) {
    final match = RegExp(r'(\d{1,2})월\s*(\d{1,2})일').firstMatch(titleText);
    if (match == null) {
      throw const CafeteriaMenuParseException('식당 메뉴 날짜를 찾지 못했어요.');
    }

    final month = int.parse(match.group(1)!);
    final day = int.parse(match.group(2)!);

    // 12월 31일에 1월 1일의 메뉴를 파싱하려고 하면 연도가 다른 문제 보정.
    final year = switch ((now.month, month)) {
      (DateTime.december, DateTime.january) => now.year + 1,
      (DateTime.january, DateTime.december) => now.year - 1,
      _ => now.year,
    };
    final menuDate = DateTime(year, month, day);
    if (menuDate.month != month || menuDate.day != day) {
      throw const CafeteriaMenuParseException('식당 메뉴 날짜 형식이 올바르지 않아요.');
    }
    return menuDate;
  }

  /// 식사 구분 텍스트를 [MealType]으로 변환.
  static MealType? _mealTypeFromText(String text) {
    if (text.contains('아침') || text.contains('조식')) {
      return MealType.breakfast;
    }
    if (text.contains('점심') || text.contains('중식')) {
      return MealType.lunch;
    }
    if (text.contains('저녁') || text.contains('석식')) {
      return MealType.dinner;
    }
    return null;
  }

  /// 메뉴 항목이 아닌지 확인.
  ///
  /// 비어있거나 공휴일인 경우가 있다.
  static bool _isNoMenuItem(String item) {
    return item == _emptyMenuItem || item == '운영X' || _isHolidayItem(item);
  }

  /// 공휴일을 나타내는 문구인지 확인.
  static bool _isHolidayItem(String item) {
    return _holidayItems.contains(item);
  }

  static bool _isTableRow(dom.Element element) {
    return element.localName == 'tr';
  }

  /// 식사 제목의 괄호 안 시간 범위를 추출.
  static String _parseMealTime(String mealHeaderText) {
    return RegExp(r'\(([^)]+)\)').firstMatch(mealHeaderText)?.group(1) ?? '';
  }

  /// <br>로 구분된 HTML 내용을 [List]으로 변환.
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

  /// 공백 문자를 통일.
  static String _normalizeText(String text) {
    return text
        .replaceAll('\u00A0', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static const String _emptyMenuItem = '등록된 식단이 없습니다.';

  static const Set<String> _holidayItems = {
    '신정',
    '설날',
    '삼일절',
    '3.1절',
    '어린이날',
    '부처님오신날',
    '현충일',
    '제헌절',
    '광복절',
    '개천절',
    '한글날',
    '추석',
    '성탄절',
    '크리스마스',
    '대체공휴일',
    '임시공휴일',
    '휴무',
  };
}
