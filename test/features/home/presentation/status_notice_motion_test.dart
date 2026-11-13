import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/core/presentation/widgets/app_notice_transition.dart';
import 'package:hongik_ingan/features/attendance/domain/attendance_request_record.dart';
import 'package:hongik_ingan/features/attendance/presentation/attendance_history_summary.dart';

void main() {
  testWidgets(
    'notice fades while its layout and semantics change immediately',
    (tester) async {
      Widget subject(bool visible, {bool reduced = false}) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: Scaffold(
            body: Column(
              children: [
                AppNoticeTransition(
                  child: visible
                      ? const SizedBox(height: 40, child: Text('Notice'))
                      : null,
                ),
                const Text('Content'),
              ],
            ),
          ),
        ),
      );

      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(subject(false));
      final before = tester.getTopLeft(find.text('Content'));
      await tester.pumpWidget(subject(true));
      await tester.pump(const Duration(milliseconds: 90));
      expect(tester.getTopLeft(find.text('Content')).dy, before.dy + 40);
      final fade = tester.widget<FadeTransition>(
        find
            .ancestor(
              of: find.text('Notice'),
              matching: find.byType(FadeTransition),
            )
            .first,
      );
      expect(fade.opacity.value, inExclusiveRange(0.0, 1.0));
      await tester.pumpWidget(subject(false));
      expect(tester.getTopLeft(find.text('Content')), before);
      expect(find.bySemanticsLabel('Notice'), findsNothing);
      await tester.pumpAndSettle();
      await tester.pumpWidget(subject(true, reduced: true));
      await tester.pump();
      expect(find.bySemanticsLabel('Notice'), findsOneWidget);
      expect(tester.getTopLeft(find.text('Content')).dy, before.dy + 40);
      semantics.dispose();
    },
  );

  for (final reduced in [false, true]) {
    testWidgets('only a first new attendance record fades; reduced=$reduced', (
      tester,
    ) async {
      final record = AttendanceRequestRecord(
        id: '1',
        lectureName: 'Course',
        requestedAt: DateTime(2026),
        authCode: '1234',
      );
      Widget subject(List<AttendanceRequestRecord> records) => ProviderScope(
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(390, 800),
              disableAnimations: reduced,
            ),
            child: Scaffold(
              body: AttendanceHistorySummary(
                userId: 'student',
                historySnapshot: AsyncData(records),
              ),
            ),
          ),
        ),
      );

      await tester.pumpWidget(subject([]));
      await tester.pumpWidget(subject([record]));
      final recordFinder = find.byKey(
        const ValueKey('attendance-summary-record-1'),
      );
      final opacity = find.ancestor(
        of: recordFinder,
        matching: find.byType(Opacity),
      );
      if (reduced) {
        expect(opacity, findsNothing);
      } else {
        expect(tester.widget<Opacity>(opacity.first).opacity, 0);
        await tester.pump(const Duration(milliseconds: 60));
        expect(
          tester.widget<Opacity>(opacity.first).opacity,
          inExclusiveRange(0.0, 1.0),
        );
        await tester.pumpAndSettle();
        await tester.pumpWidget(subject([record]));
        expect(tester.widget<Opacity>(opacity.first).opacity, 1);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
