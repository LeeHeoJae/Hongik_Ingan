import 'package:flutter/material.dart';
import 'package:hongik_ingan/core/app_config.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'core/app.dart';
import 'core/app_info.dart';
import 'core/logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Future.wait([
    initLogger(),
    PackageInfo.fromPlatform().then(
      (packageInfo) => AppInfo.version = packageInfo.version,
    ),
    AppConfig().init(),
  ]);

  runApp(const HIApp());
}
