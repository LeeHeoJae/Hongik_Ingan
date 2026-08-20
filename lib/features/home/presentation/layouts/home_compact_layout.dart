import 'package:flutter/material.dart';

class HomeCompactLayout extends StatelessWidget {
  const HomeCompactLayout({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(28, 24, 28, 24 + bottomInset),
          child: child,
        ),
      ),
    );
  }
}
