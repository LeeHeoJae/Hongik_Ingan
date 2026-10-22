import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hongik_ingan/core/haptics/app_haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/core/theme/theme.dart';
import 'package:hongik_ingan/features/attendance/application/attendance_controller.dart';
import 'package:hongik_ingan/features/attendance/domain/attendance_submission_result.dart';
import 'package:hongik_ingan/features/attendance/domain/lecture.dart';
import 'package:hongik_ingan/features/attendance/presentation/attendance_code_form.dart';
import 'package:hongik_ingan/features/attendance/presentation/attendance_result_dialog.dart';
import 'package:hongik_ingan/features/attendance/presentation/attendance_section.dart';
import 'package:hongik_ingan/features/home/application/home_controller.dart';

void main() {
  for (final result in [
    const AttendanceSubmissionResult.notice('Attendance accepted'),
    const AttendanceSubmissionResult.notice('Attendance rejected'),
    const AttendanceSubmissionResult.unconfirmed('Response unavailable'),
    const AttendanceSubmissionResult.failure('Connection failed'),
  ]) {
    testWidgets('haptics follow processing errors only: ${result.message}', (
      tester,
    ) async {
      AppHaptics.instance.setActive(true);
      AppHaptics.instance.cancel();
      final effects = <String>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          effects.add(call.arguments as String);
        }
        return null;
      });
      addTearDown(() {
        AppHaptics.instance.cancel();
        messenger.setMockMethodCallHandler(SystemChannels.platform, null);
      });
      final controller = _Attendance();
      await tester.pumpWidget(_subject(controller, _Home(), []));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, '출결 번호 입력'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '1234');
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, '제출'));
      await tester.pump(const Duration(milliseconds: 240));
      effects.clear();
      AppHaptics.instance.cancel();
      controller.location.complete();
      controller.result.complete(result);
      await tester.pumpAndSettle();
      expect(
        effects,
        result.isError
            ? [
                'HapticFeedbackType.lightImpact',
                'HapticFeedbackType.lightImpact',
              ]
            : ['HapticFeedbackType.mediumImpact'],
      );
      await tester.tap(find.widgetWithText(ElevatedButton, '확인'));
      await tester.pumpAndSettle();
    });
  }

  for (final width in [390.0, 768.0, 1440.0]) {
    for (final outcome in ['fast', 'slow', 'location-error', 'unconfirmed']) {
      testWidgets('one attendance surface: $width $outcome', (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = _Attendance();
        final home = _Home();
        final holds = <bool>[];
        await tester.pumpWidget(_subject(controller, home, holds));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ElevatedButton, '출결 번호 입력'));
        await tester.pumpAndSettle();
        final surface = tester.element(find.byType(AttendanceCodeDialog));
        final route = ModalRoute.of(surface);
        expect(holds, [true]);
        await tester.enterText(find.byType(TextField), '1234');
        await tester.pump();
        final action = tester.element(
          find.widgetWithText(ElevatedButton, '제출'),
        );
        final actionWidth = tester
            .getSize(find.widgetWithText(ElevatedButton, '제출'))
            .width;
        final close = tester.element(find.bySemanticsLabel('닫기'));
        if (outcome == 'fast') {
          controller.location.complete();
          controller.result.complete(
            const AttendanceSubmissionResult.notice('Server notice'),
          );
        }
        await tester.tap(find.widgetWithText(ElevatedButton, '제출'));
        await tester.pump();
        expect(controller.submissions, 1);
        expect(
          tester.element(find.byType(AttendanceCodeDialog)),
          same(surface),
        );
        expect(ModalRoute.of(surface), same(route));
        if (outcome != 'fast') {
          await tester.pump(const Duration(milliseconds: 240));
          expect(find.text('위치를 확인하고 있어요.'), findsOneWidget);
          expect(find.byType(TextField), findsNothing);
          expect(
            tester.element(find.widgetWithText(ElevatedButton, '처리 중')),
            same(action),
          );
          expect(
            tester
                .widget<ElevatedButton>(
                  find.widgetWithText(ElevatedButton, '처리 중'),
                )
                .onPressed,
            isNull,
          );
          expect(tester.element(find.bySemanticsLabel('닫기')), same(close));
          await tester.binding.handlePopRoute();
          await tester.pump();
          expect(find.byType(AttendanceCodeDialog), findsOneWidget);
          if (outcome == 'location-error') {
            controller.location.completeError(
              Exception('Location unavailable'),
            );
          } else {
            controller.location.complete();
            await tester.pump();
            expect(find.text('출석을 제출하고 있어요.'), findsOneWidget);
            controller.result.complete(
              outcome == 'unconfirmed'
                  ? const AttendanceSubmissionResult.unconfirmed(
                      'Check school records',
                    )
                  : const AttendanceSubmissionResult.notice('Server notice'),
            );
          }
        }
        await tester.pumpAndSettle();
        expect(
          tester.element(find.byType(AttendanceCodeDialog)),
          same(surface),
        );
        expect(ModalRoute.of(surface), same(route));
        expect(find.byType(AttendanceResultDialog), findsOneWidget);
        expect(holds, [true]);
        final result = tester
            .widget<AttendanceResultDialog>(find.byType(AttendanceResultDialog))
            .result;
        expect(
          result.message,
          outcome == 'location-error'
              ? 'Location unavailable'
              : outcome == 'unconfirmed'
              ? 'Check school records'
              : 'Server notice',
        );
        final confirm = find.widgetWithText(ElevatedButton, '확인');
        expect(tester.element(confirm), same(action));
        expect(tester.getSize(confirm).width, actionWidth);
        expect(tester.element(find.bySemanticsLabel('닫기')), same(close));
        await tester.tap(confirm);
        await tester.pumpAndSettle();
        expect(find.byType(AttendanceCodeDialog), findsNothing);
        expect(holds, [true, false]);
        expect(controller.submissions, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
    'cancel and account changes do not leave a pending attendance window',
    (tester) async {
      final controller = _Attendance();
      final home = _Home();
      final holds = <bool>[];
      await tester.pumpWidget(_subject(controller, home, holds));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, '출결 번호 입력'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('닫기'));
      await tester.pumpAndSettle();
      expect(controller.submissions, 0);
      expect(holds, [true, false]);
      await tester.tap(find.widgetWithText(ElevatedButton, '출결 번호 입력'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '1234');
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, '제출'));
      await tester.pump(const Duration(milliseconds: 240));
      home.signOut();
      await tester.pumpAndSettle();
      expect(find.byType(AttendanceCodeDialog), findsNothing);
      controller.location.complete();
      await tester.pumpAndSettle();
      expect(find.byType(AttendanceResultDialog), findsNothing);
      expect(holds.last, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reduced motion shows even a long result in the same surface', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 620);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _Attendance();
    await tester.pumpWidget(
      _subject(controller, _Home(), [], reduceMotion: true, textScale: 2),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, '출결 번호 입력'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '1234');
    await tester.pump();
    controller.location.complete();
    controller.result.complete(
      AttendanceSubmissionResult.failure(
        List.filled(100, 'Long server message.').join(' '),
      ),
    );
    await tester.tap(find.widgetWithText(ElevatedButton, '제출'));
    await tester.pumpAndSettle();
    final confirm = find.widgetWithText(ElevatedButton, '확인');
    await tester.ensureVisible(confirm);
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(find.byType(AttendanceCodeDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Widget _subject(
  _Attendance attendance,
  _Home home,
  List<bool> holds, {
  bool reduceMotion = false,
  double textScale = 1,
}) => ProviderScope(
  overrides: [
    attendanceProvider.overrideWith(() => attendance),
    homeControllerProvider.overrideWith(() => home),
  ],
  child: MaterialApp(
    theme: themeData,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        disableAnimations: reduceMotion,
        textScaler: TextScaler.linear(textScale),
      ),
      child: child!,
    ),
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: AttendanceSection(onInteractionChanged: holds.add),
          ),
        ),
      ),
    ),
  ),
);

