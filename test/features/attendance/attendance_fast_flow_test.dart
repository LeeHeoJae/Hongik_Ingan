import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hongik_ingan/features/attendance/application/attendance_controller.dart';
import 'package:hongik_ingan/features/attendance/application/attendance_data_source.dart';
import 'package:hongik_ingan/features/attendance/debug/attendance_test_environment.dart';
import 'package:hongik_ingan/features/home/application/home_controller.dart';

void main() {
  late AttendanceTestTransport transport;
  late ProviderContainer container;
  late AttendanceController controller;
  late DateTime now;
  late Future<Position> Function() locate;

  Position position() => Position(
    latitude: 37.551,
    longitude: 126.925,
    timestamp: now,
    accuracy: 1,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );

  setUp(() async {
    now = DateTime(2026, 10, 12, 10);
    locate = () async => position();
    transport = AttendanceTestTransport(latency: Duration.zero);
    container = ProviderContainer(
      overrides: [
        attendanceTransportProvider.overrideWithValue(transport),
        homeControllerProvider.overrideWith(_Home.new),
        attendanceProvider.overrideWith(
          () => AttendanceController(
            now: () => now,
            locationProvider: () => locate(),
          ),
        ),
      ],
    );
    controller = container.read(attendanceProvider.notifier);
    controller.deferFlowRefresh = true;
    await controller.fetchLecture();
  });

  tearDown(() => container.dispose());

  test('only a recent and parseable page can replace lecture data', () {
    expect(controller.useAttendancePage('not a lecture page', now), isFalse);
    expect(container.read(attendanceProvider).currentLecture, isNotNull);
    final receivedAt = now;
    now = now.add(const Duration(seconds: 16));
    expect(
      controller.useAttendancePage(
        '<table><tbody></tbody></table>',
        receivedAt,
      ),
      isFalse,
    );
    expect(container.read(attendanceProvider).currentLecture, isNotNull);
  });

  test(
    'uses the discovered lecture while location starts during input',
    () async {
      final code = Completer<String?>();
      final location = Completer<Position>();
      var locationStarted = false;
      locate = () {
        locationStarted = true;
        return location.future;
      };

      final submission = controller.performAttendance(
        requestAuthCode: () => code.future,
        canContinue: () => true,
      );
      expect(locationStarted, isTrue);
      expect(transport.lectureRequests, 1);
      expect(transport.submissions, isEmpty);
      location.complete(position());
      code.complete('1234');
      expect((await submission)?.isConfirmedAttendance, isTrue);
      expect(transport.submissions, hasLength(1));
    },
  );

  test('old prepared location is refreshed after long input', () async {
    final code = Completer<String?>();
    var locationCalls = 0;
    locate = () async {
      locationCalls++;
      return position();
    };
    final submission = controller.performAttendance(
      requestAuthCode: () => code.future,
      canContinue: () => true,
    );
    await Future<void>.delayed(Duration.zero);
    now = now.add(const Duration(seconds: 16));
    code.complete('1234');
    expect((await submission)?.isConfirmedAttendance, isTrue);
    expect(locationCalls, 2);
    expect(transport.lectureRequests, 1);
  });

  test('long input still submits the discovered lecture', () async {
    final code = Completer<String?>();
    final submission = controller.performAttendance(
      requestAuthCode: () => code.future,
      canContinue: () => true,
    );
    await Future<void>.delayed(Duration.zero);
    now = now.add(const Duration(seconds: 16));
    code.complete('1234');

    expect((await submission)?.isConfirmedAttendance, isTrue);
    expect(transport.lectureRequests, 1);
    expect(transport.submissions, hasLength(1));
  });

  test(
    'cancelled input ignores a location failure and sends nothing',
    () async {
      final code = Completer<String?>();
      final location = Completer<Position>();
      locate = () => location.future;
      final submission = controller.performAttendance(
        requestAuthCode: () => code.future,
        canContinue: () => true,
      );
      code.complete(null);
      expect(await submission, isNull);
      location.completeError(StateError('location unavailable'));
      await Future<void>.delayed(Duration.zero);
      expect(transport.submissions, isEmpty);
    },
  );

  test('session change while entering code prevents submission', () async {
    final code = Completer<String?>();
    final submission = controller.performAttendance(
      requestAuthCode: () => code.future,
      canContinue: () => true,
    );
    await container.read(homeControllerProvider.notifier).logout();
    code.complete('1234');
    expect(await submission, isNull);
    expect(transport.submissions, isEmpty);
  });
}

class _Home extends HomeController {
  @override
  HomeState build() => const HomeState(isLoggedIn: true, userId: 'student');

  @override
  Future<void> logout() async {
    ref.read(attendanceProvider.notifier).resetSession();
    state = const HomeState();
  }
}
