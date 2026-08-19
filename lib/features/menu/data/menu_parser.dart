import 'dart:convert';

import 'package:hongik_ingan/features/menu/data/menu_exception.dart';
import 'package:hongik_ingan/features/menu/domain/menu.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

final class MenuParser {
  const MenuParser._();

  /// [html]을 파싱하여 [DailyMenu]로 변환.
  ///
  /// 식단이 없으면 상태를 [MenuDayStatus.noMenu]로 반환한다.
  static DailyMenu parse({required String html}) {
    final document = html_parser.parse(html);
    final title = document.querySelector('td.title');
    final tableBody = document.querySelector('tbody');
    if (title == null || tableBody == null) {
      throw const MenuParseException('식당 메뉴 표를 찾지 못했어요.');
    }
    final menuDate = _parseMenuDate(title.text);

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
  static DateTime _parseMenuDate(String titleText) {
    final match = RegExp(r'(\d{1,2})월\s*(\d{1,2})일').firstMatch(titleText);
    if (match == null) {
      throw const MenuParseException('식당 메뉴 날짜를 찾지 못했어요.');
    }

    final month = int.parse(match.group(1)!);
    final day = int.parse(match.group(2)!);

    final now = DateTime.now();
    // 12월 31일에 1월 1일의 메뉴를 파싱하려고 하면 연도가 다른 문제 보정.
    final year = switch ((now.month, month)) {
      (DateTime.december, DateTime.january) => now.year + 1,
      (DateTime.january, DateTime.december) => now.year - 1,
      _ => now.year,
    };
    final menuDate = DateTime(year, month, day);
    if (menuDate.month != month || menuDate.day != day) {
      throw const MenuParseException('식당 메뉴 날짜 형식이 올바르지 않아요.');
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
    return item == _emptyMenuItem || _isHolidayItem(item);
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

  /// 공백 문자를 통일화.
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
