import 'dart:async';

import 'haptic_backend_native.dart'
    if (dart.library.js_interop) 'haptic_backend_web.dart';
import 'haptic_types.dart';

export 'haptic_types.dart';

/// UI feedback is best effort and must never affect the underlying operation.
class AppHaptics {
  AppHaptics({required HapticBackend backend, DateTime Function()? now})
    : _backend = backend,
      _now = now ?? DateTime.now;

  static final instance = AppHaptics(backend: createHapticBackend());

  final HapticBackend _backend;
  final DateTime Function() _now;
  DateTime? _blockedUntil;
  bool _active = true;
  int _generation = 0;
  HapticSignal? _lastSignal;

  void complete() => _play(HapticSignal.complete);
  void error() => _play(HapticSignal.error);

  void setActive(bool active) {
    _active = active;
    if (!active) cancel();
  }

  void cancel() {
    _generation++;
    _blockedUntil = null;
    try {
      _backend.cancel();
    } catch (_) {
      // Unsupported devices and browser restrictions are silent fallbacks.
    }
  }

  Future<void> runAction(
    Future<void> Function() operation, {
    required bool Function() hasError,
    bool Function()? isCurrent,
  }) async {
    final generation = _generation;
    try {
      await operation();
      if (generation == _generation &&
          (isCurrent?.call() ?? true) &&
          hasError()) {
        error();
      }
    } catch (_) {
      if (generation == _generation && (isCurrent?.call() ?? true)) error();
      rethrow;
    }
  }

  void _play(HapticSignal signal) {
    if (!_active) {
      return;
    }
    final now = _now();
    if (_blockedUntil != null && now.isBefore(_blockedUntil!)) {
      if (_lastSignal == signal ||
          (_lastSignal == HapticSignal.error &&
              signal == HapticSignal.complete)) {
        return;
      }
    }
    _lastSignal = signal;
    _blockedUntil = now.add(const Duration(milliseconds: 200));
    unawaited(_playSafely(signal));
  }

  Future<void> _playSafely(HapticSignal signal) async {
    try {
      await _backend.play(signal);
    } catch (_) {
      // Haptics must not surface as login or attendance failures.
    }
  }
}
