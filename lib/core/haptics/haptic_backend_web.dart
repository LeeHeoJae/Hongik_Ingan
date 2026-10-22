import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'haptic_types.dart';

@JS('navigator')
external JSObject get _navigator;

@JS('document.visibilityState')
external JSString get _visibility;

HapticBackend createHapticBackend() => _WebHaptics();

class _WebHaptics implements HapticBackend {
  void _vibrate(List<int> pattern) {
    if (_navigator['vibrate'].isA<JSFunction>()) {
      _navigator.callMethod<JSAny?>(
        'vibrate'.toJS,
        pattern.map((value) => value.toJS).toList().toJS,
      );
    }
  }

  @override
  Future<void> play(HapticSignal signal) async {
    if (_visibility.toDart != 'visible') return;
    _vibrate(switch (signal) {
      HapticSignal.complete => [15, 50, 25],
      HapticSignal.error => [30, 70, 30],
    });
  }

  @override
  void cancel() => _vibrate([0]);
}
