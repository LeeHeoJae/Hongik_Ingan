import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/features/home/presentation/widgets/home_login_transition.dart';

void main() {
  testWidgets('login cross-fades while measuring only the incoming content', (
    tester,
  ) async {
    final loggedIn = ValueNotifier(false);
    addTearDown(loggedIn.dispose);
    await tester.pumpWidget(_subject(loggedIn));
    final loginElement = tester.element(find.text('Login'));
    expect(tester.getSize(find.byType(HomeLoginTransition)).height, 240);

    loggedIn.value = true;
    await tester.pump();
    expect(tester.element(find.text('Login')), same(loginElement));
    expect(tester.getSize(find.byType(HomeLoginTransition)).height, 80);
    expect(_fadeFor(tester, 'Attendance').opacity.value, 0);
    expect(_fadeFor(tester, 'Login').opacity.value, 1);
    expect(
      tester
          .widget<IgnorePointer>(
            find
                .ancestor(
                  of: find.text('Login'),
                  matching: find.byType(IgnorePointer),
                )
                .first,
          )
          .ignoring,
      isTrue,
    );
    expect(
      tester
          .widget<ExcludeSemantics>(
            find
                .ancestor(
                  of: find.text('Login'),
                  matching: find.byType(ExcludeSemantics),
                )
                .first,
          )
          .excluding,
      isTrue,
    );
    expect(
      tester
          .widget<ExcludeFocus>(
            find
                .ancestor(
                  of: find.text('Login'),
                  matching: find.byType(ExcludeFocus),
                )
                .first,
          )
          .excluding,
      isTrue,
    );

    await tester.pump(const Duration(milliseconds: 44));
    expect(
      _fadeFor(tester, 'Attendance').opacity.value,
      inExclusiveRange(0, 1),
    );
    expect(_fadeFor(tester, 'Login').opacity.value, inExclusiveRange(0, 1));
    expect(
      _fadeFor(tester, 'Attendance').opacity.value +
          _fadeFor(tester, 'Login').opacity.value,
      lessThanOrEqualTo(1),
    );
    await tester.pump(const Duration(milliseconds: 66));
    expect(_fadeFor(tester, 'Login').opacity.value, 0);
    expect(
      _fadeFor(tester, 'Attendance').opacity.value,
      inExclusiveRange(0, 1),
    );
    expect(tester.getSize(find.byType(HomeLoginTransition)).height, 80);
    await tester.pump(const Duration(milliseconds: 110));
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.text('Login'), findsNothing);
    expect(_fadeFor(tester, 'Attendance').opacity.value, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('logout interrupts a login fade without retaining attendance', (
    tester,
  ) async {
    final loggedIn = ValueNotifier(false);
    addTearDown(loggedIn.dispose);
    await tester.pumpWidget(_subject(loggedIn));
    loggedIn.value = true;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 64));
    loggedIn.value = false;
    await tester.pump();
    expect(find.text('Attendance'), findsNothing);
    expect(find.text('Login'), findsOneWidget);
    expect(_fadeFor(tester, 'Login').opacity.value, 1);
    expect(tester.getSize(find.byType(HomeLoginTransition)).height, 240);
    loggedIn.value = true;
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Login'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion switches immediately', (tester) async {
    final loggedIn = ValueNotifier(false);
    addTearDown(loggedIn.dispose);
    await tester.pumpWidget(_subject(loggedIn, reducedMotion: true));
    loggedIn.value = true;
    await tester.pump();
    expect(find.text('Login'), findsNothing);
    expect(_fadeFor(tester, 'Attendance').opacity.value, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an existing session appears immediately without a login fade', (
    tester,
  ) async {
    final loggedIn = ValueNotifier(true);
    addTearDown(loggedIn.dispose);
    await tester.pumpWidget(_subject(loggedIn));
    expect(_fadeFor(tester, 'Attendance').opacity.value, 1);
    expect(find.text('Login'), findsNothing);
    await tester.pump(const Duration(milliseconds: 64));
    expect(_fadeFor(tester, 'Attendance').opacity.value, 1);
  });

  testWidgets('enabling reduced motion finishes an active login fade', (
    tester,
  ) async {
    final loggedIn = ValueNotifier(false);
    addTearDown(loggedIn.dispose);
    await tester.pumpWidget(_subject(loggedIn));
    loggedIn.value = true;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 44));
    await tester.pumpWidget(_subject(loggedIn, reducedMotion: true));
    expect(find.text('Login'), findsNothing);
    expect(_fadeFor(tester, 'Attendance').opacity.value, 1);
    expect(tester.takeException(), isNull);
  });
}

FadeTransition _fadeFor(WidgetTester tester, String text) {
  return tester.widget<FadeTransition>(
    find
        .ancestor(of: find.text(text), matching: find.byType(FadeTransition))
        .first,
  );
}

Widget _subject(ValueNotifier<bool> loggedIn, {bool reducedMotion = false}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reducedMotion),
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 320,
          child: ValueListenableBuilder<bool>(
            valueListenable: loggedIn,
            builder: (context, value, child) => HomeLoginTransition(
              isLoggedIn: value,
              child: SizedBox(
                height: value ? 80 : 240,
                child: Text(value ? 'Attendance' : 'Login'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
