import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../domain/update_check_result.dart';

class UpdateDialog extends StatelessWidget {
  const UpdateDialog({
    super.key,
    required this.currentVersion,
    required this.result,
    required this.onRetry,
  });

  final String currentVersion;
  final UpdateCheckResult result;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final info = result.info;
    final releaseNotes = info?.notice.trim() ?? '';
    final checking =
        result.status == UpdateCheckStatus.idle ||
        result.status == UpdateCheckStatus.checking;
    final (title, description, icon) = switch (result.status) {
      UpdateCheckStatus.available => (
        '새로운 버전이 있어요',
        '더 안정적이고 편리한 홍익인간을 이용해 보세요.',
        Icons.system_update_rounded,
      ),
      UpdateCheckStatus.upToDate => (
        '최신 버전이에요',
        '현재 최신 버전을 사용하고 있어요.',
        Icons.check_circle_outline_rounded,
      ),
      UpdateCheckStatus.failed => (
        '업데이트를 확인하지 못했어요',
        '네트워크 연결을 확인한 뒤 다시 시도해 주세요.',
        Icons.wifi_off_rounded,
      ),
      UpdateCheckStatus.idle || UpdateCheckStatus.checking => (
        '업데이트 확인 중',
        '업데이트를 확인하고 있어요.',
        Icons.system_update_rounded,
      ),
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalInset = constraints.maxWidth < 360 ? 16.0 : 40.0;
        final stackedVersions =
            constraints.maxWidth - horizontalInset * 2 - 80 < 240 ||
            MediaQuery.textScalerOf(context).scale(14) > 20;
        final current = _VersionLabel(
          label: '현재',
          version: info?.currentVersion ?? currentVersion,
        );
        final latest = info == null
            ? null
            : _VersionLabel(
                label: '최신',
                version: info.latestVersion,
                highlighted: true,
              );
        return AlertDialog(
          insetPadding: EdgeInsets.symmetric(
            horizontal: horizontalInset,
            vertical: 24,
          ),
          title: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: colorScheme.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(title)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                if (checking) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(semanticsLabel: '업데이트 확인 중'),
                ],
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
                  child: latest == null
                      ? current
                      : stackedVersions
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            current,
                            const SizedBox(height: 12),
                            latest,
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(child: current),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Icon(
                                Icons.arrow_forward_rounded,
                                color: colorScheme.onSurfaceVariant,
                                size: 18,
                              ),
                            ),
                            Expanded(child: latest),
                          ],
                        ),
                ),
                if (info != null) ...[
                  const SizedBox(height: 20),
                  Text(
                    '업데이트 내역',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    releaseNotes.isEmpty
                        ? '업데이트 내역이 제공되지 않았어요.'
                        : releaseNotes,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(info != null ? '나중에' : '닫기'),
            ),
            if (result.status == UpdateCheckStatus.failed)
              FilledButton(onPressed: onRetry, child: const Text('다시 확인')),
            if (info != null)
              FilledButton.icon(
                onPressed: () => launchUpdateUrl(info.updateUrl),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('업데이트하기'),
              ),
          ],
        );
      },
    );
  }
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: color, fontSize: 12)),
        const SizedBox(height: 2),
        Text(
          'v$version',
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

Future<void> launchUpdateUrl(String url) async {
  final updateUri = Uri.parse(url);
  await launchUrl(updateUri, mode: LaunchMode.externalApplication);
}
