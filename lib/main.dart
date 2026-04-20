import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'core/app.dart';
import 'core/app_info.dart';
import 'core/logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initLogger();
  final packageInfo = await PackageInfo.fromPlatform();
  AppInfo.version = packageInfo.version;
  runApp(const HIApp());
}
