import 'package:flutter/material.dart';

import 'app_animated_switcher.dart';

/// Fades a notice without retaining its height after it is removed.
class AppNoticeTransition extends StatelessWidget {
  const AppNoticeTransition({super.key, required this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => AppAnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        layoutBuilder: AppAnimatedSwitcher.layoutForCurrentChild(
          constraints.maxWidth,
        ),
        child: child == null
            ? const SizedBox.shrink(key: ValueKey('no-notice'))
            : KeyedSubtree(key: const ValueKey('notice'), child: child!),
      ),
    );
  }
}
