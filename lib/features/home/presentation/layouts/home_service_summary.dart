part of 'home_service_workspace.dart';

class HomeServiceSummaryData {
  const HomeServiceSummaryData({
    required this.status,
    this.eyebrow,
    this.secondary,
    this.warning,
    this.compactWarning,
    this.attentionKey,
    this.availableSeats,
    this.hasMenuChoices = false,
    this.leadingMenuIndex,
    this.facts = const [],
  });

  final String status;
  final String? eyebrow;
  final String? secondary;
  final String? warning;
  final String? compactWarning;
  final String? attentionKey;
  final int? availableSeats;
  final bool hasMenuChoices;
  final int? leadingMenuIndex;
  final List<({String label, String value})> facts;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HomeServiceSummaryData &&
          status == other.status &&
          eyebrow == other.eyebrow &&
          secondary == other.secondary &&
          warning == other.warning &&
          compactWarning == other.compactWarning &&
          attentionKey == other.attentionKey &&
          availableSeats == other.availableSeats &&
          hasMenuChoices == other.hasMenuChoices &&
          leadingMenuIndex == other.leadingMenuIndex &&
          listEquals(facts, other.facts);

  @override
  int get hashCode => Object.hash(
    status,
    eyebrow,
    secondary,
    warning,
    compactWarning,
    attentionKey,
    availableSeats,
    hasMenuChoices,
    leadingMenuIndex,
    Object.hashAll(facts),
  );
}

class _SummaryStatus extends StatelessWidget {
  const _SummaryStatus({
    required this.service,
    required this.data,
    this.compact = false,
  });

  final HomeService service;
  final HomeServiceSummaryData data;
  final bool compact;

  static TextSpan menuSpan(
    String text,
    int? leadingIndex,
    TextStyle? style,
    Color highlight,
  ) {
    final marker = leadingIndex == 0
        ? 'A안'
        : leadingIndex == 1
        ? 'B안'
        : null;
    final start = marker == null
        ? -1
        : leadingIndex == 0 && text.startsWith(marker)
        ? 0
        : text.indexOf('\n$marker') + 1;
    if (start < 0) return TextSpan(text: text, style: style);
    if (!text.substring(start).startsWith(marker!)) {
      return TextSpan(text: text, style: style);
    }
    final newline = text.indexOf('\n', start);
    final end = newline < 0 ? text.length : newline;
    return TextSpan(
      style: style,
      children: [
        TextSpan(text: text.substring(0, start)),
        TextSpan(
          style: TextStyle(color: highlight),
          children: [
            TextSpan(
              text: marker,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: text.substring(start + marker.length, end)),
          ],
        ),
        TextSpan(text: text.substring(end)),
      ],
    );
  }

  static TextSpan seatSpan(
    ThemeData theme,
    HomeServiceSummaryData data, {
    required bool compact,
  }) => TextSpan(
    style: theme.textTheme.bodyMedium,
    children: [
      TextSpan(
        text: '${data.availableSeats}',
        style: theme.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: compact ? 24 : 36,
          color: theme.colorScheme.onSurface,
        ),
      ),
      TextSpan(text: '석 남음', style: theme.textTheme.bodyMedium),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (service == HomeService.seat && data.availableSeats != null) {
      return Text.rich(seatSpan(theme, data, compact: compact));
    }
    if (service == HomeService.menu) {
      final lines = data.status.split('\n');
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < lines.length; index++) ...[
            if (index > 0) const SizedBox(height: 10),
            Text.rich(
              TextSpan(
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                  fontWeight: FontWeight.w400,
                  color: data.leadingMenuIndex == index
                      ? theme.colorScheme.primary
                      : null,
                ),
                children: data.leadingMenuIndex == index
                    ? [
                        TextSpan(
                          text: lines[index].substring(0, 2),
                          semanticsLabel:
                              '${lines[index].substring(0, 2)}, 투표 수 우세',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        TextSpan(text: lines[index].substring(2)),
                      ]
                    : [TextSpan(text: lines[index])],
              ),
            ),
          ],
        ],
      );
    }
    return Text(
      data.status,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}

class _SummaryContent extends StatelessWidget {
  const _SummaryContent({
    required this.service,
    required this.data,
    required this.compact,
    this.compression = 0,
  });

  final HomeService service;
  final HomeServiceSummaryData data;
  final bool compact;
  final double compression;

