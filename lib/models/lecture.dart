class Lecture {
  final String name;
  final String time;
  final Map<String, String> attendanceParams;

  Lecture({
    required this.name,
    required this.time,
    required this.attendanceParams,
  });

  @override
  String toString() {
    return 'Lecture{name: $name, time: $time, params: $attendanceParams}';
  }
}
