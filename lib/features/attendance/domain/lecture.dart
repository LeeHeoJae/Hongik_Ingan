class Lecture {
  final String name;
  final String time;
  final Map<String, String> attendanceParams;

  Lecture({
    required this.name,
    required this.time,
    required Map<String, String> attendanceParams,
  }) : attendanceParams = Map.unmodifiable(attendanceParams);

  @override
  String toString() {
    return 'Lecture{name: $name, time: $time, params: $attendanceParams}';
  }
}