  static double minimumHeight(
    BuildContext context,
    HomeService service,
    HomeServiceSummaryData data,
    double width,
  ) {
    final theme = Theme.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    const spacing = HomeSummarySpacing(1);
    double measure(InlineSpan text, double maxWidth) {
      final painter = TextPainter(
        text: text,
        textDirection: Directionality.of(context),
        textScaler: scaler,
      )..layout(maxWidth: math.max(1.0, maxWidth));
      final height = painter.height;
      painter.dispose();
      return height;
    }

    final titleHeight = math.max(18.0, scaler.scale(14) * 1.25);
    final labelHeight = data.eyebrow != null && data.warning == null
        ? scaler.scale(12) * 1.3 + spacing.labelGap
        : 0.0;
    final statusHeight =
        service == HomeService.seat && data.availableSeats != null
        ? measure(
            _SummaryStatus.seatSpan(theme, data, compact: true),
            width - 20,
          )
        : scaler.scale(13) * 1.4;
    final warningHeight = data.warning == null
        ? 0.0
        : spacing.contentGap +
              math.max(
                16.0,
                measure(
                  TextSpan(
                    text: data.compactWarning ?? data.warning,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  width - 41,
                ),
              );
    return (2 * spacing.verticalPadding +
            titleHeight +
            labelHeight +
            spacing.contentGap +
            statusHeight +
            warningHeight)
        .ceilToDouble();
  }

  @override
  Widget build(BuildContext context) {
    final palette =
        Theme.of(context).extension<HongikPalette>() ?? HongikPalette.light;
    final textTheme = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (compact || constraints.maxWidth < 205) {
          final spacing = HomeSummarySpacing(compression);
          final scaler = MediaQuery.textScalerOf(context);
          final titleHeight = math.max(18.0, scaler.scale(14) * 1.25);
          final showEyebrow = data.eyebrow != null && data.warning == null;
          final labelHeight = !showEyebrow
              ? 0.0
              : scaler.scale(12) * 1.3 + spacing.labelGap;
          final warningText = data.compactWarning ?? data.warning;
          final warningStyle = (textTheme.bodySmall ?? const TextStyle())
              .copyWith(
                fontSize: 12,
                height: 1.3,
                color: palette.warning,
                fontWeight: FontWeight.w600,
              );
          var warningHeight = 0.0;
          if (data.warning != null) {
            final painter = TextPainter(
              text: TextSpan(text: warningText, style: warningStyle),
              textDirection: Directionality.of(context),
              textScaler: scaler,
            )..layout(maxWidth: math.max(0.0, constraints.maxWidth - 41));
            warningHeight = math.max(16.0, painter.height) + spacing.contentGap;
            painter.dispose();
          }
          final statusLines = constraints.maxHeight.isFinite
              ? ((constraints.maxHeight -
                            2 * spacing.verticalPadding -
                            spacing.contentGap -
                            titleHeight -
                            labelHeight -
                            warningHeight) /
                        (scaler.scale(13) * 1.4))
                    .floor()
                    .clamp(1, 4)
              : 4;
          return Center(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 10,
                vertical: spacing.verticalPadding,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        data.attentionKey != null
                            ? Icons.check_circle_rounded
                            : service.icon,
                        color: service.summaryIconColor(Theme.of(context)),
                        size: 18,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          service.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.labelLarge?.copyWith(
                            fontSize: 14,
                            height: 1.25,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: palette.textSecondary,
                        size: 16,
                      ),
                    ],
                  ),
                  if (showEyebrow) ...[
                    SizedBox(height: spacing.labelGap),
                    Text(
                      data.eyebrow!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        height: 1.3,
                        color: data.attentionKey != null
                            ? palette.brandNavy
                            : palette.textSecondary,
                        fontWeight: data.attentionKey != null
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                  SizedBox(height: spacing.contentGap),
                  Flexible(
                    child:
                        service == HomeService.seat &&
                            data.availableSeats != null
                        ? _SummaryStatus(
                            service: service,
                            data: data,
                            compact: true,
                          )
                        : service == HomeService.menu &&
                              data.leadingMenuIndex != null
                        ? Text.rich(
                            _SummaryStatus.menuSpan(
                              data.secondary == null
                                  ? data.status
                                  : '${data.status} · ${data.secondary}',
                              data.leadingMenuIndex,
                              textTheme.bodySmall?.copyWith(
                                fontSize: 13,
                                height: 1.4,
                                fontWeight: FontWeight.w600,
                              ),
                              Theme.of(context).colorScheme.primary,
                            ),
                            maxLines: statusLines,
                            overflow: TextOverflow.ellipsis,
                          )
                        : Text(
                            data.secondary == null
                                ? data.status
                                : '${data.status} · ${data.secondary}',
                            maxLines: statusLines,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(
                              fontSize: 13,
                              height: 1.4,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                  if (data.warning != null) ...[
                    SizedBox(height: spacing.contentGap),
                    Tooltip(
                      message: warningText == data.warning ? '' : data.warning!,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 16,
                            color: palette.warning,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(warningText!, style: warningStyle),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 17,
            vertical: 17 - 9 * compression,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: service.iconBackgroundColor(Theme.of(context)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      data.attentionKey != null
                          ? Icons.check_circle_rounded
                          : service.icon,
                      color: service.iconColor(Theme.of(context)),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      service.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: palette.textSecondary,
                  ),
                ],
              ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 10 - 6 * compression),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (data.eyebrow != null) ...[
                      Text(
                        data.eyebrow!,
                        style: textTheme.bodySmall?.copyWith(
                          color: data.attentionKey != null
                              ? palette.brandNavy
                              : palette.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    _SummaryStatus(service: service, data: data),
                    if (data.secondary != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        data.secondary!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: palette.textSecondary,
                        ),
                      ),
                    ],
                    if (data.warning != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 16,
                            color: palette.warning,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              data.warning!,
                              style: textTheme.bodySmall?.copyWith(
                                color: palette.warning,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (data.facts.isNotEmpty)
                Column(
                  children: [
                    Divider(height: 1, color: palette.cardOutline),
                    const SizedBox(height: 9),
                    for (final fact in data.facts) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              fact.label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodySmall?.copyWith(
                                color: palette.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: Text(
                              fact.value,
                              textAlign: TextAlign.end,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                    ],
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}
