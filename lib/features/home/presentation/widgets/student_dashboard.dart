import 'package:flutter/material.dart';
import 'package:hongik_ingan/core/theme/color.dart';
import 'package:hongik_ingan/features/attendance/presentation/attendance_bottom_sheet.dart';

class StudentDashboard extends StatelessWidget {
  final String userId;
  final VoidCallback onLogout;

  const StudentDashboard({
    super.key,
    required this.userId,
    required this.onLogout,
  });

  void _showAttendanceSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const AttendanceBottomSheet(),
    );
  }

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
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withValues(
                    alpha: isDark ? 0.1 : 0.24,
                  ),
                  blurRadius: isDark ? 14 : 24,
                  spreadRadius: isDark ? 0 : 1,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: () => _showAttendanceSheet(context),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 58),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: isDark ? 2 : 4,
                shadowColor: colorScheme.primary.withValues(
                  alpha: isDark ? 0.1 : 0.18,
                ),
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
              ),
              child: const Text(
                '출결 번호 입력하러 가기',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
            ),
          ),
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
