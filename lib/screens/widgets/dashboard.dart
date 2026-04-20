import 'package:flutter/material.dart';

class Dashboard extends StatelessWidget {
  final String userId;
  final VoidCallback onMoveToAttendance;
  final VoidCallback onLogout;

  const Dashboard({
    super.key,
    required this.userId,
    required this.onMoveToAttendance,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.face_retouching_natural,
              size: 40,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '반갑습니다, ${userId.toUpperCase()}님',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: onMoveToAttendance,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 60),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: const Text(
              '출결 번호 입력하러 가기',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onLogout,
            child: Text(
              '로그아웃 / 계정 전환',
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
