import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/features/home/application/home_controller.dart';
import 'package:hongik_ingan/features/home/domain/login_result.dart';
import 'package:hongik_ingan/features/home/presentation/widgets/security_code_dialog.dart';

class _HomeController extends HomeController {
  @override
  HomeState build() =>
      const HomeState(loginStatus: LoginStatus.securityCodeRequired);
}

void main() {
  testWidgets('keeps the code on failure and closes on success', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 667);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final pending = Completer<LoginResult?>();
    final submitted = <String>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [homeControllerProvider.overrideWith(_HomeController.new)],
        child: MaterialApp(
          theme: ThemeData.dark(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => SecurityCodeDialog(
                    onSubmit: (code) {
                      submitted.add(code);
                      return submitted.length == 1
                          ? pending.future
                          : Future.value(const LoginResult.success());
                    },
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final surface = find
        .descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(Material),
        )
        .first;
    expect(tester.getSize(surface).width, lessThanOrEqualTo(360));
    final code = find.widgetWithText(TextField, '보안코드 6자리');
    await tester.enterText(code, '001234');
    await tester.tap(find.text('확인하고 로그인'));
    await tester.pump();
    expect(submitted, ['001234']);
    expect(tester.widget<TextField>(code).readOnly, isTrue);
    expect(
      tester
          .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.close))
          .onPressed,
      isNull,
    );
    pending.complete(
      const LoginResult.failure(
        LoginFailureKind.securityCode,
        '보안코드 인증 결과를 확인하지 못했어요. 다시 시도해 주세요.',
      ),
    );
    await tester.pumpAndSettle();
    final error = find.text('보안코드 인증 결과를 확인하지 못했어요. 다시 시도해 주세요.');
    expect(error, findsOneWidget);
    expect(
      tester.renderObject<RenderParagraph>(error).didExceedMaxLines,
      isFalse,
    );
    expect(tester.widget<TextField>(code).controller!.text, '001234');
    await tester.tap(find.text('확인하고 로그인'));
    await tester.pumpAndSettle();
    expect(submitted, ['001234', '001234']);
    expect(code, findsNothing);
  });
}
