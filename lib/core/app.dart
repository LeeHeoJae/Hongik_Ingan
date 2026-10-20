import 'package:flutter/material.dart';
import 'package:hongik_ingan/core/theme/theme.dart';

import 'package:hongik_ingan/features/home/presentation/home_screen.dart';
import 'navigation/modal_navigation.dart';
import 'logging/keyboard_diagnostics.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class HIApp extends StatefulWidget {
  const HIApp({super.key});

  @override
  State<HIApp> createState() => _HIAppState();
}

class _HIAppState extends State<HIApp> {
  late final _navigation = ModalNavigation(
    navigatorKey: navigatorKey,
    home: const HomeScreen(),
  );
  late final _routeInformation = ModalRouteInformationProvider(
    initialRouteInformation: RouteInformation(
      uri: Uri.parse(
        WidgetsBinding.instance.platformDispatcher.defaultRouteName,
      ),
    ),
  );

  @override
  void dispose() {
    _navigation.dispose();
    _routeInformation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      builder: buildKeyboardViewport,
      title: '홍익인간',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: themeData,
      darkTheme: darkThemeData,
      routerDelegate: _navigation,
      routeInformationProvider: _routeInformation,
      routeInformationParser: const ModalRouteInformationParser(),
    );
  }
}
