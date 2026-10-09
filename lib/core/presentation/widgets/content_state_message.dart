import 'package:flutter/material.dart';
import 'package:hongik_ingan/core/theme/color.dart';

enum ContentStateTone { neutral, error }

class ContentStateMessage extends StatelessWidget {
  const ContentStateMessage({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.actionIcon = Icons.refresh_rounded,
    this.onAction,
    this.tone = ContentStateTone.neutral,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final IconData actionIcon;
  final VoidCallback? onAction;
  final ContentStateTone tone;

  @override
  Widget build(BuildContext context) {
    final palette =
        Theme.of(context).extension<HongikPalette>() ?? HongikPalette.light;
    final accentColor = switch (tone) {
      ContentStateTone.neutral => palette.brandBlue,
      ContentStateTone.error => palette.brandRed,
    };

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
        child: Semantics(
          label: '$title. $message',
          liveRegion: true,
          container: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 42, color: accentColor),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: palette.textSecondary,
                  height: 1.45,
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: onAction,
                  icon: Icon(actionIcon),
                  label: Text(actionLabel!),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(120, 48),
                    foregroundColor: palette.textSecondary,
                    side: BorderSide(color: palette.cardOutline),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Horizontal state message for compact service details.
class CompactContentStateMessage extends StatelessWidget {
  const CompactContentStateMessage({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.isLoading = false,
    this.tone = ContentStateTone.neutral,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool isLoading;
  final ContentStateTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final palette =
        Theme.of(context).extension<HongikPalette>() ?? HongikPalette.light;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.cardSurfaceMuted,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (isLoading)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(
              icon,
              size: 22,
              color: tone == ContentStateTone.error
                  ? palette.brandRed
                  : palette.brandBlue,
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Semantics(
              label: '$title. $message',
              liveRegion: true,
              container: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    message,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!isLoading && actionLabel != null) ...[
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: onAction,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(96, 44),
                foregroundColor: palette.textSecondary,
                side: BorderSide(color: palette.cardOutline),
              ),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
