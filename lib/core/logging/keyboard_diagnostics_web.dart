import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';

import '../deployment_environment.dart';
import 'keyboard_overlay_media.dart';

@JS('window.hongikKeyboardDiagnostics')
external JSObject? get _bridge;

@JS('window.hongikKeyboardDiagnostics.start')
external JSBoolean _start(JSString metadata);

@JS('window.hongikKeyboardDiagnostics.recordFlutter')
external void _recordFlutter(JSString snapshot);

@JS('window.hongikKeyboardDiagnostics.download')
external JSBoolean _download();

@JS('window.hongikKeyboardDiagnostics.configureViewport')
external JSBoolean _configureViewport(JSString info, JSFunction onInset);

@JS('window.hongikKeyboardDiagnostics.configureViewport')
external JSFunction? get _viewportApi;

_KeyboardObserver? _observer;
final _keyboardHeight = ValueNotifier<double>(0);
JSFunction? _insetCallback;
bool _overlayEnabled = false;
bool _initialized = false;

void initializeKeyboardViewport() {
  if (_initialized || _bridge == null || _viewportApi == null) return;
  _initialized = true;
  final info = jsonEncode({
    'appEnv': DeploymentEnvironment.appEnv,
    'flutterVersion': const String.fromEnvironment('FLUTTER_VERSION'),
    'engineRevision': const String.fromEnvironment('FLUTTER_ENGINE_REVISION'),
    'flutterBrowserOs': ui_web.browser.operatingSystem.name,
    'flutterBrowserIsMobile': ui_web.browser.isMobile,
  }).toJS;
  _insetCallback = ((JSNumber height) {
    _keyboardHeight.value = height.toDartDouble;
    _observer?._schedule('keyboard-overlay-frame');
  }).toJS;
  _overlayEnabled = _configureViewport(info, _insetCallback!).toDart;
  if (DeploymentEnvironment.isDevelopment && _start(info).toDart) {
    _observer = _KeyboardObserver()..start();
  }
}

Widget buildKeyboardViewport(BuildContext context, Widget? child) {
  final content = child ?? const SizedBox.shrink();
  if (!_overlayEnabled) return content;
  return ValueListenableBuilder<double>(
    valueListenable: _keyboardHeight,
    child: content,
    builder: (context, height, child) => MediaQuery(
      data: keyboardOverlayMedia(MediaQuery.of(context), height),
      child: child!,
    ),
  );
}

bool downloadKeyboardDiagnostics() =>
    DeploymentEnvironment.isDevelopment &&
    _observer != null &&
    _download().toDart;

class _KeyboardObserver with WidgetsBindingObserver {
  bool _framePending = false;
  String _reason = 'startup';

  void start() {
    WidgetsBinding.instance.addObserver(this);
    FocusManager.instance.addListener(_focusChanged);
    Timer(const Duration(minutes: 10), () {
      WidgetsBinding.instance.removeObserver(this);
      FocusManager.instance.removeListener(_focusChanged);
    });
    _schedule('startup');
  }

  @override
  void didChangeMetrics() {
    // Record the engine's metrics immediately, then the laid-out coordinates.
    _capture('metrics');
    _schedule('metrics-frame');
  }

  void _focusChanged() => _schedule('focus-frame');

  void _schedule(String reason) {
    _reason = reason;
    if (_framePending) return;
    _framePending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _framePending = false;
      _capture(_reason);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _capture(String reason) {
    final focus = FocusManager.instance.primaryFocus;
    final render = focus?.context?.findRenderObject();
    Rect? focusRect;
    if (render is RenderBox && render.attached && render.hasSize) {
      focusRect = render.localToGlobal(Offset.zero) & render.size;
    }
    _recordFlutter(
      jsonEncode({
        'reason': reason,
        'appKeyboardInset': _keyboardHeight.value,
        'focusRect': focusRect == null
            ? null
            : {
                'x': focusRect.left,
                'y': focusRect.top,
                'width': focusRect.width,
                'height': focusRect.height,
              },
        'views': [
          for (final view in WidgetsBinding.instance.platformDispatcher.views)
            {
              'viewId': view.viewId,
              'devicePixelRatio': view.devicePixelRatio,
              'width': view.physicalSize.width / view.devicePixelRatio,
              'height': view.physicalSize.height / view.devicePixelRatio,
              'insetBottom': view.viewInsets.bottom / view.devicePixelRatio,
              'paddingBottom': view.viewPadding.bottom / view.devicePixelRatio,
            },
        ],
      }).toJS,
    );
  }
}
