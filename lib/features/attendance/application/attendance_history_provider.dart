import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hongik_ingan/features/attendance/data/attendance_history_repository.dart';
import 'package:hongik_ingan/features/attendance/domain/attendance_request_record.dart';

final attendanceHistoryRepositoryProvider =
    Provider<AttendanceHistoryRepository>(
      (ref) => AttendanceHistoryRepository(),
    );

final attendanceHistoryProvider = FutureProvider.autoDispose
    .family<List<AttendanceRequestRecord>, String>(
      (ref, userId) =>
          ref.watch(attendanceHistoryRepositoryProvider).load(userId),
    );
