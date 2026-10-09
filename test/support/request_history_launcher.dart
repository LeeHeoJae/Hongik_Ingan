import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hongik_ingan/features/attendance/presentation/attendance_records_view.dart';

/// Opens the production request tab without imposing the home action's busy gate.
class RequestHistoryLauncher extends StatelessWidget {
  const RequestHistoryLauncher({super.key, this.userId = 'student'});
  final String userId;

  @override
  Widget build(BuildContext context) => TextButton(
    key: const ValueKey('attendance-history-button'),
    style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
    onPressed: () => unawaited(
      showAttendanceRecords(
        context,
        userId,
        initialTab: AttendanceRecordsTab.requests,
      ),
    ),
    child: const Text('Open request history'),
  );
}
