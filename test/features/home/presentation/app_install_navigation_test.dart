import 'dart:async';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/core/network/school_request_options.dart';
import 'package:hongik_ingan/core/network/school_transport.dart';
import 'package:hongik_ingan/core/network/school_transport_provider.dart';
import 'package:hongik_ingan/features/app_install/application/app_install_controller.dart';
import 'package:hongik_ingan/features/app_install/data/app_install_bridge.dart';
import 'package:hongik_ingan/features/app_install/domain/app_install_state.dart';
import 'package:hongik_ingan/features/home/presentation/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildSubject({
    AppInstallTarget target = AppInstallTarget.iosManual,
    AppInstallPromptResult promptResult = AppInstallPromptResult.unavailable,
    _FakeAppInstallBridge? bridge,
  }) {
    return ProviderScope(
      overrides: [
        schoolTransportProvider.overrideWithValue(_FakeSchoolTransport()),
        appInstallBridgeProvider.overrideWith(
          (ref) =>
              bridge ??
              _FakeAppInstallBridge(target: target, promptResult: promptResult),
        ),
      ],
      child: const MaterialApp(home: HomeScreen()),
    );
  }

  Future<void> openInstallGuide(WidgetTester tester) async {
    await tester.tap(find.byTooltip('앱 정보 및 문제 해결'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('설치 방법 보기'));
    await tester.pumpAndSettle();
    expect(find.text('iPhone 및 iPad'), findsOneWidget);
  }

  testWidgets('앱 정보에서 연 안내는 이전 버튼 없이 닫기로 종료한다', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();
    await openInstallGuide(tester);

    expect(find.text('이전'), findsNothing);
    await tester.tap(find.byTooltip('설치 안내 닫기'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('iPhone 및 iPad'), findsNothing);
  });

  testWidgets('직접 연 설치 안내를 닫으면 같은 세션에서 자동으로 다시 나타나지 않는다', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();
    await openInstallGuide(tester);

    await tester.tap(find.byTooltip('설치 안내 닫기'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('홍익인간을 앱으로 설치'), findsNothing);
    expect(find.text('iPhone 및 iPad'), findsNothing);
  });

  testWidgets('입력 중에는 자동 설치 권유를 숨기고 키보드를 닫으면 표시한다', (tester) async {
    tester.view.viewInsets = const FakeViewPadding(bottom: 180);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(buildSubject());
    await tester.pump();
    await tester.showKeyboard(find.byType(TextField).first);
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('홍익인간을 앱으로 설치'), findsNothing);

    tester.view.resetViewInsets();
    await tester.pumpAndSettle();

    expect(find.text('홍익인간을 앱으로 설치'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('표시 중인 설치 권유도 키보드가 열리면 숨긴다', (tester) async {
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(buildSubject());
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('홍익인간을 앱으로 설치'), findsOneWidget);

    tester.view.viewInsets = const FakeViewPadding(bottom: 180);
    await tester.pumpAndSettle();

    expect(find.text('홍익인간을 앱으로 설치'), findsNothing);

    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    expect(find.text('홍익인간을 앱으로 설치'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('설치 실패 후 안내도 닫으면 설치 권유가 다시 나타나지 않는다', (tester) async {
    await tester.pumpWidget(
      buildSubject(target: AppInstallTarget.nativePrompt),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    await tester.tap(find.text('앱 설치'));
    await tester.pumpAndSettle();
    expect(find.text('브라우저에서 직접 설치'), findsOneWidget);

    expect(find.text('이전'), findsNothing);
    await tester.tap(find.byTooltip('설치 안내 닫기'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('홍익인간을 앱으로 설치'), findsNothing);
    expect(find.text('브라우저에서 직접 설치'), findsNothing);
  });

  testWidgets('Firefox의 앱 정보는 주소창 안내를 직접 열며 설치 창을 호출하지 않는다', (tester) async {
    final bridge = _FakeAppInstallBridge(
      target: AppInstallTarget.windowsFirefoxManual,
      promptResult: AppInstallPromptResult.unavailable,
    );
    await tester.pumpWidget(buildSubject(bridge: bridge));
    await tester.pump();
    await tester.tap(find.byTooltip('앱 정보 및 문제 해결'));
    await tester.pumpAndSettle();

    expect(find.text('앱 설치'), findsNothing);
    expect(find.textContaining('주소창에서 앱으로 추가'), findsOneWidget);
    await tester.tap(find.text('설치 방법 보기'));
    await tester.pumpAndSettle();

    expect(find.text('Firefox에서 설치'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(bridge.promptCalls, 0);
  });

  for (final result in [
    AppInstallPromptResult.error,
    AppInstallPromptResult.unavailable,
  ]) {
    testWidgets('앱 정보의 설치 창 호출 실패는 현재 환경의 안내로 전환한다: $result', (tester) async {
      final bridge = _FakeAppInstallBridge(
        target: AppInstallTarget.nativePrompt,
        promptResult: result,
        targetAfterPrompt: AppInstallTarget.androidManual,
      );
      await tester.pumpWidget(buildSubject(bridge: bridge));
      await tester.pump();
      await tester.tap(find.byTooltip('앱 정보 및 문제 해결'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('앱 설치'));
      await tester.pumpAndSettle();

      expect(find.text('Android에서 설치'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('이전'), findsNothing);
      expect(bridge.promptCalls, 1);
      await tester.tap(find.byTooltip('설치 안내 닫기'));
      await tester.pumpAndSettle();
      expect(find.text('Android에서 설치'), findsNothing);
    });
  }

  testWidgets('안내 중 설치 완료 상태로 바뀌면 열린 안내를 숨긴다', (tester) async {
    final bridge = _FakeAppInstallBridge(
      target: AppInstallTarget.iosManual,
      promptResult: AppInstallPromptResult.unavailable,
    );
    await tester.pumpWidget(buildSubject(bridge: bridge));
    await tester.pump();
    await openInstallGuide(tester);
    bridge.setTarget(AppInstallTarget.installed);
    await tester.pumpAndSettle();

    expect(find.text('iPhone 및 iPad'), findsNothing);
    expect(find.byTooltip('설치 안내 닫기'), findsNothing);
  });
}

class _FakeAppInstallBridge implements AppInstallBridge {
  _FakeAppInstallBridge({
    required this.target,
    required this.promptResult,
    this.targetAfterPrompt,
  });

  AppInstallTarget target;
  final AppInstallPromptResult promptResult;
  final AppInstallTarget? targetAfterPrompt;
  final _states = StreamController<AppInstallSnapshot>.broadcast(sync: true);
  int promptCalls = 0;

  void setTarget(AppInstallTarget value) {
    target = value;
    _states.add(current);
  }

  @override
  AppInstallSnapshot get current => AppInstallSnapshot(target);

  @override
  Stream<AppInstallSnapshot> get states => _states.stream;

  @override
  Future<AppInstallPromptResult> prompt() async {
    promptCalls++;
    if (targetAfterPrompt case final next?) setTarget(next);
    return promptResult;
  }

  @override
  void dispose() => unawaited(_states.close());
}

class _FakeSchoolTransport implements SchoolTransport {
  @override
  Future<Response<T>> get<T>(
    String target, {
    Map<String, dynamic>? queryParameters,
    SchoolRequestOptions options = const SchoolRequestOptions(),
  }) {
    throw UnsupportedError('이 테스트에서는 학교 서버 요청을 사용하지 않습니다.');
  }

  @override
  Future<Response<T>> post<T>(
    String target, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    SchoolRequestOptions options = const SchoolRequestOptions(),
  }) {
    throw UnsupportedError('이 테스트에서는 학교 서버 요청을 사용하지 않습니다.');
  }

  @override
  Future<void> clearAuthSession() async {}

  @override
  Future<bool> hasAuthSession() async => false;

  @override
  Future<bool> hasCookie(Uri target, String name) async => false;

  @override
  Future<void> saveAuthCookies(List<Cookie> cookies) async {}
}
