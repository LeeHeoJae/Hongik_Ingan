import 'package:hongik_ingan/features/app_install/data/app_install_bridge.dart';
import 'package:hongik_ingan/features/app_install/domain/app_install_state.dart';

AppInstallBridge createPlatformAppInstallBridge() =>
    const StubAppInstallBridge();

/// 웹이 아닌 환경에서 작동 안하도록.
class StubAppInstallBridge implements AppInstallBridge {
  const StubAppInstallBridge();

  @override
  AppInstallSnapshot get current =>
      const AppInstallSnapshot(AppInstallTarget.notWeb);

  @override
  Stream<AppInstallSnapshot> get states => const Stream.empty();

  @override
  Future<AppInstallPromptResult> prompt() async =>
      AppInstallPromptResult.unavailable;

  @override
  void dispose() {}
}
