import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hongik_ingan/core/network/school_transport_factory.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'core/app.dart';
import 'core/app_info.dart';
import 'core/logging/logger.dart';
import 'core/network/school_transport_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  unawaited(initLogger());
  final transport = await createSchoolTransport();
  unawaited(
    PackageInfo.fromPlatform().then(
      (packageInfo) => AppInfo.version = packageInfo.version,
    ),
  );

  runApp(
    ProviderScope(
      overrides: [schoolTransportProvider.overrideWithValue(transport)],
      child: const HIApp(),
    ),
  );
}
