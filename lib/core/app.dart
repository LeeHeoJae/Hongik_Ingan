import 'package:flutter/material.dart';

import '../screens/home_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class HIApp extends StatelessWidget {
  const HIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '홍익인간',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      navigatorKey: navigatorKey,
      home: const HomeScreen(),
    );
  }
}