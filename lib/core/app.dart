import 'package:flutter/material.dart';
import 'package:hongik_ingan/core/theme/theme.dart';

import '../screens/home_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class HIApp extends StatelessWidget {
  const HIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '홍익인간',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: themeData,
      darkTheme: darkThemeData,
      navigatorKey: navigatorKey,
      home: const HomeScreen(),
    );
  }
}
