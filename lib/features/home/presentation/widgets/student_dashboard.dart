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
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette =
        Theme.of(context).extension<HongikPalette>() ?? HongikPalette.light;

    return Container(
      padding: const EdgeInsets.fromLTRB(26, 26, 26, 22),
      decoration: BoxDecoration(
        color: palette.cardSurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.cardOutline),
        boxShadow: [
          BoxShadow(
            color: palette.cardShadow,
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              color: palette.brandNavy.withValues(alpha: isDark ? 0.22 : 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.face_retouching_natural,
              size: 36,
              color: palette.brandNavy,
            ),
          ),
          const SizedBox(height: 22),
          Text(
            '반가워요, ${userId.toUpperCase()}님',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w900,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 28),
          const AttendanceSection(),
          const SizedBox(height: 20),
          TextButton(
            onPressed: onLogout,
            child: Text(
              '로그아웃',
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
