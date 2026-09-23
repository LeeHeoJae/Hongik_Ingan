import 'package:hongik_ingan/features/attendance/presentation/attendance_section.dart';
import 'package:flutter/material.dart';
import 'package:hongik_ingan/core/theme/color.dart';

class StudentDashboard extends StatelessWidget {
  final String userId;
  final VoidCallback onLogout;

  const StudentDashboard({
    super.key,
    required this.userId,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final palette =
        Theme.of(context).extension<HongikPalette>() ?? HongikPalette.light;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '로그인됨',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (userId.isNotEmpty)
                    Text(
                      userId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            TextButton(onPressed: onLogout, child: const Text('로그아웃')),
          ],
        ),
        const SizedBox(height: 12),
        Divider(height: 1, color: palette.cardOutline),
        const SizedBox(height: 18),
        const AttendanceSection(),
      ],
    );
  }
}
