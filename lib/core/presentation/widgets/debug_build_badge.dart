import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hongik_ingan/core/app_info.dart';

class DebugBuildBadge extends StatelessWidget {
  const DebugBuildBadge({super.key});

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.inverseSurface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        child: DefaultTextStyle(
          style: TextStyle(
            color: colorScheme.onInverseSurface,
            fontSize: 10,
            height: 1.2,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'DEBUG',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              Text('v${AppInfo.version}'),
            ],
          ),
        ),
      ),
    );
  }
}
