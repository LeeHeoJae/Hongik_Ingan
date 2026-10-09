import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../domain/update_info.dart';

void showUpdateDialog(BuildContext context, UpdateInfo info) {
  final content = info.notice;
  final currentVersion = info.currentVersion;
  final targetVersion = info.latestVersion;
  final updateLink = info.updateUrl;
  showDialog(
    context: context,
    builder: (context) {
      final colorScheme = Theme.of(context).colorScheme;
      final releaseNotes = content.trim();

      return AlertDialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: MediaQuery.sizeOf(context).width < 360 ? 16 : 40,
          vertical: 24,
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.system_update_rounded,
                color: colorScheme.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('새로운 버전이 있어요')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '더 안정적이고 편리한 홍익인간을 이용해 보세요.',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    _VersionLabel(label: '현재', version: currentVersion),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        color: colorScheme.onSurfaceVariant,
                        size: 18,
                      ),
                    ),
                    _VersionLabel(
                      label: '최신',
                      version: targetVersion,
                      highlighted: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '업데이트 내역',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                releaseNotes.isEmpty ? '더 나은 사용 경험을 위해 개선했어요.' : releaseNotes,
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('나중에'),
          ),
          FilledButton.icon(
            onPressed: () => launchUpdateUrl(updateLink),
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: const Text('업데이트하기'),
          ),
        ],
      );
    },
  );
}

class _VersionLabel extends StatelessWidget {
  const _VersionLabel({
    required this.label,
    required this.version,
    this.highlighted = false,
  });

  final String label;
  final String version;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = highlighted
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: color, fontSize: 12)),
          const SizedBox(height: 2),
          Text(
            'v$version',
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

Future<void> launchUpdateUrl(String url) async {
  final updateUri = Uri.parse(url);
  await launchUrl(updateUri, mode: LaunchMode.externalApplication);
}
