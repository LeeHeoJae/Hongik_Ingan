import 'package:flutter_riverpod/flutter_riverpod.dart';

DateTime toCampusTime(DateTime instant) =>
    instant.toUtc().add(const Duration(hours: 9));

DateTime currentCampusTime() => toCampusTime(DateTime.now());

String campusDateKey(DateTime date) {
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  return '${date.year}-${twoDigits(date.month)}-${twoDigits(date.day)}';
}

final campusClockProvider = Provider<DateTime Function()>(
  (ref) => currentCampusTime,
);
