import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/core/haptics/app_haptics.dart';

void main() {
  late _Backend backend;
  late AppHaptics haptics;
  late HapticMode mode;
  late DateTime now;

  setUp(() {
    backend = _Backend();
    mode = HapticMode.resultsOnly;
    now = DateTime(2026);
    haptics = AppHaptics(
      backend: backend,
      readMode: () => mode,
      now: () => now,
    );
  });

  test('duplicate results are throttled and errors take priority', () {
    haptics.complete();
    haptics.complete();
    haptics.error();
    haptics.error();
    haptics.complete();
    now = now.add(const Duration(milliseconds: 110));
    haptics.complete();
    expect(backend.signals, [HapticSignal.complete, HapticSignal.error]);
    now = now.add(const Duration(milliseconds: 100));
    haptics.error();
    expect(backend.signals, [
      HapticSignal.complete,
      HapticSignal.error,
      HapticSignal.error,
    ]);
  });

  test(
    'results only permits completion and errors; off suppresses everything',
    () {
      mode = HapticMode.resultsOnly;
      haptics.complete();
      haptics.error();
      expect(backend.signals, [HapticSignal.complete, HapticSignal.error]);
      mode = HapticMode.off;
      now = now.add(const Duration(seconds: 1));
      haptics.complete();
      haptics.error();
      expect(backend.signals.length, 2);
    },
  );

  test('backgrounding cancels pending feedback and ignores later results', () {
    haptics.error();
    haptics.setActive(false);
    haptics.complete();
    expect(backend.cancellations, 1);
    expect(backend.signals, [HapticSignal.error]);
    haptics.setActive(true);
    haptics.complete();
    expect(backend.signals.last, HapticSignal.complete);
  });

  test(
    'unsupported or failed playback never interrupts the operation',
    () async {
      backend.fail = true;
      haptics.error();
      haptics.cancel();
      await Future<void>.delayed(Duration.zero);
    },
  );

  test('manual operations only vibrate when they fail', () async {
    await haptics.runAction(() async {}, hasError: () => false);
    expect(backend.signals, isEmpty);
    now = now.add(const Duration(seconds: 1));
    await haptics.runAction(() async {}, hasError: () => true);
    expect(backend.signals, [HapticSignal.error]);
  });

  test('leaving a manual operation suppresses its late error', () async {
    final pending = Completer<void>();
    final operation = haptics.runAction(
      () => pending.future,
      hasError: () => true,
    );
    haptics.cancel();
    pending.complete();
    await operation;
    expect(backend.signals, isEmpty);
  });

  test('unmounted operations never inspect disposed state', () async {
    await haptics.runAction(
      () async {},
      isCurrent: () => false,
      hasError: () => throw StateError('Disposed state'),
    );
    expect(backend.signals, isEmpty);
  });
}

class _Backend implements HapticBackend {
  final signals = <HapticSignal>[];
  var cancellations = 0;
  var fail = false;

  @override
  Future<void> play(HapticSignal signal) async {
    if (fail) throw StateError('Unsupported');
    signals.add(signal);
  }

  @override
  void cancel() {
    cancellations++;
    if (fail) throw StateError('Unsupported');
  }
}
