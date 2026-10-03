import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/features/cafeteria_menu/data/cafeteria_menu_parser.dart';
import 'package:hongik_ingan/features/cafeteria_menu/data/cafeteria_menu_exception.dart';
import 'package:hongik_ingan/features/cafeteria_menu/domain/cafeteria_menu.dart';

void main() {
  Map<String, String> row(
    String date,
    String restaurant,
    String level,
    String menu,
  ) => {
    'MENU_DATE': date,
    'REST_NO': restaurant,
    'PRICELEVEL': level,
    'REST_NAME': Uri.encodeComponent(restaurant == '2' ? '교직원식당' : '제2기숙사'),
    'MENU': Uri.encodeComponent(menu),
  };
  String response(List<Map<String, String>> rows) => jsonEncode({
    'result': 'Y',
    'RESTINFO': [
      {
        'REST_NO': '2',
        'WORK': Uri.encodeComponent('11:30~14:00(중식), 17:00~18:30(석식)<br/>'),
      },
      {
        'REST_NO': '3',
        'WORK': Uri.encodeComponent(
          '08:00~09:00(조식), 11:30~14:00(중식), 17:30~18:50(석식)<br/>',
        ),
      },
    ],
    'RESTDATA': rows,
  });

  test('공식 응답의 날짜와 식당, 중식 두 선택지와 식사 시간을 보존한다', () {
    final menus = CafeteriaMenuParser.parseWeek(
      json: response([
        row('20261006', '2', '0', '순살감자탕\r\n쌀밥'),
        row('20261006', '2', '1', '유부된장국'),
        row('20261006', '3', '0', '함박스테이크&amp;소스\r\n백미밥'),
        row('20261006', '3', '1', '불맛제육볶음'),
        row('20261006', '3', '2', '연어치즈까스&amp;타르s'),
        row('20261006', '3', '3', '야끼소바'),
      ]),
    );
    final menu = menus.single;
    expect(menu.date, DateTime(2026, 10, 6));
    expect(menu.weekday, '화');
    expect(menu.status, MenuDayStatus.loaded);
    final faculty = menu.cafeterias.first;
    expect(faculty.meals.map((meal) => meal.type), [
      MealType.lunch,
      MealType.dinner,
    ]);
    expect(faculty.meals.last.time, '17:00~18:30');
    final dorm = menu.cafeterias.last;
    expect(dorm.name, '제2기숙사');
    expect(dorm.meals.map((meal) => meal.type), [
      MealType.breakfast,
      MealType.lunch,
      MealType.lunch,
      MealType.dinner,
    ]);
    expect(dorm.meals.first.items, ['함박스테이크&소스', '백미밥']);
    expect(dorm.meals.first.time, '08:00~09:00');
    expect(dorm.meals.last.time, '17:30~18:50');
  });

  test('공휴일과 운영X 문구를 음식으로 표시하지 않는다', () {
    final menus = CafeteriaMenuParser.parseWeek(
      json: response([
        row('20261009', '2', '0', '한글날\r\n운영X'),
        row('20261009', '3', '1', '한글날'),
        row('20261005', '2', '0', '대체공휴일\r\n운영X'),
        row('20261005', '3', '1', '대체공휴일'),
      ]),
    );
    expect(menus.map((menu) => menu.date), [
      DateTime(2026, 10, 5),
      DateTime(2026, 10, 9),
    ]);
    expect(menus.every((menu) => menu.status == MenuDayStatus.noMenu), isTrue);
    expect(menus.every((menu) => !menu.hasMenu), isTrue);
    expect(
      menus.every((menu) => menu.message == '공휴일에는 식당을 운영하지 않아요.'),
      isTrue,
    );
  });

  test('미공개 주의 null과 빈 목록을 구분 없이 빈 주로 반환한다', () {
    expect(CafeteriaMenuParser.parseWeek(json: 'null'), isEmpty);
    expect(CafeteriaMenuParser.parseWeek(json: '{}'), isEmpty);
    expect(CafeteriaMenuParser.parseWeek(json: response([])), isEmpty);
    final menus = CafeteriaMenuParser.parseWeek(
      json: response([row('20261006', '3', '1', '등록된 식단이 없습니다.')]),
    );
    expect(menus.single.status, MenuDayStatus.noMenu);
    expect(menus.single.message, isNull);
  });

  test('형식 변경과 잘못된 날짜는 미공개가 아닌 파싱 오류로 처리한다', () {
    for (final source in [
      '<html>Bad gateway</html>',
      '{"result":"N"}',
      response([row('20261301', '3', '1', '밥')]),
      response([row('20260230', '3', '1', '밥')]),
      response([row('20261006', '3', '9', '밥')]),
    ]) {
      expect(
        () => CafeteriaMenuParser.parseWeek(json: source),
        throwsA(isA<CafeteriaMenuParseException>()),
      );
    }
  });
}
