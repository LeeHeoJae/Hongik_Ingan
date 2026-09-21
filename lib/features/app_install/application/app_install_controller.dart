import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hongik_ingan/features/app_install/data/app_install_bridge.dart';
import 'package:hongik_ingan/features/app_install/domain/app_install_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _legacyPromoDismissedKey = 'app_install_promo_dismissed';
const _promoDismissedUntilKey = 'app_install_promo_dismissed_until';
const _promoDismissDuration = Duration(days: 1);

/// 브라우저와의 통신 도구.
final appInstallBridgeProvider = Provider<AppInstallBridge>((ref) {
  final bridge = createAppInstallBridge();
  ref.onDispose(bridge.dispose);
  return bridge;
});

/// 설치 제안의 숨김 기간을 계산할 때 사용하는 현재 시각.
final appInstallClockProvider = Provider<DateTime Function()>((ref) {
  return DateTime.now;
});

final appInstallControllerProvider =
    NotifierProvider<AppInstallController, AppInstallState>(
      AppInstallController.new,
    );

class AppInstallController extends Notifier<AppInstallState> {
  Timer? _promoResetTimer;

  @override
  AppInstallState build() {
    final bridge = ref.watch(appInstallBridgeProvider);
    final subscription = bridge.states.listen(_applySnapshot);
    ref.onDispose(subscription.cancel);
    ref.onDispose(() => _promoResetTimer?.cancel());
    unawaited(_loadPreference());
    return AppInstallState(target: bridge.current.target);
  }

  Future<void> _loadPreference() async {
    final preferences = await SharedPreferences.getInstance();
    if (!ref.mounted) return;
    final now = ref.read(appInstallClockProvider)();
    var dismissedUntilMilliseconds = preferences.getInt(
      _promoDismissedUntilKey,
    );

    if (dismissedUntilMilliseconds == null &&
        (preferences.getBool(_legacyPromoDismissedKey) ?? false)) {
      dismissedUntilMilliseconds = now
          .add(_promoDismissDuration)
          .millisecondsSinceEpoch;
      await preferences.setInt(
        _promoDismissedUntilKey,
        dismissedUntilMilliseconds,
      );
      await preferences.remove(_legacyPromoDismissedKey);
    }

    var dismissedUntil = dismissedUntilMilliseconds == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(dismissedUntilMilliseconds);
    if (dismissedUntil != null && !dismissedUntil.isAfter(now)) {
      await preferences.remove(_promoDismissedUntilKey);
      dismissedUntil = null;
    }

    if (!ref.mounted) return;
    state = state.copyWith(
      preferenceLoaded: true,
      promoDismissed: dismissedUntil != null,
    );
    if (dismissedUntil != null) {
      _schedulePromoReset(dismissedUntil.difference(now));
    }
  }

  void _applySnapshot(AppInstallSnapshot snapshot) {
    state = state.copyWith(target: snapshot.target);
  }

  Future<void> dismissPromo() async {
    final now = ref.read(appInstallClockProvider)();
    final dismissedUntil = now.add(_promoDismissDuration);
    state = state.copyWith(promoDismissed: true);
    _schedulePromoReset(dismissedUntil.difference(now));

    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(
      _promoDismissedUntilKey,
      dismissedUntil.millisecondsSinceEpoch,
    );
    await preferences.remove(_legacyPromoDismissedKey);
  }

  void _schedulePromoReset(Duration delay) {
    _promoResetTimer?.cancel();
    _promoResetTimer = Timer(delay, () {
      if (!ref.mounted) return;
      state = state.copyWith(promoDismissed: false);
    });
  }

  Future<AppInstallPromptResult> prompt() async {
    if (state.target != AppInstallTarget.nativePrompt || state.isPrompting) {
      return AppInstallPromptResult.unavailable;
    }

    state = state.copyWith(isPrompting: true);
    final result = await ref.read(appInstallBridgeProvider).prompt();
    if (!ref.mounted) return result;
    state = state.copyWith(isPrompting: false);

    if (result == AppInstallPromptResult.accepted ||
        result == AppInstallPromptResult.dismissed) {
      await dismissPromo();
    }
    return result;
  }
}
