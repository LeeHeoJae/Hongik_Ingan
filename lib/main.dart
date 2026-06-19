import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'core/app.dart';
import 'core/app_info.dart';
import 'core/logger.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  unawaited(initLogger());
  unawaited(
    PackageInfo.fromPlatform().then(
      (packageInfo) => AppInfo.version = packageInfo.version,
    ),
  );

  runApp(const ProviderScope(child: HIApp()));
}
