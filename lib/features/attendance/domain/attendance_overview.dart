class AttendanceCourseKey {
  const AttendanceCourseKey({
    required this.year,
    required this.semester,
    required this.courseCode,
    required this.section,
  });

  final String year;
  final String semester;
  final String courseCode;
  final String section;

  String get id => '$year:$semester:$courseCode:$section';
  String get termLabel => '$year-$semester';
  Map<String, String> toParams() => {
    'yy': year,
    'hakgi': semester,
    'haksu': courseCode,
    'bunban': section,
  };

  static AttendanceCourseKey? fromParams(Map<String, dynamic> params) {
    final values = [
      'yy',
      'hakgi',
      'haksu',
      'bunban',
    ].map((key) => params[key]?.toString().trim() ?? '').toList();
    if (values.any((value) => value.isEmpty) ||
        !RegExp(r'^\d{4}$').hasMatch(values[0]) ||
        !RegExp(r'^\d+$').hasMatch(values[2]) ||
        !RegExp(r'^\d+$').hasMatch(values[3])) {
      return null;
    }
    return AttendanceCourseKey(
      year: values[0],
      semester: values[1],
      courseCode: values[2],
      section: values[3],
    );
  }
}

class AttendanceCourse {
  const AttendanceCourse({
    required this.key,
    required this.name,
    required this.category,
  });

  final AttendanceCourseKey key;
  final String name;
  final String category;
  String get codeLabel => '${key.courseCode}-${key.section}';
}

class SchoolAttendanceEntry {
  const SchoolAttendanceEntry({
    required this.week,
    required this.schedule,
    required this.lectureLabel,
    required this.status,
  });

  final int week;
  final String schedule;
  final String lectureLabel;
  final String status;
}

class SchoolAttendanceDetail {
  const SchoolAttendanceDetail({
    required this.course,
    required this.isPublished,
    this.entries = const [],
  });

  final AttendanceCourse course;
  final bool isPublished;
  final List<SchoolAttendanceEntry> entries;
}
