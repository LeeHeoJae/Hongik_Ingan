import 'package:material_ui/material_ui.dart';
import 'package:hongik_ingan/core/theme/theme.dart';

import 'package:hongik_ingan/features/attendance/application/quick_attend_launch.dart';
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
      uri: _initialUri(
        WidgetsBinding.instance.platformDispatcher.defaultRouteName,
      ),
    ),
  );

  // 바로가기 경로는 시작할 때 한 번만 쓰고 주소에 남기지 않는다.
  // 남기면 웹에서 새로고침할 때마다 입력창이 다시 열린다.
  static Uri _initialUri(String routeName) =>
      isQuickAttendRoute(routeName) ? Uri.parse('/') : Uri.parse(routeName);

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
