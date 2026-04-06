import 'package:flutter/material.dart';

import '../screens/home_screen.dart';

class HIApp extends StatelessWidget {
  const HIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '홍익인간',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const HomeScreen(),
    );
  }
}