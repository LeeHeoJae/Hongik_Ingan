import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: LoginForm(
            idController: idController,
            pwController: passwordController,
            isLoading: false,
            rememberMe: false,
            autoLogin: false,
            onRememberMeChanged: onRememberMeChanged ?? (_) {},
            onAutoLoginChanged: onAutoLoginChanged ?? (_) {},
            onLogin: onLogin ?? () {},
          ),
        ),
      ),
    );
  }

  testWidgets('학번 다음 동작은 비밀번호로 이동하고 완료 동작은 로그인한다', (tester) async {
    var loginCount = 0;
    await tester.pumpWidget(buildSubject(onLogin: () => loginCount++));
    await tester.pumpAndSettle();

    final fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    expect(fields[0].textInputAction, TextInputAction.next);
    expect(fields[0].autofillHints, contains(AutofillHints.username));
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
}
