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

    return Row(
      children: [
        Icon(
          Icons.person_outline_rounded,
          size: 16,
          color: palette.textSecondary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            userId.isEmpty ? '로그인됨' : '로그인됨  $userId',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: palette.textSecondary),
          ),
        ),
        TextButton(
          onPressed: onLogout,
          style: TextButton.styleFrom(
            foregroundColor: palette.textSecondary,
            minimumSize: const Size(44, 44),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            textStyle: Theme.of(context).textTheme.bodySmall,
          ),
          child: const Text('로그아웃'),
        ),
      ],
    );
  }
}
