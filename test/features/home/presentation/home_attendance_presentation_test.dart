import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/features/attendance/application/attendance_controller.dart';
import 'package:hongik_ingan/features/attendance/domain/attendance_request_record.dart';
import 'package:hongik_ingan/features/attendance/domain/lecture.dart';
import 'package:hongik_ingan/features/home/presentation/home_attendance_presentation.dart';
import 'package:hongik_ingan/features/home/presentation/widgets/home_attendance_density.dart';

void main() {
  final lecture = Lecture(
    name: 'Current lecture',
    time: '10:00',
    attendanceParams: {'lecture': '1'},
  );
  final records = [
    for (var i = 0; i < 2; i++)
      AttendanceRequestRecord(
        id: '$i',
        lectureName: 'Previous lecture',
        requestedAt: DateTime.utc(2026, 10, 21, 1, i),
        authCode: '1234',
      ),
  ];

  HomeAttendancePresentation presentation({
    String userId = 'student',
    AttendanceState attendance = const AttendanceState(),
    List<AttendanceRequestRecord> history = const [],
  }) => HomeAttendancePresentation(
    isLoggedIn: true,
    recovering: false,
    userId: userId,
    attendance: attendance,
    history: AsyncData(history),
  );

  test(
    'new request records do not change the current lecture space budget',
    () {
      final attendance = AttendanceState(currentLecture: lecture);
      final before = presentation(attendance: attendance);
      final after = presentation(attendance: attendance, history: records);
      expect(after.showHistory, isFalse);
      expect(after.balanceSummary, isFalse);
      for (final density in HomeAttendanceDensity.values) {
        expect(after.heightReduction(density), before.heightReduction(density));
      }
    },
  );

  test('only a visible populated history summary receives balance space', () {
    final empty = presentation();
    final populated = presentation(history: records);
    expect(empty.showHistory, isTrue);
    expect(empty.balanceSummary, isFalse);
    expect(populated.showHistory, isTrue);
    expect(populated.balanceSummary, isTrue);
    expect(
      populated.heightReduction(HomeAttendanceDensity.tight),
      greaterThan(empty.heightReduction(HomeAttendanceDensity.tight)),
    );
  });

  test(
    'displayed data stays fixed until both interaction and keyboard close',
    () {
      final hold = HomeAttendancePresentationHold();
      final before = presentation(
        attendance: AttendanceState(currentLecture: lecture),
      );
      final live = presentation(history: records);
      hold.updateInteraction(true, before);
      expect(hold.resolveKeyboard(0), isTrue);
      final during = hold.resolve(live);
      expect(during.attendance, same(before.attendance));
      expect(during.history, same(before.history));
      expect(during.held, isTrue);
      hold.updateInteraction(false, live);
      expect(hold.resolveKeyboard(300), isTrue);
      expect(hold.resolve(live).attendance, same(before.attendance));
      expect(hold.resolveKeyboard(0), isFalse);
      expect(hold.resolve(live), same(live));
    },
  );

  test('a held snapshot is never displayed for another account', () {
    final hold = HomeAttendancePresentationHold();
    hold.updateInteraction(true, presentation(history: records));
    final otherAccount = presentation(userId: 'another-student');
    expect(hold.resolve(otherAccount), same(otherAccount));
    expect(hold.resolve(otherAccount).held, isFalse);
  });
}
