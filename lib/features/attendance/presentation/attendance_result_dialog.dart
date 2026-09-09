import 'package:flutter/material.dart';
import 'package:hongik_ingan/features/attendance/domain/attendance_submission_result.dart';

/// 출결 결과 다이얼로그
class AttendanceResultDialog extends StatelessWidget {
  const AttendanceResultDialog({super.key, required this.result});

  final AttendanceSubmissionResult result;

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
    return AlertDialog(
      scrollable: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          resultIcon,
          const SizedBox(width: 12),
          const Expanded(child: Text(title)),
        ],
      ),
      content: Text(result.message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('확인'),
        ),
      ],
    );
  }
}
