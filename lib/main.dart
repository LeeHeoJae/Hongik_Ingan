import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hongik_ingan/core/network/school_transport_factory.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'core/app.dart';
import 'core/app_config.dart';
import 'core/app_info.dart';
import 'core/logging/logger.dart';
import 'core/logging/keyboard_diagnostics.dart';
import 'core/logging/startup_timeline.dart';
import 'core/network/school_transport_provider.dart';
import 'features/home/application/home_controller.dart';

Future<void> main() async {
  StartupTimeline.start();
  WidgetsFlutterBinding.ensureInitialized();
  initializeKeyboardViewport();

  await initLogger();
  StartupTimeline.mark('loggerReady');

  // 저장된 로그인 설정은 첫 화면 준비와 겹쳐서 미리 읽어 둔다.
  // 실패하면 HomeController가 시작할 때 다시 읽는다.
  unawaited(AppConfig().init().then((_) {}, onError: (Object _) {}));

  // 앱 정보와 학교 연결 준비는 서로 의존하지 않으므로 동시에 진행한다.
  final (packageInfo, transport) = await (
    PackageInfo.fromPlatform(),
    createSchoolTransport(),
  ).wait;
  AppInfo.initialize(packageInfo);
  StartupTimeline.mark('runApp');

  final container = ProviderContainer(
    overrides: [schoolTransportProvider.overrideWithValue(transport)],
  );
  // 세션 확인(학교 서버 요청)은 첫 화면이 그려지기를 기다리지 않고 바로 시작한다.
  container.read(homeControllerProvider.notifier).beginInitialRestore();

  runApp(UncontrolledProviderScope(container: container, child: const HIApp()));
  unawaited(
    WidgetsBinding.instance.waitUntilFirstFrameRasterized.then(
      (_) => StartupTimeline.mark('firstFrame'),
    ),
  );
}
