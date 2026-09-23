import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/core/network/school_request_options.dart';
import 'package:hongik_ingan/core/network/school_transport.dart';
import 'package:hongik_ingan/core/network/school_transport_provider.dart';
import 'package:hongik_ingan/core/theme/theme.dart';
import 'package:hongik_ingan/features/cafeteria_menu/application/cafeteria_menu_controller.dart';
import 'package:hongik_ingan/features/cafeteria_menu/domain/cafeteria_menu.dart';
import 'package:hongik_ingan/features/home/presentation/home_screen.dart';
import 'package:hongik_ingan/features/seat/application/seat_controller.dart';
import 'package:hongik_ingan/features/seat/domain/seat.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('모바일에서 로그인 입력과 서비스 선택을 전환 후에도 유지한다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_subject());
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, 'test-student');
    await tester.enterText(find.byType(TextField).last, 'test-password');

    await tester.ensureVisible(find.text('열람실'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('열람실'));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(const ValueKey('home-service-seat'))).top,
      lessThan(200),
    );
    await tester.ensureVisible(find.text('R동'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('R동'));
    await tester.pump();

    await tester.ensureVisible(find.text('학식 메뉴'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('학식 메뉴'));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(const ValueKey('home-service-menu'))).top,
      lessThan(200),
    );
    await tester.ensureVisible(find.text('교직원 식당'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('교직원 식당'));
    await tester.pump();

    await tester.ensureVisible(find.text('로그인·출결'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('로그인·출결'));
    await tester.pumpAndSettle();
    final fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    expect(fields.first.controller!.text, 'test-student');
    expect(fields.last.controller!.text, 'test-password');

    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomeScreen)),
    );
    expect(
      container.read(seatControllerProvider).selectedLocation,
      SeatLocation.rBuilding,
    );
    expect(
      container.read(cafeteriaMenuControllerProvider).selectedCafeteria?.name,
      '교직원 식당',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('좁은 화면과 키보드가 열린 상태에서도 세 기능에 접근할 수 있다', (tester) async {
    tester.view.physicalSize = const Size(320, 620);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: _subject(),
      ),
    );
    await tester.pump();

    expect(find.byType(TextField), findsNWidgets(2));
    await tester.ensureVisible(find.text('학식 메뉴'));
    await tester.pumpAndSettle();
    expect(find.text('열람실'), findsOneWidget);
    expect(find.text('학식 메뉴'), findsOneWidget);
    await tester.tap(find.text('학식 메뉴'));
    await tester.pumpAndSettle();
    expect(find.text('주간 식당 메뉴'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('넓은 홈 화면에서 주 영역은 크고 보조 영역은 오른쪽에 쌓인다', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_subject());
    await tester.pump();

    final attendance = tester.getRect(
      find.byKey(const ValueKey('home-service-attendance')),
    );
    final seat = tester.getRect(
      find.byKey(const ValueKey('home-service-seat')),
    );
    final menu = tester.getRect(
      find.byKey(const ValueKey('home-service-menu')),
    );
    expect(attendance.width, greaterThan(seat.width * 2));
    expect(seat.left, greaterThan(attendance.right));
    expect(menu.top, greaterThan(seat.bottom));
    expect(find.text('등록된 메뉴가 없어요'), findsOneWidget);

    await tester.tap(find.text('학식 메뉴'));
    await tester.pumpAndSettle();
    final promotedMenu = tester.getRect(
      find.byKey(const ValueKey('home-service-menu')),
    );
    expect(promotedMenu.width, attendance.width);
    expect(tester.takeException(), isNull);
  });
}

Widget _subject() {
  return ProviderScope(
    overrides: [
      schoolTransportProvider.overrideWithValue(_FakeSchoolTransport()),
      seatControllerProvider.overrideWith(_PreviewSeatController.new),
      cafeteriaMenuControllerProvider.overrideWith(
        _PreviewCafeteriaMenuController.new,
      ),
    ],
    child: MaterialApp(
      theme: themeData,
      darkTheme: darkThemeData,
      home: const HomeScreen(),
    ),
  );
}

class _PreviewSeatController extends SeatController {
  @override
  SeatState build() => SeatState();

  @override
  Future<void> fetchSelectedStatus({bool forceRefresh = false}) async {}

  @override
  Future<void> refresh() async {}

  @override
  void selectLocation(SeatLocation location) {
    state = state.copyWith(selectedLocation: location);
  }
}

class _PreviewCafeteriaMenuController extends CafeteriaMenuController {
  @override
  CafeteriaMenuState build() {
    final base = MenuDateRange.dateOnly(DateTime.now());
    final dates = MenuDateRange.displayWeekdaysFor(base);
    final selected = MenuDateRange.initialSelectedDateFor(base);
    return CafeteriaMenuState(
      baseDate: base,
      selectedDate: selected,
      dates: dates,
      menus: [
        DailyMenu(
          date: selected,
          weekday: MenuDateRange.weekdayLabel(selected),
          cafeterias: const [
            CafeteriaMenu(name: '기숙사 식당', priceInfo: '', meals: []),
            CafeteriaMenu(name: '교직원 식당', priceInfo: '', meals: []),
          ],
        ),
      ],
    );
  }

  @override
  Future<void> fetchInitialMenu({bool forceRefresh = false}) async {}

  @override
  Future<void> fetchMenus({
    DateTime? baseDate,
    bool forceRefresh = false,
  }) async {}

  @override
  Future<void> refresh() async {}
}

class _FakeSchoolTransport implements SchoolTransport {
  @override
  Future<Response<T>> get<T>(
    String target, {
    Map<String, dynamic>? queryParameters,
    SchoolRequestOptions options = const SchoolRequestOptions(),
  }) {
    throw UnsupportedError('이 테스트에서는 학교 서버 요청을 사용하지 않습니다.');
  }

  @override
  Future<Response<T>> post<T>(
    String target, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    SchoolRequestOptions options = const SchoolRequestOptions(),
  }) {
    throw UnsupportedError('이 테스트에서는 학교 서버 요청을 사용하지 않습니다.');
  }

  @override
  Future<void> clearAuthSession() async {}

  @override
  Future<bool> hasAuthSession() async => false;

  @override
  Future<bool> hasCookie(Uri target, String name) async => false;

  @override
  Future<void> saveAuthCookies(List<Cookie> cookies) async {}
}
