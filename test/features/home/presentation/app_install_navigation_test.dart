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
  }) {
    return ProviderScope(
      overrides: [
        schoolTransportProvider.overrideWithValue(_FakeSchoolTransport()),
        appInstallBridgeProvider.overrideWith(
          (ref) =>
              _FakeAppInstallBridge(target: target, promptResult: promptResult),
        ),
      ],
      child: const MaterialApp(home: HomeScreen()),
    );
  }

  Future<void> openInstallGuide(WidgetTester tester) async {
    await tester.tap(find.byTooltip('앱 정보 및 문제 해결'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('앱 설치'));
    await tester.pumpAndSettle();
    expect(find.text('iPhone 및 iPad'), findsOneWidget);
  }

  testWidgets('앱 정보에서 연 설치 안내의 이전 버튼은 앱 정보로 돌아간다', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();
    await openInstallGuide(tester);

    await tester.tap(find.text('이전'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('개인이 개발한 홍익대학교 비공식 오픈소스 앱이에요.'), findsOneWidget);
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

  testWidgets('설치 실패 후 안내의 이전 버튼은 설치 권유 화면으로 돌아간다', (tester) async {
    await tester.pumpWidget(
      buildSubject(target: AppInstallTarget.nativePrompt),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    await tester.tap(find.text('앱 설치'));
    await tester.pumpAndSettle();
    expect(find.text('브라우저에서 직접 설치'), findsOneWidget);

    await tester.tap(find.text('이전'));
    await tester.pumpAndSettle();

    expect(find.text('설치 방법 보기'), findsOneWidget);
    expect(find.text('브라우저에서 직접 설치'), findsNothing);
  });
}

class _FakeAppInstallBridge implements AppInstallBridge {
  _FakeAppInstallBridge({required this.target, required this.promptResult});

  final AppInstallTarget target;
  final AppInstallPromptResult promptResult;

  @override
  AppInstallSnapshot get current => AppInstallSnapshot(target);

  @override
  Stream<AppInstallSnapshot> get states => const Stream.empty();

  @override
  Future<AppInstallPromptResult> prompt() async {
    return promptResult;
  }

  @override
  void dispose() {}
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