class _Home extends HomeController {
  @override
  HomeState build() => const HomeState(isLoggedIn: true, userId: 'student');
  void signOut() => state = const HomeState();
}

class _Attendance extends AttendanceController {
  final location = Completer<void>();
  final result = Completer<AttendanceSubmissionResult>();
  var submissions = 0;
  @override
  AttendanceState build() => AttendanceState(
    hasCheckedLecture: true,
    currentLecture: Lecture(
      name: 'Lecture',
      time: '12:00',
      attendanceParams: {},
    ),
  );
  @override
  Future<void> fetchLecture({
    bool forceRefresh = false,
    bool isAutomatic = false,
  }) async {}
  @override
  Future<AttendanceSubmissionResult?> performAttendance({
    required Future<String?> Function() requestAuthCode,
    required bool Function() canContinue,
    String? userId,
    Future<bool> Function(AttendanceSubmissionResult)? confirmUnconfirmedRetry,
  }) async {
    final code = await requestAuthCode();
    if (code == null || !canContinue()) return null;
    submissions++;
    state = state.copyWith(phase: AttendancePhase.locating);
    await location.future;
    if (!canContinue()) return null;
    state = state.copyWith(phase: AttendancePhase.submitting);
    final response = await result.future;
    if (!canContinue()) return null;
    state = AttendanceState(
      hasCheckedLecture: true,
      submissionResult: response,
    );
    return response;
  }
}
