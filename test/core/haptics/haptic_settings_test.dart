import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/core/app_config.dart';
import 'package:hongik_ingan/core/haptics/app_haptics.dart';
import 'package:hongik_ingan/core/haptics/haptic_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('failed saves retain the selection and allow retry', (
    tester,
  ) async {
    var fail = true;
    const channel = MethodChannel('plugins.flutter.io/shared_preferences');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    SharedPreferences.resetStatic();
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method.startsWith('getAll')) return <String, Object>{};
      if (call.method == 'setString') return !fail;
      throw StateError(call.method);
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      SharedPreferences.resetStatic();
      AppHaptics.instance.cancel();
    });
    final config = AppConfig(loadPreferences: SharedPreferences.getInstance);
    await config.init();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: HapticSettings(config: config),
          ),
        ),
      ),
    );
    Future<void> chooseOff() async {
      await tester.tap(find.byType(DropdownButton<HapticMode>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('끄기').last);
      await tester.pumpAndSettle();
    }

    await chooseOff();
    expect(config.hapticMode, HapticMode.resultsOnly);
    expect(find.text('진동 설정을 저장하지 못했어요. 다시 시도해 주세요.'), findsOneWidget);
    fail = false;
    await chooseOff();
    expect(config.hapticMode, HapticMode.off);
    expect(find.text('진동 설정을 저장하지 못했어요. 다시 시도해 주세요.'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
