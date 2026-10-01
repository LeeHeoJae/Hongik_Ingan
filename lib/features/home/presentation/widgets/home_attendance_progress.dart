import 'package:flutter/material.dart';
import 'package:hongik_ingan/core/theme/color.dart';

class HomeAttendanceProgress extends StatelessWidget {
  const HomeAttendanceProgress({super.key, required this.currentStep});

  final int currentStep;
  static const labels = ['로그인', '수업 확인', '번호 입력'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<HongikPalette>() ?? HongikPalette.light;
    return Semantics(
      label: '${labels.join(', ')}. 현재 단계: ${labels[currentStep]}',
      excludeSemantics: true,
      child: Text.rich(
        TextSpan(
          children: [
            for (var index = 0; index < labels.length; index++) ...[
              if (index > 0) const TextSpan(text: '  →  '),
              TextSpan(
                text:
                    '${index == currentStep ? '●' : index + 1} ${labels[index]}',
                style: TextStyle(
                  color: index == currentStep
                      ? theme.colorScheme.primary
                      : palette.textSecondary,
                ),
              ),
            ],
          ],
        ),
        style: theme.textTheme.bodySmall?.copyWith(
          color: palette.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
