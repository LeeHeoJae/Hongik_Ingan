import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/features/home/application/home_controller.dart';
import 'package:hongik_ingan/features/home/presentation/home_service_summary_provider.dart';
import 'package:hongik_ingan/features/home/presentation/layouts/home_service_workspace.dart';
import 'package:hongik_ingan/features/seat/application/seat_controller.dart';
import 'package:hongik_ingan/features/seat/domain/seat.dart';

void main() {
  test('seat selection and other buildings do not notify the home summary', () {
    final seats = _Seats();
    final container = ProviderContainer(
      overrides: [seatControllerProvider.overrideWith(() => seats)],
    );
    addTearDown(container.dispose);
    var changes = 0;
    final provider = homeServiceSummaryProvider(HomeService.seat);
    container.listen(provider, (_, _) => changes++, fireImmediately: true);
    expect(container.read(provider).status, '좌석 조회 전');
    seats.change(
      SeatState(
        selectedLocation: SeatLocation.values.last,
        loadingLocations: {SeatLocation.values.last},
      ),
    );
    expect(container.read(provider).status, '좌석 조회 전');
    expect(changes, 1);
    seats.change(SeatState(loadingLocations: {SeatLocation.tBuilding}));
    expect(container.read(provider).status, '좌석 확인 중');
    expect(changes, 2);
  });

  test(
    'login preferences do not notify attendance summary, login progress does',
    () {
      final home = _Home();
      final container = ProviderContainer(
        overrides: [homeControllerProvider.overrideWith(() => home)],
      );
      addTearDown(container.dispose);
      var changes = 0;
      final provider = homeServiceSummaryProvider(HomeService.attendance);
      container.listen(provider, (_, _) => changes++, fireImmediately: true);
      expect(container.read(provider).status, '로그인 필요');
      home.change(const HomeState(rememberMe: true, autoLogin: true));
      expect(container.read(provider).status, '로그인 필요');
      expect(changes, 1);
      home.change(const HomeState(isLoading: true, statusMessage: 'Checking'));
      expect(container.read(provider).secondary, 'Checking');
      expect(changes, 2);
    },
  );

  test('equivalent visible summaries compare by value including facts', () {
    final first = HomeServiceSummaryData(
      status: 'Ready',
      facts: [(label: 'Next', value: 'Refresh')],
    );
    final second = HomeServiceSummaryData(
      status: 'Ready',
      facts: [(label: 'Next', value: 'Refresh')],
    );
    expect(first, second);
    expect(first.hashCode, second.hashCode);
    expect(first, isNot(const HomeServiceSummaryData(status: 'Changed')));
  });
}

class _Seats extends SeatController {
  @override
  SeatState build() => SeatState();
  void change(SeatState value) => state = value;
}

class _Home extends HomeController {
  @override
  HomeState build() => const HomeState();
  void change(HomeState value) => state = value;
}
