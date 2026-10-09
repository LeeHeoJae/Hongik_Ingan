import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/core/time/campus_clock.dart';
import 'package:hongik_ingan/features/attendance/domain/attendance_overview.dart';
import 'package:hongik_ingan/features/attendance/domain/attendance_week_target.dart';
import 'attendance_overview_test.dart' show testCourse;

void main() {
  test(
    'targets the dated school row for this week, preserving unentered rows',
    () {
      expect(
        _target({
          5: '09/29(화)',
          6: '10/08(목)',
          7: '미입력',
        }, DateTime.utc(2026, 10, 9)),
        (week: 6, isCurrentWeek: true),
      );
    },
  );
  test('an upcoming lecture within this week also identifies the row', () {
    expect(_target({6: '10/08(목)'}, DateTime.utc(2026, 10, 5)), (
      week: 6,
      isCurrentWeek: true,
    ));
  });
  test(
    'falls back to recent lecture without extrapolating an unentered week',
    () {
      expect(_target({6: '10/08(목)', 7: '미입력'}, DateTime.utc(2026, 10, 16)), (
        week: 6,
        isCurrentWeek: false,
      ));
    },
  );
  test('no valid dates or future-only semesters have no navigation target', () {
    for (final label in [
      '미입력',
      '-',
      '02/30(월)',
      '10/08(금)',
      '13/01(목)',
      '형식이 다른 원문',
    ]) {
      expect(_target({1: label}, DateTime.utc(2026, 10, 9)), isNull);
    }
    expect(_target({1: '10/20(화)'}, DateTime.utc(2026, 10, 9)), isNull);
  });
  test(
    'campus week rolls over at Korean midnight regardless of device zone',
    () {
      final labels = {6: '10/08(목)', 7: '10/13(화)'};
      expect(
        _target(labels, toCampusTime(DateTime.utc(2026, 10, 11, 14, 59))),
        (week: 6, isCurrentWeek: true),
      );
      expect(_target(labels, toCampusTime(DateTime.utc(2026, 10, 11, 15))), (
        week: 7,
        isCurrentWeek: true,
      ));
    },
  );
  test('second-semester January dates use the following calendar year', () {
    expect(_target({15: '01/04(월)'}, DateTime.utc(2027, 1, 4)), (
      week: 15,
      isCurrentWeek: true,
    ));
  });
  test(
    'ambiguous current rows use a clearly recent target; ties stay unavailable',
    () {
      expect(
        _target({5: '10/06(화)', 6: '10/08(목)'}, DateTime.utc(2026, 10, 9)),
        (week: 6, isCurrentWeek: false),
      );
      expect(
        _target({5: '10/08(목)', 6: '10/08(목)'}, DateTime.utc(2026, 10, 9)),
        isNull,
      );
    },
  );
}

AttendanceWeekTarget? _target(Map<int, String> labels, DateTime now) =>
    attendanceWeekTarget(
      SchoolAttendanceDetail(
        course: testCourse,
        isPublished: true,
        entries: [
          for (final entry in labels.entries)
            SchoolAttendanceEntry(
              week: entry.key,
              schedule: '목7',
              lectureLabel: entry.value,
              status: '-',
            ),
        ],
      ),
      now,
    );
