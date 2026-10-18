import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/attendance_controller.dart';
import 'attendance_test_environment.dart';

class AttendanceTestControls extends ConsumerWidget {
  const AttendanceTestControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scenario = ref.watch(attendanceTestControllerProvider);
    final controller = ref.read(attendanceTestControllerProvider.notifier);
    final busy = ref.watch(attendanceProvider.select((state) => state.isBusy));
    final colorScheme = Theme.of(context).colorScheme;
    final isActive = scenario != null;
    final inactiveBackground = colorScheme.brightness == Brightness.dark
        ? colorScheme.primaryContainer
        : colorScheme.surfaceContainerHigh;
    final inactiveForeground = colorScheme.brightness == Brightness.dark
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurfaceVariant;

    return IconButton(
      key: const ValueKey('attendance-test-toggle'),
      tooltip: isActive ? '테스트 수업 표시 중 · 끄기' : '테스트 수업 표시',
      onPressed: busy
          ? null
          : () {
              unawaited(
                scenario == null ? controller.enable() : controller.disable(),
              );
            },
      style: IconButton.styleFrom(
        foregroundColor: isActive ? colorScheme.onPrimary : inactiveForeground,
        backgroundColor: isActive ? colorScheme.primary : inactiveBackground,
        minimumSize: const Size.square(44),
        maximumSize: const Size.square(44),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: Badge(
        isLabelVisible: isActive,
        smallSize: 7,
        backgroundColor: colorScheme.onPrimary,
        child: Icon(
          isActive ? Icons.science_rounded : Icons.science_outlined,
          size: 20,
        ),
      ),
    );
  }
}
