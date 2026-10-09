import 'attendance_overview.dart';

typedef AttendanceWeekTarget = ({int week, bool isCurrentWeek});

/// Uses dated lectures, never an unentered cell or an assumed semester start.
AttendanceWeekTarget? attendanceWeekTarget(
  SchoolAttendanceDetail detail,
  DateTime campusTime,
) {
  final year = int.tryParse(detail.course.key.year);
  final semester = detail.course.key.semester;
  if (year == null || (semester != '1' && semester != '2')) return null;
  final today = DateTime.utc(campusTime.year, campusTime.month, campusTime.day);
  final monday = today.subtract(Duration(days: today.weekday - 1));
  final nextMonday = monday.add(const Duration(days: 7));
  final thisWeek = <int>{};
  DateTime? latestDate;
  final recentWeeks = <int>{};

  for (final entry in detail.entries) {
    final match = RegExp(
      r'^(\d{2})/(\d{2})\(([월화수목금토일])\)',
    ).firstMatch(entry.lectureLabel);
    if (match == null) continue;
    final month = int.parse(match[1]!);
    final day = int.parse(match[2]!);
    // January/February in the second academic semester belong to the next year.
    final date = DateTime.utc(
      year + (semester == '2' && month <= 2 ? 1 : 0),
      month,
      day,
    );
    if (date.month != month ||
        date.day != day ||
        date.weekday != '월화수목금토일'.indexOf(match[3]!) + 1) {
      continue;
    }
    if (!date.isBefore(monday) && date.isBefore(nextMonday)) {
      thisWeek.add(entry.week);
    }
    if (date.isAfter(today)) continue;
    if (latestDate == null || date.isAfter(latestDate)) {
      latestDate = date;
      recentWeeks.clear();
    }
    if (date == latestDate) recentWeeks.add(entry.week);
  }
  if (thisWeek.length == 1) return (week: thisWeek.single, isCurrentWeek: true);
  if (recentWeeks.length == 1) {
    return (week: recentWeeks.single, isCurrentWeek: false);
  }
  return null;
}
