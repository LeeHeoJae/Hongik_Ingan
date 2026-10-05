import 'package:flutter/material.dart';
import 'package:hongik_ingan/core/theme/color.dart';

/// A persistent status slot shared by login and attendance.
class AttendanceStatusMessage extends StatelessWidget {
  const AttendanceStatusMessage({
    super.key,
    required this.title,
    required this.icon,
    this.description,
    this.isError = false,
    this.isReady = false,
  });

  final String title;
  final IconData icon;
  final String? description;
  final bool isError;
  final bool isReady;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<HongikPalette>() ?? HongikPalette.light;
    final color = isError
        ? theme.colorScheme.error
        : isReady
        ? palette.brandBlue
        : theme.colorScheme.onSurface;
    final titleStyle = theme.textTheme.bodyMedium!.copyWith(
      color: color,
      fontWeight: FontWeight.w600,
      height: 1.5,
    );
    final descriptionStyle = theme.textTheme.bodyMedium!.copyWith(
      color: isError ? theme.colorScheme.error : palette.textSecondary,
      height: 1.5,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        double measure(String text, TextStyle style, double width) {
          final painter = TextPainter(
            text: TextSpan(text: text, style: style),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
            locale: Localizations.maybeLocaleOf(context),
          )..layout(maxWidth: width.clamp(1, double.infinity));
          final height = painter.height;
          painter.dispose();
          return height;
        }

        // Reserve ordinary messages only; long text remains free to grow.
        final titleHeight = measure(
          '출결 가능한 수업이 없어요',
          titleStyle,
          constraints.maxWidth - 24,
        );
        final descriptionHeight = measure(
          '출결 서버에 연결하지 못했어요.',
          descriptionStyle,
          constraints.maxWidth - 24,
        );
        final descriptionContent = ConstrainedBox(
          constraints: BoxConstraints(minHeight: descriptionHeight),
          child: description == null
              ? const SizedBox.shrink()
              : ExcludeSemantics(
                  child: Text(description!, style: descriptionStyle),
                ),
        );
        return Semantics(
          container: true,
          explicitChildNodes: true,
          liveRegion: true,
          label: description == null ? title : '$title\n$description',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(minHeight: titleHeight),
                child: ExcludeSemantics(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(icon, size: 18, color: color),
                      ),
                      const SizedBox(width: 6),
                      Expanded(child: Text(title, style: titleStyle)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 24),
                child: descriptionContent,
              ),
            ],
          ),
        );
      },
    );
  }
}
