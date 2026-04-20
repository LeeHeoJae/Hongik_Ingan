import 'package:flutter/material.dart';

import 'core/app.dart';
import 'core/logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initLogger();
  runApp(HIApp());
}
