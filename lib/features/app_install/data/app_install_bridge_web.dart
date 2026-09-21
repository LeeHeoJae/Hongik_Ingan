import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:hongik_ingan/features/app_install/data/app_install_bridge.dart';
import 'package:hongik_ingan/features/app_install/domain/app_install_state.dart';

@JS('hongikPwaInstall.getStateJson')
external JSString _getStateJson();

@JS('hongikPwaInstall.subscribe')
external void _subscribe(JSFunction listener);

@JS('hongikPwaInstall.unsubscribe')
external void _unsubscribe(JSFunction listener);

@JS('hongikPwaInstall.prompt')
external JSPromise<JSString> _prompt();

AppInstallBridge createPlatformAppInstallBridge() => WebAppInstallBridge();

/// Flutter가 브라우저에 무엇을 물어볼 수 있는지 정의.
class WebAppInstallBridge implements AppInstallBridge {
  WebAppInstallBridge() {
    _listener = ((JSString stateJson) {
      if (!_states.isClosed) {
        _states.add(_parseSnapshot(stateJson.toDart));
      }
    }).toJS;
    _subscribe(_listener);
  }

  final StreamController<AppInstallSnapshot> _states =
      StreamController<AppInstallSnapshot>.broadcast();
  late final JSFunction _listener;

  @override
  AppInstallSnapshot get current => _parseSnapshot(_getStateJson().toDart);

  @override
  Stream<AppInstallSnapshot> get states => _states.stream;

  @override
  Future<AppInstallPromptResult> prompt() async {
    final result = (await _prompt().toDart).toDart;
    return switch (result) {
      'accepted' => AppInstallPromptResult.accepted,
      'dismissed' => AppInstallPromptResult.dismissed,
      'error' => AppInstallPromptResult.error,
      _ => AppInstallPromptResult.unavailable,
    };
  }

  @override
  void dispose() {
    _unsubscribe(_listener);
    unawaited(_states.close());
  }
}

/// JS의 문자열을 AppInstallTarget enum으로 파싱.
AppInstallSnapshot _parseSnapshot(String stateJson) {
  try {
    final json = jsonDecode(stateJson) as Map<String, dynamic>;
    final target = switch (json['target']) {
      'installed' => AppInstallTarget.installed,
      'nativePrompt' => AppInstallTarget.nativePrompt,
      'iosManual' => AppInstallTarget.iosManual,
      'macSafariManual' => AppInstallTarget.macSafariManual,
      'browserManual' => AppInstallTarget.browserManual,
      _ => AppInstallTarget.unsupportedBrowser,
    };
    return AppInstallSnapshot(target);
  } on FormatException {
    return const AppInstallSnapshot(AppInstallTarget.unsupportedBrowser);
  }
}
