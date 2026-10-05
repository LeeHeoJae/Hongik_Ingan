import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:hongik_ingan/features/attendance/domain/attendance_request_record.dart';

class AttendanceHistoryRepository {
  static const maxRecords = 20;

  Future<void> _writes = Future.value();

  String _key(String userId) =>
      'attendance_history_v1:${Uri.encodeComponent(userId)}';

  Future<List<AttendanceRequestRecord>> load(String userId) async {
    await _writes;
    return _read(await SharedPreferences.getInstance(), userId);
  }

  List<AttendanceRequestRecord> _read(SharedPreferences prefs, String userId) {
    final encoded = prefs.getString(_key(userId));
    if (encoded == null) return [];
    final records = (jsonDecode(encoded) as List)
        .map(
          (row) =>
              AttendanceRequestRecord.fromJson(row as Map<String, dynamic>),
        )
        .toList();
    records.sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
    return records.take(maxRecords).toList();
  }

  Future<void> save(String userId, AttendanceRequestRecord record) {
    // Serialize writes so the initial request cannot overwrite its final result.
    final write = _writes.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      final records = _read(prefs, userId)
        ..removeWhere((previous) => previous.id == record.id)
        ..insert(0, record);
      records.sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
      final saved = await prefs.setString(
        _key(userId),
        jsonEncode(
          records.take(maxRecords).map((row) => row.toJson()).toList(),
        ),
      );
      if (!saved) throw StateError('Attendance history could not be saved.');
    });
    // A failed write must not prevent the next request from being saved.
    _writes = write.catchError((Object _) {});
    return write;
  }
}
