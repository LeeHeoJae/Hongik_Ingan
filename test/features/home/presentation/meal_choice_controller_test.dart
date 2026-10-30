import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/core/time/campus_clock.dart';
import 'package:hongik_ingan/features/attendance/application/attendance_controller.dart';
import 'package:hongik_ingan/features/cafeteria_menu/application/cafeteria_menu_controller.dart';
import 'package:hongik_ingan/features/cafeteria_menu/application/meal_choice_controller.dart';
import 'package:hongik_ingan/features/cafeteria_menu/data/meal_choice_service.dart';
import 'package:hongik_ingan/features/cafeteria_menu/domain/cafeteria_menu.dart';
import 'package:hongik_ingan/features/cafeteria_menu/presentation/widgets/meal_choice_controls.dart';
import 'package:hongik_ingan/features/home/application/home_controller.dart';
import 'package:hongik_ingan/features/home/presentation/home_attendance_presentation.dart';
import 'package:hongik_ingan/features/home/presentation/layouts/home_page_layout.dart';
import 'package:hongik_ingan/features/home/presentation/layouts/home_service_workspace.dart';
import 'package:hongik_ingan/features/home/presentation/widgets/home_campus_summary.dart';
import 'package:hongik_ingan/features/seat/application/seat_controller.dart';
import 'package:hongik_ingan/features/seat/domain/seat.dart';

const _today = '2026-10-26';
const _tomorrow = '2026-10-27';
const _meals = [
  MealMenu(
    type: MealType.lunch,
    time: '11:30~14:00',
    items: ['A'],
    option: 'A',
  ),
  MealMenu(
    type: MealType.lunch,
    time: '11:30~14:00',
    items: ['B'],
    option: 'B',
  ),
];

class _Votes extends MealChoiceService {
  final reads = <String>[];

  @override
  Future<LunchPoll?> fetch(
    String date, {
    bool force = false,
    bool fresh = false,
  }) async {
    reads.add(date);
    return LunchPoll(
      id: date,
      options: const {
        'A': ['A'],
        'B': ['B'],
      },
    );
  }
}

class _Menu extends CafeteriaMenuController {
  @override
  CafeteriaMenuState build() {
    final day = DateTime(2026, 10, 26);
    return CafeteriaMenuState(
      baseDate: day,
      selectedDate: day,
      dates: [day],
      menus: [
        DailyMenu(
          date: day,
          weekday: '월',
          cafeterias: const [
            CafeteriaMenu(name: '기숙사', priceInfo: '', meals: _meals),
          ],
        ),
      ],
    );
  }
}

class _Seats extends SeatController {
  @override
  SeatState build() => SeatState();

  @override
  Future<void> fetchStatusForLocation(
    SeatLocation location, {
    bool forceRefresh = false,
  }) async {}
}

class _Probe extends ConsumerWidget {
  const _Probe(this.date, {this.active = true});
  final String date;
  final bool active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (active) ref.watch(activeMealChoiceProvider(date));
    final poll = ref.watch(mealChoiceProvider(date)).poll;
    return Text(poll?.id ?? 'loading');
  }
}

void main() {
  testWidgets(
    'home switches polling from the summary date to the detail date',
    (tester) async {
      final service = _Votes();
      addTearDown(service.dispose);
      var primary = HomeService.attendance;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mealChoiceServiceProvider.overrideWithValue(service),
            campusClockProvider.overrideWithValue(
              () => DateTime(2026, 10, 26, 12),
            ),
            homeCampusTimeProvider.overrideWithValue(
              DateTime(2026, 10, 26, 12),
            ),
            cafeteriaMenuControllerProvider.overrideWith(_Menu.new),
            seatControllerProvider.overrideWith(_Seats.new),
            homeControllerProvider.overrideWithValue(const HomeState()),
            attendanceProvider.overrideWithValue(const AttendanceState()),
          ],
          child: MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) => HomePageLayout(
                presentation: const HomeAttendancePresentation(
                  isLoggedIn: false,
                  recovering: false,
                  userId: null,
                  attendance: AttendanceState(),
                  history: null,
                ),
                holdBackdrop: false,
                attendanceLayoutKey: 0,
                primaryService: primary,
                onPrimaryChanged: (service) =>
                    setState(() => primary = service),
                header: const SizedBox.shrink(),
                footer: const SizedBox.shrink(),
                installOverlay: const SizedBox.shrink(),
                detailBuilder: (context, service, isPrimary, animate, onSize) =>
                    service == HomeService.menu
                    ? MealChoiceControls(
                        date: DateTime(2026, 10, 27),
                        meals: _meals,
                        itemBuilder: (_) => const SizedBox(height: 20),
                        headerBuilder: (_) => const SizedBox.shrink(),
                      )
                    : const SizedBox(height: 100),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(service.reads, [_today]);

      await tester.tap(find.text(HomeService.menu.title));
      await tester.pumpAndSettle();
      expect(service.reads, [_today, _tomorrow]);
      await tester.pump(const Duration(seconds: 60));
      expect(service.reads, [_today, _tomorrow, _tomorrow]);
    },
  );

  testWidgets('active listeners share one refresh per date', (tester) async {
    final service = _Votes();
    addTearDown(service.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mealChoiceServiceProvider.overrideWithValue(service),
          campusClockProvider.overrideWithValue(
            () => DateTime(2026, 10, 26, 12),
          ),
        ],
        child: const MaterialApp(
          home: Column(
            children: [_Probe(_today), _Probe(_today), _Probe(_tomorrow)],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(service.reads.where((date) => date == _today).length, 1);
    expect(service.reads.where((date) => date == _tomorrow).length, 1);
    expect(find.text(_today), findsNWidgets(2));
    expect(find.text(_tomorrow), findsOneWidget);

    await tester.pump(const Duration(seconds: 60));
    expect(service.reads.where((date) => date == _today).length, 2);
    expect(service.reads.where((date) => date == _tomorrow).length, 2);
  });

  testWidgets('inactive dates and background do not refresh', (tester) async {
    final service = _Votes();
    addTearDown(service.dispose);
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );
    Widget subject(bool tomorrowActive) => ProviderScope(
      overrides: [
        mealChoiceServiceProvider.overrideWithValue(service),
        campusClockProvider.overrideWithValue(() => DateTime(2026, 10, 26, 12)),
      ],
      child: MaterialApp(
        home: Column(
          children: [
            _Probe(_today),
            _Probe(_tomorrow, active: tomorrowActive),
          ],
        ),
      ),
    );

    await tester.pumpWidget(subject(false));
    await tester.pump();
    expect(service.reads, [_today]);
    await tester.pumpWidget(subject(true));
    await tester.pump();
    expect(service.reads, [_today, _tomorrow]);
    await tester.pumpWidget(subject(false));
    await tester.pump();
    await tester.pump(const Duration(seconds: 60));
    expect(service.reads, [_today, _tomorrow, _today]);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 120));
    expect(service.reads, [_today, _tomorrow, _today]);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(service.reads, [_today, _tomorrow, _today, _today]);
  });
}
