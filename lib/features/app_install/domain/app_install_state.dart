import 'package:flutter/foundation.dart';

enum AppInstallTarget {
  notWeb,
  installed,
  nativePrompt,
  iosManual,
  macSafariManual,
  windowsFirefoxManual,
  androidManual,
  browserManual,
  browserHelp,
}

enum AppInstallPromptResult { accepted, dismissed, unavailable, error }

@immutable
class AppInstallSnapshot {
  const AppInstallSnapshot(this.target);

  final AppInstallTarget target;
}

@immutable
class AppInstallState {
  const AppInstallState({
    required this.target,
    this.preferenceLoaded = false,
    this.promoDismissed = false,
    this.isPrompting = false,
  });

  final AppInstallTarget target;
  final bool preferenceLoaded;
  final bool promoDismissed;
  final bool isPrompting;

  bool get showInfoAction =>
      target != AppInstallTarget.notWeb && target != AppInstallTarget.installed;

  bool get showProactivePromo =>
      preferenceLoaded &&
      !promoDismissed &&
      !isPrompting &&
      (target == AppInstallTarget.nativePrompt ||
          target == AppInstallTarget.iosManual ||
          target == AppInstallTarget.macSafariManual);

  AppInstallState copyWith({
    AppInstallTarget? target,
    bool? preferenceLoaded,
    bool? promoDismissed,
    bool? isPrompting,
  }) {
    return AppInstallState(
      target: target ?? this.target,
      preferenceLoaded: preferenceLoaded ?? this.preferenceLoaded,
      promoDismissed: promoDismissed ?? this.promoDismissed,
      isPrompting: isPrompting ?? this.isPrompting,
    );
  }
}
