import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'haptic_types.dart';

HapticBackend createHapticBackend() => _NativeHaptics();

class _NativeHaptics implements HapticBackend {
  Timer? _secondPulse;

  bool get _supported =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Future<void> play(HapticSignal signal) async {
    cancel();
    if (!_supported) return;
    switch (signal) {
      case HapticSignal.complete:
        await HapticFeedback.mediumImpact();
      case HapticSignal.error:
        // Schedule before awaiting the channel so cancellation cannot race it.
        _secondPulse = Timer(const Duration(milliseconds: 100), () {
          unawaited(HapticFeedback.lightImpact().catchError((Object _) {}));
        });
        await HapticFeedback.lightImpact();
    }
  }

  @override
  void cancel() {
    _secondPulse?.cancel();
    _secondPulse = null;
  }
}
