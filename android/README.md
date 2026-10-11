# Android toolchain

- Flutter 3.47 or newer on the stable channel (migration verified with 3.47.7).
- Android SDK Platform 37.0, compile SDK 37, target SDK 37.
- Android Gradle Plugin 9.1.1, Gradle 9.3.1, JDK 17 or newer.
- AGP built-in Kotlin is enabled. Do not reapply `kotlin-android` to the app.
- Kotlin compiler 2.3.20 is selected with `apply false` in `settings.gradle.kts`
  because AGP's bundled 2.2.10 is below Flutter 3.47's minimum supported version.
  The Kotlin Android plugin is not applied to the app.

Flutter 3.47 still uses the legacy Android Gradle DSL, so
`android.newDsl=false` must remain in `gradle.properties`. Remove it only after
the Flutter SDK and all Android plugins support the new DSL. This flag is
independent of the built-in Kotlin setting.
See the [Flutter built-in Kotlin migration guide](https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-app-developers).

Commit `pubspec.lock`: Android plugin versions must support built-in Kotlin.
In particular, `shared_preferences_android` requires version 2.4.24 or newer.

From the repository root on this Windows development environment:

```powershell
& 'C:/flutter/bin/flutter.bat' pub get
& 'C:/flutter/bin/flutter.bat' analyze --no-pub
& 'C:/flutter/bin/flutter.bat' test --no-pub
& 'C:/flutter/bin/flutter.bat' build apk --debug --flavor dev --no-pub
& 'C:/flutter/bin/flutter.bat' build apk --release --flavor prod --no-pub
```

Use the intended release build number when preparing a distribution APK.
Build success does not verify Android 17 runtime behavior: check startup,
login and saved credentials, location permissions, attendance, seat requests,
log sharing, back navigation, and tablet/window resizing on a test device.

The current app uses public university endpoints rather than LAN device access,
so the API 37 local-network permission is not needed for these requests.
Review [Android 17 target behavior changes](https://developer.android.com/about/versions/17/behavior-changes-17)
when adding native functionality or new Android plugins.
