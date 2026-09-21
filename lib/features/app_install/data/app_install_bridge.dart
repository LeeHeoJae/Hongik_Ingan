import 'package:hongik_ingan/features/app_install/domain/app_install_state.dart';

import 'app_install_bridge_stub.dart'
    if (dart.library.js_interop) 'app_install_bridge_web.dart';

/// Controller가 웹, 네이티브를 몰라도 되도록 추상화.
abstract interface class AppInstallBridge {
  /// 지금 설치 상태.
  AppInstallSnapshot get current;

  /// 설치 상태 Stream.
  Stream<AppInstallSnapshot> get states;

  /// 설치 창 요청.
  Future<AppInstallPromptResult> prompt();

  void dispose();
}

AppInstallBridge createAppInstallBridge() => createPlatformAppInstallBridge();
