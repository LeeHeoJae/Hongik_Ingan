import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/features/home/presentation/widgets/home_login_transition.dart';
import 'package:hongik_ingan/features/home/presentation/widgets/home_content_size_reporter.dart';
import 'package:hongik_ingan/features/home/presentation/widgets/home_attendance_action_layout.dart';
import 'package:hongik_ingan/features/attendance/presentation/attendance_status_message.dart';

void main() {
  _authenticationRegressionTests();
  testWidgets('resolved initial session skips the login cross-fade', (
    tester,
  ) async {
    final loggedIn = ValueNotifier(false);
    addTearDown(loggedIn.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<bool>(
          valueListenable: loggedIn,
          builder: (context, value, child) => HomeLoginTransition(
            isLoggedIn: value,
            animateLogin: false,
            child: Text(value ? 'Attendance' : 'Restoring'),
          ),
        ),
      ),
    );
    loggedIn.value = true;
    await tester.pump();
    expect(find.text('Restoring'), findsNothing);
    expect(_fadeFor(tester, 'Attendance').opacity.value, 1);
  });

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

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 110));
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
    await tester.pump(const Duration(milliseconds: 224));
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

void _authenticationRegressionTests() {
  testWidgets(
    'stacked login paints within the card without remeasuring its gaps',
    (tester) async {
      tester.view.physicalSize = const Size(768, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var cardHeight = 400.0;
      var taps = 0;
      final heights = <double>[];
      Widget subject() => MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 520,
              child: HomeAttendanceCardScope(
                height: cardHeight,
                availableHeight: 900,
                child: HomeAttendanceActionScope(
                  bodyTop: 80,
                  bottomPadding: 16,
                  child: HomeContentSizeReporter(
                    onSize: (size) => heights.add(size.height),
                    child: HomeLoginBodyAnchor(
                      status: const AttendanceStatusMessage(
                        title: 'Login',
                        icon: Icons.lock,
                        descriptionViewportLines: 2,
                      ),
                      fields: const [
                        TextField(),
                        TextField(),
                        SizedBox(height: 32),
                      ],
                      action: SizedBox(
                        height: 44,
                        child: ElevatedButton(
                          onPressed: () => taps++,
                          child: const Text('Submit'),
                        ),
                      ),
                      hasStatusDescription: false,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(subject());
      final firstHeight = heights.single;
      final sizes = find
          .byType(TextField)
          .evaluate()
          .map((element) => tester.getSize(find.byWidget(element.widget)))
          .toList();
      cardHeight = 364;
      await tester.pumpWidget(subject());
      expect(heights, [firstHeight]);
      for (var i = 0; i < sizes.length; i++) {
        expect(tester.getSize(find.byType(TextField).at(i)), sizes[i]);
      }
      final action = find.widgetWithText(ElevatedButton, 'Submit');
      expect(tester.getRect(action).bottom, cardHeight - 96);
      expect(
        tester.getRect(find.byType(TextField).last).bottom,
        lessThan(tester.getRect(action).top),
      );
      await tester.tap(action);
      expect(taps, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('only the new body determines height during authentication', (
    tester,
  ) async {
    var loggedIn = false;
    final heights = <double>[];
    var taps = 0;
    Widget subject() => MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 320,
            child: HomeContentSizeReporter(
              onSize: (size) => heights.add(size.height),
              child: HomeLoginTransition(
                isLoggedIn: loggedIn,
                bottomAligned: true,
                child: SizedBox(
                  height: loggedIn ? 80 : 220,
                  child: TextButton(
                    onPressed: () => taps++,
                    child: Text(loggedIn ? 'Account' : 'Login'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(subject());
    loggedIn = true;
    await tester.pumpWidget(subject());
    expect(heights, [220, 80]);
    expect(find.text('Login'), findsOneWidget);
    expect(find.semantics.byLabel('Login'), findsNothing);
    await tester.tap(find.text('Login'), warnIfMissed: false);
    expect(taps, 0);
    final transition = find.byType(HomeLoginTransition);
    expect(tester.getSize(transition).height, 80);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 140));
    expect(heights, [220, 80]);
    final incoming = find.byKey(const ValueKey('home-login-incoming'));
    expect(
      tester.widget<FadeTransition>(incoming).opacity.value,
      inExclusiveRange(0, 1),
    );
    await tester.tap(find.text('Account'));
    expect(taps, 1);
    await tester.pump(const Duration(milliseconds: 260));
    await tester.pumpAndSettle();
    expect(find.text('Login'), findsNothing);
    semantics.dispose();
  });

  testWidgets(
    'logout immediately restores the form and drops account during login',
    (tester) async {
      var loggedIn = false;
      final controller = TextEditingController(text: 'saved input');
      addTearDown(controller.dispose);
      Widget subject({bool reduceMotion = false}) => MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(disableAnimations: reduceMotion),
            child: HomeLoginTransition(
              isLoggedIn: loggedIn,
              child: loggedIn
                  ? const Text('Private account')
                  : TextField(controller: controller),
            ),
          ),
        ),
      );
      await tester.pumpWidget(subject());
      final field = tester.element(find.byType(TextField));
      loggedIn = true;
      await tester.pumpWidget(subject());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 64));
      final outgoing = find
          .ancestor(
            of: find.byType(TextField),
            matching: find.byType(FadeTransition),
          )
          .first;
      final opacity = tester.widget<FadeTransition>(outgoing).opacity.value;
      expect(opacity, inExclusiveRange(0, 1));
      loggedIn = false;
      await tester.pumpWidget(subject());
      final incoming = find.byKey(const ValueKey('home-login-incoming'));
      expect(tester.widget<FadeTransition>(incoming).opacity.value, 1);
      expect(tester.element(find.byType(TextField)), same(field));
      expect(find.text('Private account'), findsNothing);
      expect(controller.text, 'saved input');
      await tester.pumpWidget(subject(reduceMotion: true));
      expect(tester.widget<FadeTransition>(incoming).opacity.value, 1);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('session restoration and recovery can skip entrance effects', (
    tester,
  ) async {
    var loggedIn = false;
    Widget subject() => MaterialApp(
      home: HomeLoginTransition(
        isLoggedIn: loggedIn,
        animateLogin: false,
        child: Text(loggedIn ? 'Account' : 'Login'),
      ),
    );
    await tester.pumpWidget(subject());
    final incoming = find.byKey(const ValueKey('home-login-incoming'));
    for (final next in [true, false, true]) {
      loggedIn = next;
      await tester.pumpWidget(subject());
      expect(tester.widget<FadeTransition>(incoming).opacity.value, 1);
      expect(find.text(next ? 'Login' : 'Account'), findsNothing);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
