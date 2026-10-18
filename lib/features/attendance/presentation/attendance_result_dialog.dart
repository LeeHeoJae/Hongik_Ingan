import 'package:flutter/material.dart';
import 'package:hongik_ingan/features/attendance/domain/attendance_submission_result.dart';

/// 출결 결과 다이얼로그
class AttendanceResultDialog extends StatelessWidget {
  const AttendanceResultDialog({
    super.key,
    required this.result,
    this.embedded = false,
    this.bodyOnly = false,
  });

  final AttendanceSubmissionResult result;
  final bool embedded;
  final bool bodyOnly;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final resultColor = result.isError
        ? colorScheme.error
        : colorScheme.onSurfaceVariant;
    const title = '출결 안내';

    final resultIcon = Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: resultColor.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(
        result.isError
            ? Icons.error_outline_rounded
            : Icons.info_outline_rounded,
        color: resultColor,
        size: 28,
      ),
    );
    if (bodyOnly) {
      return Semantics(
        liveRegion: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                result.isError
                    ? Icons.error_outline_rounded
                    : Icons.info_outline_rounded,
                color: resultColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(result.message)),
            ],
          ),
        ),
      );
    }
    final heading = Row(
      children: [
        resultIcon,
        const SizedBox(width: 12),
        const Expanded(child: Text(title)),
      ],
    );
    final confirm = TextButton(
      onPressed: () => Navigator.of(context).pop(),
      child: const Text('확인'),
    );
    if (embedded) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DefaultTextStyle(
                      style: Theme.of(context).textTheme.titleLarge!,
                      child: heading,
                    ),
                    const SizedBox(height: 20),
                    Text(result.message),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Align(alignment: Alignment.centerRight, child: confirm),
          ],
        ),
      );
    }
    return AlertDialog(
      scrollable: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: heading,
      content: Text(result.message),
      actions: [confirm],
    );
  }
}
