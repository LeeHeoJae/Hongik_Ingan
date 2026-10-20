import 'dart:math' as math;
import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/core/theme/color.dart';
import 'package:hongik_ingan/core/theme/theme.dart';
import 'package:hongik_ingan/features/home/presentation/widgets/home_attendance_action_layout.dart';
import 'package:hongik_ingan/features/home/presentation/widgets/login_form.dart';

void main() {
  late TextEditingController idController;
  late TextEditingController passwordController;

  setUp(() {
    idController = TextEditingController();
    passwordController = TextEditingController();
  });

  tearDown(() {
    idController.dispose();
    passwordController.dispose();
  });

  Widget buildSubject({
    VoidCallback? onLogin,
    ValueChanged<bool>? onRememberMeChanged,
    ValueChanged<bool>? onAutoLoginChanged,
    bool isLoading = false,
    bool rememberMe = false,
    bool autoLogin = false,
    bool dark = false,
    bool reducedMotion = false,
    double? textScale,
    double? keyboardInset,
    double topSpace = 0,
    bool adaptiveLayout = false,
  }) {
    final theme = dark ? darkThemeData : themeData;
    final app = MaterialApp(
      theme: theme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: textScale == null ? null : TextScaler.linear(textScale),
          disableAnimations: reducedMotion,
          viewInsets: keyboardInset == null
              ? null
              : EdgeInsets.only(bottom: keyboardInset),
        ),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          child: Material(
            color: theme.extension<HongikPalette>()!.cardSurface,
            child: Padding(
              padding: EdgeInsets.only(top: topSpace),
              child: LoginForm(
                layoutBuilder: adaptiveLayout
                    ? (content, action) => HomeAttendanceActionLayout(
                        content: content,
                        action: action,
                      )
                    : null,
                idController: idController,
                pwController: passwordController,
                isLoading: isLoading,
                rememberMe: rememberMe,
                autoLogin: autoLogin,
                onRememberMeChanged: onRememberMeChanged ?? (_) {},
                onAutoLoginChanged: onAutoLoginChanged ?? (_) {},
                onLogin: onLogin ?? () {},
              ),
            ),
          ),
        ),
      ),
    );
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: LoginForm.handleScrollMetrics,
      child: app,
    );
  }

  testWidgets('login reveal animates and retargets from the current offset', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 634);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(buildSubject(topSpace: 260));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField).first);
    await tester.pumpAndSettle();
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    await tester.pumpWidget(buildSubject(topSpace: 260, keyboardInset: 359));
    await tester.pump();
    await tester.pump();
    final start = position.pixels;
    await tester.pump(const Duration(milliseconds: 80));
    final midway = position.pixels;
    expect(midway, greaterThan(start));
    await tester.pumpWidget(buildSubject(topSpace: 260, keyboardInset: 399));
    await tester.pump();
    expect(position.pixels, closeTo(midway, 0.5));
    await tester.pumpAndSettle();
    expect(position.pixels, greaterThan(midway));
    expect(
      tester.getRect(find.byType(TextField).first).top,
      greaterThanOrEqualTo(0),
    );
    expect(
      tester.getRect(find.byType(TextField).last).bottom,
      lessThanOrEqualTo(235),
    );
  });

  testWidgets('login reveal respects reduced motion', (tester) async {
    tester.view.physicalSize = const Size(390, 634);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(buildSubject(topSpace: 260, reducedMotion: true));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField).first);
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      buildSubject(topSpace: 260, keyboardInset: 359, reducedMotion: true),
    );
    await tester.pump();
    final rect = tester.getRect(find.byType(TextField).last);
    expect(rect.bottom, lessThanOrEqualTo(275));
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.getRect(find.byType(TextField).last), rect);
  });

  for (final width in [390.0, 1204.0]) {
    for (final overlay in [false, true]) {
      testWidgets(
        'keyboard shows both complete fields width=$width overlay=$overlay',
        (tester) async {
          tester.view.physicalSize = Size(width, 634);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetViewInsets);
          await tester.pumpWidget(buildSubject(topSpace: 260));
          await tester.pumpAndSettle();
          final id = find.byType(TextField).first;
          final password = find.byType(TextField).last;
          await tester.tap(id);
          if (overlay) {
            await tester.pumpWidget(
              buildSubject(topSpace: 260, keyboardInset: 359),
            );
          } else {
            tester.view.viewInsets = const FakeViewPadding(bottom: 359);
          }
          await tester.pumpAndSettle();
          void expectPairVisible() {
            for (final field in [id, password]) {
              expect(tester.getRect(field).top, greaterThanOrEqualTo(0));
              expect(tester.getRect(field).bottom, lessThanOrEqualTo(275));
              expect(field.hitTestable(), findsOneWidget);
            }
          }

          expectPairVisible();
          final before = tester.getRect(id);
          await tester.tap(password);
          await tester.pumpAndSettle();
          expectPairVisible();
          expect(tester.getRect(id), before);
          expect(
            tester.widget<TextField>(password).focusNode!.hasFocus,
            isTrue,
          );
          await tester.enterText(password, 'test-only');
          await tester.pumpAndSettle();
          expectPairVisible();
          expect(passwordController.text, 'test-only');
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'short keyboard viewport prioritizes the complete focused field',
    (tester) async {
      tester.view.physicalSize = const Size(390, 634);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(buildSubject(topSpace: 260, textScale: 2));
      await tester.pumpAndSettle();
      final id = find.byType(TextField).first;
      await tester.tap(id);
      await tester.pumpWidget(
        buildSubject(topSpace: 260, textScale: 2, keyboardInset: 534),
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(id).top, greaterThanOrEqualTo(0));
      expect(tester.getRect(id).bottom, lessThanOrEqualTo(100));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'initial login fields are visible immediately without an entrance fade',
    (tester) async {
      await tester.pumpWidget(buildSubject());
      for (final fade in tester.widgetList<FadeTransition>(
        find.ancestor(
          of: find.byType(TextField).first,
          matching: find.byType(FadeTransition),
        ),
      )) {
        expect(fade.opacity.value, 1);
      }
      expect(find.byType(TextField).hitTestable(), findsNWidgets(2));
    },
  );

  testWidgets('입력 폭에 관계없이 학번 아래에 비밀번호를 배치한다', (tester) async {
    tester.view.physicalSize = const Size(520, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'C211136');
    await tester.enterText(find.byType(TextField).last, 'password');
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    expect(
      tester.getRect(fields.last).top,
      greaterThan(tester.getRect(fields.first).bottom),
    );
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(460, 600);
    await tester.pumpAndSettle();
    expect(
      tester.getRect(fields.last).top,
      greaterThan(tester.getRect(fields.first).bottom),
    );
    expect(find.text('통합 로그인'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('학번 다음 동작은 비밀번호로 이동하고 완료 동작은 로그인한다', (tester) async {
    var loginCount = 0;
    await tester.pumpWidget(buildSubject(onLogin: () => loginCount++));
    await tester.pumpAndSettle();

    final fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    expect(fields[0].textInputAction, TextInputAction.next);
    expect(fields[0].autofillHints, contains(AutofillHints.username));
    expect(fields[0].autocorrect, isFalse);
    expect(fields[0].enableSuggestions, isFalse);
    expect(fields[1].textInputAction, TextInputAction.done);
    expect(fields[1].autofillHints, contains(AutofillHints.password));

    await tester.tap(find.byType(TextField).first);
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
    expect(fields[1].focusNode!.hasFocus, isTrue);

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(loginCount, 1);
  });

  for (final width in [390.0, 1200.0]) {
    for (final filled in [false, true]) {
      testWidgets('login tab order at width $width, filled: $filled', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        if (filled) {
          idController.text = 'C211136';
          passwordController.text = 'password';
        }
        await tester.pumpWidget(buildSubject(adaptiveLayout: true));
        await tester.pumpAndSettle();
        final fields = tester
            .widgetList<TextField>(find.byType(TextField))
            .toList();
        final targets = <FocusNode>[
          fields.first.focusNode!,
          fields.last.focusNode!,
          Focus.of(tester.element(find.text('통합 로그인'))),
          if (filled) Focus.of(tester.element(find.byIcon(Icons.cancel).first)),
          if (filled) Focus.of(tester.element(find.byIcon(Icons.cancel).last)),
          Focus.of(tester.element(find.byIcon(Icons.visibility_off))),
          Focus.of(tester.element(find.text('정보 저장'))),
          Focus.of(tester.element(find.text('자동 로그인'))),
          Focus.of(tester.element(find.text('로그인 정보 처리 안내'))),
        ];
        targets.first.requestFocus();
        await tester.pump();
        for (final target in targets.skip(1)) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          expect(target.hasPrimaryFocus, isTrue);
        }
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        for (final target in targets.reversed.skip(1)) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          expect(target.hasPrimaryFocus, isTrue);
        }
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
    'keyboard done and a button tap before loading rebuild log in once',
    (tester) async {
      var loginCount = 0;
      await tester.pumpWidget(buildSubject(onLogin: () => loginCount++));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'C211136');
      await tester.enterText(find.byType(TextField).last, 'keyboard-password');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.tap(find.widgetWithText(ElevatedButton, '통합 로그인'));
      expect(loginCount, 1);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, '통합 로그인'));
      expect(loginCount, 2);
    },
  );

  testWidgets(
    'first login tap with keyboard open preserves values and dismisses focus',
    (tester) async {
      tester.view.physicalSize = const Size(390, 620);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      var loginCount = 0;
      await tester.pumpWidget(buildSubject(onLogin: () => loginCount++));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'C211136');
      await tester.enterText(find.byType(TextField).last, 'keyboard-password');
      tester.view.viewInsets = const FakeViewPadding(bottom: 320);
      await tester.pumpAndSettle();
      final login = find.widgetWithText(ElevatedButton, '통합 로그인');
      await tester.ensureVisible(login);
      await tester.pumpAndSettle();
      expect(login.hitTestable(), findsOneWidget);
      await tester.tap(login);
      await tester.pumpAndSettle();
      expect(loginCount, 1);
      expect(idController.text, 'C211136');
      expect(passwordController.text, 'keyboard-password');
      expect(
        tester
            .widget<TextField>(find.byType(TextField).last)
            .focusNode!
            .hasFocus,
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'password visibility keeps focus and selection across keyboard changes',
    (tester) async {
      tester.view.physicalSize = const Size(390, 620);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'keyboard-password');
      passwordController.selection = const TextSelection.collapsed(offset: 3);
      tester.view.viewInsets = const FakeViewPadding(bottom: 320);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('비밀번호 표시'));
      await tester.pumpAndSettle();
      var field = tester.widget<TextField>(find.byType(TextField).last);
      expect(field.obscureText, isFalse);
      expect(field.focusNode!.hasFocus, isTrue);
      expect(passwordController.selection.baseOffset, 3);
      tester.view.physicalSize = const Size(620, 320);
      tester.view.viewInsets = const FakeViewPadding(bottom: 160);
      await tester.pumpAndSettle();
      field = tester.widget<TextField>(find.byType(TextField).last);
      expect(field.focusNode!.hasFocus, isTrue);
      expect(passwordController.text, 'keyboard-password');
      expect(passwordController.selection.baseOffset, 3);
      await tester.ensureVisible(find.byTooltip('비밀번호 숨기기'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('비밀번호 숨기기'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField).last).obscureText,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets('compact login options fit and grow with text scale $scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(buildSubject(textScale: scale));
      await tester.pumpAndSettle();
      for (final label in ['정보 저장', '자동 로그인']) {
        final text = find.text(label);
        final control = find
            .ancestor(of: text, matching: find.byType(InkWell))
            .first;
        final rect = tester.getRect(control);
        expect(rect.height, scale == 1 ? 32 : greaterThan(32));
        expect(rect.top, lessThanOrEqualTo(tester.getRect(text).top));
        expect(rect.bottom, greaterThanOrEqualTo(tester.getRect(text).bottom));
        expect(tester.widget<Text>(text).style!.fontSize, 13);
      }
      final info = find.widgetWithText(TextButton, '로그인 정보 처리 안내');
      expect(tester.getSize(info).height, scale == 1 ? 32 : greaterThan(32));
      await tester.tap(info);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('정보 저장과 자동 로그인 선택은 각각의 콜백만 호출한다', (tester) async {
    var rememberChangeCount = 0;
    var autoLoginChangeCount = 0;
    await tester.pumpWidget(
      buildSubject(
        onRememberMeChanged: (_) => rememberChangeCount++,
        onAutoLoginChanged: (_) => autoLoginChangeCount++,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('자동 로그인'));
    await tester.pump();

    expect(autoLoginChangeCount, 1);
    expect(rememberChangeCount, 0);
  });

  testWidgets('좁은 화면과 큰 글자에서도 저장 옵션을 모두 표시한다', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: buildSubject(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('정보 저장'), findsOneWidget);
    expect(find.text('자동 로그인'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'credential info opens and closes immediately with reduced motion',
    (tester) async {
      await tester.pumpWidget(buildSubject(reducedMotion: true));
      await tester.tap(find.text('로그인 정보 처리 안내'));
      await tester.pump();
      final route = ModalRoute.of(tester.element(find.byType(AlertDialog)))!;
      expect(route.animation!.value, 1);
      route.navigator!.pop();
      await tester.pump();
      await tester.pump();
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('로그인 정보 처리 안내를 확인할 수 있다', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.text('로그인 정보 처리 안내'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('공식 앱이 아닌'), findsOneWidget);
    expect(find.text('자동 로그인 주의'), findsOneWidget);
    expect(find.text('소스 코드 보기'), findsOneWidget);
  });

  testWidgets('저장 옵션은 이름과 상태를 가진 하나의 조작 영역으로 동작한다', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      var rememberMe = false;
      var autoLogin = false;
      var rememberCount = 0;
      var autoLoginCount = 0;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) => buildSubject(
            rememberMe: rememberMe,
            autoLogin: autoLogin,
            onRememberMeChanged: (value) => setState(() {
              rememberMe = value;
              rememberCount++;
            }),
            onAutoLoginChanged: (value) => setState(() {
              autoLogin = value;
              autoLoginCount++;
            }),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final rememberNode = tester.getSemantics(find.byType(Checkbox).first);
      expect(
        rememberNode,
        isSemantics(
          label: '정보 저장',
          hasCheckedState: true,
          isChecked: false,
          hasTapAction: true,
        ),
      );
      expect(tester.getSemantics(find.text('정보 저장')).id, rememberNode.id);
      rememberNode.owner!.performAction(rememberNode.id, SemanticsAction.tap);
      await tester.pumpAndSettle();
      expect(rememberMe, isTrue);
      expect(rememberCount, 1);
      expect(
        tester.getSemantics(find.byType(Checkbox).first),
        isSemantics(label: '정보 저장', isChecked: true),
      );

      Focus.of(tester.element(find.text('정보 저장'))).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(rememberMe, isFalse);
      expect(rememberCount, 2);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(Focus.of(tester.element(find.text('자동 로그인'))).hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(autoLogin, isTrue);
      expect(autoLoginCount, 1);
      expect(
        tester.getSemantics(find.byType(Checkbox).last),
        isSemantics(label: '자동 로그인', isChecked: true),
      );
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      expect(rememberMe, isTrue);
      expect(rememberCount, 3);
      expect(autoLoginCount, 1);
    } finally {
      semantics.dispose();
    }
  });

  for (final dark in [false, true]) {
    testWidgets('로그인 중 작업 이름을 유지하고 중복 실행을 막는다 (dark: $dark)', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      try {
        var loginCount = 0;
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: buildSubject(
              dark: dark,
              isLoading: true,
              onLogin: () => loginCount++,
            ),
          ),
        );
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('로그인 중'), findsOneWidget);
        expect(
          tester.getSemantics(find.byType(ElevatedButton)),
          isSemantics(label: '로그인 중', isEnabled: false),
        );
        expect(
          tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
          isNull,
        );
        await tester.ensureVisible(find.byType(ElevatedButton));
        await tester.tap(find.byType(ElevatedButton));
        await tester.ensureVisible(find.byType(TextField).last);
        await tester.tap(find.byType(TextField).last);
        await tester.pump();
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();
        expect(loginCount, 0);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('로그인 옵션과 텍스트 버튼이 대비 기준을 충족한다 (dark: $dark)', (tester) async {
      await tester.pumpWidget(buildSubject(dark: dark));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(LoginForm));
      final theme = Theme.of(context);
      final background = theme.extension<HongikPalette>()!.cardSurface;
      for (final label in ['정보 저장', '자동 로그인']) {
        final color = tester.widget<Text>(find.text(label)).style!.color!;
        expect(_contrastRatio(color, background), greaterThanOrEqualTo(4.5));
      }
      for (final checkbox in tester.widgetList<Checkbox>(
        find.byType(Checkbox),
      )) {
        expect(
          _contrastRatio(checkbox.side!.color, background),
          greaterThanOrEqualTo(3),
        );
      }
      final button = tester.widget<TextButton>(
        find.widgetWithText(TextButton, '로그인 정보 처리 안내'),
      );
      final buttonColor =
          button.style?.foregroundColor?.resolve({}) ??
          theme.textButtonTheme.style!.foregroundColor!.resolve({})!;
      expect(
        _contrastRatio(buttonColor, background),
        greaterThanOrEqualTo(4.5),
      );
    });
  }
}

double _contrastRatio(Color foreground, Color background) {
  final foregroundLuminance = foreground.computeLuminance();
  final backgroundLuminance = background.computeLuminance();
  return (math.max(foregroundLuminance, backgroundLuminance) + 0.05) /
      (math.min(foregroundLuminance, backgroundLuminance) + 0.05);
}
