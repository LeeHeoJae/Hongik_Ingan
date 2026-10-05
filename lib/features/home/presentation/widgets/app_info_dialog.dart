import 'package:flutter/material.dart';
import 'package:hongik_ingan/core/theme/color.dart';

class AppInfoDialog extends StatelessWidget {
  const AppInfoDialog({
    super.key,
    required this.version,
    required this.onOpenSource,
    this.installDescription,
    this.onInstall,
    this.onShareLogs,
  });

  final String version;
  final VoidCallback onOpenSource;
  final String? installDescription;
  final VoidCallback? onInstall;
  final VoidCallback? onShareLogs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<HongikPalette>() ?? HongikPalette.light;

    return AlertDialog(
      constraints: const BoxConstraints(maxWidth: 440),
      insetPadding: EdgeInsets.symmetric(
        horizontal: MediaQuery.sizeOf(context).width < 360 ? 16 : 40,
        vertical: 24,
      ),
      scrollable: true,
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColor.hkMidnightBlue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Image.asset(
              'assets/images/icon_foreground.png',
              excludeFromSemantics: true,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('홍익인간'),
                if (version.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'v$version',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      content: SizedBox(
        width: 392,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '개인이 개발한 홍익대학교 비공식 오픈소스 앱이에요.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: palette.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Divider(height: 1, color: palette.cardOutline),
            const SizedBox(height: 8),
            if (onInstall != null)
              _AppInfoAction(
                icon: Icons.install_mobile_rounded,
                label: '앱 설치',
                description: installDescription,
                onTap: onInstall!,
              ),
            _AppInfoAction(
              icon: Icons.code_rounded,
              label: '소스 코드',
              trailingIcon: Icons.open_in_new_rounded,
              onTap: onOpenSource,
            ),
            if (onShareLogs != null)
              _AppInfoAction(
                icon: Icons.upload_file_outlined,
                label: '진단 로그 공유',
                description: '개인정보를 가린 로그를 공유해요.',
                trailingIcon: Icons.ios_share_rounded,
                onTap: onShareLogs!,
              ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      actions: [
        TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('닫기'),
        ),
      ],
    );
  }
}

class _AppInfoAction extends StatelessWidget {
  const _AppInfoAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.description,
    this.trailingIcon = Icons.chevron_right_rounded,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? description;
  final IconData trailingIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<HongikPalette>() ?? HongikPalette.light;

    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: palette.textSecondary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (description != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          description!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: palette.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(trailingIcon, color: palette.textSecondary, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
