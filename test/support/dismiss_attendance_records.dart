import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/features/attendance/presentation/attendance_records_view.dart';

Future<void> dismissAttendanceRecords(WidgetTester tester) async {
  expect(find.byType(AttendanceRecordsView), findsOneWidget);
  if (find.byType(BottomSheet).evaluate().isNotEmpty) {
    expect(find.bySemanticsLabel('닫기'), findsNothing);
    await tester.binding.handlePopRoute();
  } else {
    await tester.tap(find.bySemanticsLabel('닫기'));
  }
}
