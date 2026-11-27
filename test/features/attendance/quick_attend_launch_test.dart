import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/features/attendance/application/quick_attend_launch.dart';

class _FakeStopwatch implements Stopwatch {
  Duration value = Duration.zero;
  @override
  Duration get elapsed => value;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('recognizes the shortcut route only', () {
    expect(isQuickAttendRoute('/attend'), isTrue);
    expect(isQuickAttendRoute('/attend?from=shortcut'), isTrue);
    expect(isQuickAttendRoute('/'), isFalse);
    expect(isQuickAttendRoute('/attendance'), isFalse);
    expect(isQuickAttendRoute(''), isFalse);
  });

  test('is consumed once', () {
    final launch = QuickAttendLaunch(requested: true);
    expect(launch.isPending, isTrue);
    expect(launch.consume(), isTrue);
    expect(launch.consume(), isFalse);
    expect(launch.isPending, isFalse);
  });

  test('does nothing for a normal launch or after cancel', () {
    expect(QuickAttendLaunch(requested: false).consume(), isFalse);
    final launch = QuickAttendLaunch(requested: true)..cancel();
    expect(launch.consume(), isFalse);
  });

  test('expires after the waiting window', () {
    final clock = _FakeStopwatch();
    final launch = QuickAttendLaunch(requested: true, stopwatch: clock);
    clock.value = quickAttendWindow;
    expect(launch.isPending, isTrue);
    clock.value = quickAttendWindow + const Duration(milliseconds: 1);
    expect(launch.consume(), isFalse);
  });
}
