import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/core/haptics/haptic_backend_native.dart';
import 'package:hongik_ingan/core/haptics/haptic_types.dart';

void main() {
  for (final cancel in [false, true]) {
    testWidgets('native error pulse cancellation: $cancel', (tester) async {
      final effects = <String>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          effects.add(call.arguments as String);
        }
        return null;
      });
      final backend = createHapticBackend();
      addTearDown(() {
        backend.cancel();
        messenger.setMockMethodCallHandler(SystemChannels.platform, null);
      });
      await backend.play(HapticSignal.error);
      if (cancel) backend.cancel();
      await tester.pump(const Duration(milliseconds: 150));
      expect(effects.length, cancel ? 1 : 2);
    });
  }
}
