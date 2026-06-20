import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'core/app.dart';
import 'core/app_info.dart';
import 'core/logger.dart';
import 'core/network_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  unawaited(initLogger());
  await NetworkClient().init();
  unawaited(
    PackageInfo.fromPlatform().then(
      (packageInfo) => AppInfo.version = packageInfo.version,
    ),
  );

  runApp(const ProviderScope(child: HIApp()));
}
