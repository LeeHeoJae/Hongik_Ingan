import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hongik_ingan/features/attendance/data/attendance_history_repository.dart';
import 'package:hongik_ingan/features/attendance/domain/attendance_request_record.dart';
import 'attendance_data_source.dart';

final attendancePersistentHistoryRepositoryProvider =
    Provider<AttendanceHistoryRepository>(
      (ref) => AttendanceHistoryRepository(),
    );

final attendanceHistoryRepositoryProvider =
    Provider<AttendanceHistoryRepository>(
      (ref) =>
          ref.watch(attendanceDataSourceOverrideProvider)?.historyRepository ??
          ref.watch(attendancePersistentHistoryRepositoryProvider),
    );

final attendanceHistoryProvider = FutureProvider.autoDispose
    .family<List<AttendanceRequestRecord>, String>(
      (ref, userId) =>
          ref.watch(attendanceHistoryRepositoryProvider).load(userId),
    );
