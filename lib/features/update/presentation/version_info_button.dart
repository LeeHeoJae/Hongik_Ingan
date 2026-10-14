import 'package:flutter/material.dart';
import 'package:hongik_ingan/core/theme/color.dart';

class VersionInfoButton extends StatelessWidget {
  const VersionInfoButton({
    super.key,
    required this.version,
    required this.hasUpdate,
    required this.onPressed,
  });

  final String version;
  final bool hasUpdate;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<HongikPalette>() ?? HongikPalette.light;
    final radius = BorderRadius.circular(20);

    return Semantics(
      button: true,
      onTap: onPressed,
      label: '버전 v$version${hasUpdate ? ', 업데이트 가능' : ''}, 버전 정보 열기',
      excludeSemantics: true,
      child: Material(
        color: palette.cardSurfaceMuted,
        borderRadius: radius,
        child: InkWell(
          onTap: onPressed,
          borderRadius: radius,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasUpdate) ...[
                    Icon(Icons.update, color: palette.success, size: 18),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    'v$version',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onSurface,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
