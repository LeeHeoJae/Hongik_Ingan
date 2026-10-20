import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/core/logging/keyboard_overlay_media.dart';

void main() {
  testWidgets(
    'overlay keyboard reserves space once and restores it on dismissal',
    (tester) async {
      tester.view.physicalSize = const Size(1204, 634);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const bodyKey = ValueKey('body');
      Future<void> show(double keyboard, {double engineInset = 0}) async {
        final media = MediaQueryData(
          size: const Size(1204, 634),
          viewInsets: EdgeInsets.only(bottom: engineInset),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: keyboardOverlayMedia(media, keyboard),
              child: const Scaffold(body: SizedBox.expand(key: bodyKey)),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await show(360);
      expect(tester.getSize(find.byKey(bodyKey)).height, 274);
      await show(360, engineInset: 360);
      expect(tester.getSize(find.byKey(bodyKey)).height, 274);
      await show(0);
      expect(tester.getSize(find.byKey(bodyKey)).height, 634);
    },
  );

  test(
    'overlay inset handles safe area and preserves other media settings',
    () {
      const media = MediaQueryData(
        size: Size(1204, 634),
        viewPadding: EdgeInsets.only(bottom: 24),
        padding: EdgeInsets.only(bottom: 24),
        textScaler: TextScaler.linear(2),
      );
      final result = keyboardOverlayMedia(media, 360);
      expect(result.padding.bottom, 0);
      expect(result.viewPadding.bottom, 24);
      expect(result.textScaler.scale(14), 28);
      expect(keyboardOverlayMedia(media, double.nan), same(media));
    },
  );
}
