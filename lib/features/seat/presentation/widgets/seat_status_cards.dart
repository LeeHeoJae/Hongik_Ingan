import 'package:flutter/material.dart';
import 'package:hongik_ingan/core/theme/color.dart';
import 'package:hongik_ingan/features/seat/domain/seat.dart';

class SeatSummaryCard extends StatelessWidget {
  const SeatSummaryCard({
    super.key,
    required this.summary,
    required this.compact,
  });

  final Seat summary;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final palette =
        Theme.of(context).extension<HongikPalette>() ?? HongikPalette.light;
    final usageValue = (summary.usageRate / 100).clamp(0.0, 1.0);
    final usageColor = _usageColor(context, summary.usageRate);

    return Container(
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: palette.cardSurfaceMuted,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.cardOutline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '사용 가능 좌석',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: palette.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '총',
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontSize: compact ? 17 : 20,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                          ),
                          TextSpan(
                            text: '${summary.availableSeats}',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  color: usageColor,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          TextSpan(
                            text: '석 남음',
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontSize: compact ? 16 : 18,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: usageColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '사용률 ${_formatRate(summary.usageRate)}',
                  style: TextStyle(
                    color: usageColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 4 : 5),
          _AnimatedSeatProgress(
            value: usageValue,
            color: usageColor,
            backgroundColor: palette.cardOutline,
            minHeight: compact ? 7 : 8,
          ),
          SizedBox(height: compact ? 7 : 8),
          Wrap(
            spacing: compact ? 8 : 10,
            runSpacing: compact ? 8 : 10,
            children: [
              _MetricPill(
                label: '전체',
                value: '${summary.totalSeats}석',
                compact: compact,
              ),
              _MetricPill(
                label: '사용',
                value: '${summary.usedSeats}석',
                compact: compact,
              ),
              if (!compact)
                _MetricPill(
                  label: '잔여',
                  value: '${summary.availableSeats}석',
                  compact: compact,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class SeatCard extends StatelessWidget {
  const SeatCard({super.key, required this.seat, required this.compact});

  final Seat seat;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final palette = theme.extension<HongikPalette>() ?? HongikPalette.light;

    final usageValue = (seat.usageRate / 100).clamp(0.0, 1.0).toDouble();
    final usageColor = _usageColor(context, seat.usageRate);
    final statusLabel = _statusLabel(seat);

    return Container(
      padding: EdgeInsets.all(compact ? 10 : 14),
      decoration: BoxDecoration(
        color: palette.cardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.cardOutline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  seat.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: usageColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: usageColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 12,
            runSpacing: 8,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${seat.availableSeats}',
                      style: TextStyle(
                        color: usageColor,
                        fontSize: compact ? 26 : 32,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextSpan(
                      text: '석 남음',
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: compact ? 14 : 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Text('전체 ${seat.totalSeats}석', style: _metaStyle(context)),
            ],
          ),
          SizedBox(height: compact ? 8 : 12),
          _AnimatedSeatProgress(
            value: usageValue,
            minHeight: compact ? 7 : 8,
            color: usageColor,
            backgroundColor: palette.cardSurfaceMuted,
          ),
          SizedBox(height: compact ? 7 : 8),
          Text(
            '사용률 ${_formatRate(seat.usageRate)}',
            style: _metaStyle(context),
          ),
        ],
      ),
    );
  }

  String _statusLabel(Seat seat) {
    if (seat.availableSeats <= 0) {
      return '만석';
    }

    final usageRate = seat.usageRate;
    if (usageRate >= 85) {
      return '혼잡';
    }
    if (usageRate >= 65) {
      return '다소 혼잡';
    }
    if (usageRate >= 40) {
      return '보통';
    }
    return '여유';
  }

  TextStyle? _metaStyle(BuildContext context) {
    final palette =
        Theme.of(context).extension<HongikPalette>() ?? HongikPalette.light;

    return Theme.of(context).textTheme.bodySmall?.copyWith(
      color: palette.textSecondary,
      fontWeight: FontWeight.w700,
      height: 1.1,
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.label,
    required this.value,
    required this.compact,
  });

  final String label;
  final String value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette =
        Theme.of(context).extension<HongikPalette>() ?? HongikPalette.light;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 7 : 9,
      ),
      decoration: BoxDecoration(
        color: palette.cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.cardOutline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: palette.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _AnimatedSeatProgress extends StatelessWidget {
  const _AnimatedSeatProgress({
    required this.value,
    required this.color,
    required this.backgroundColor,
    required this.minHeight,
  });

  final double value;
  final Color color;
  final Color backgroundColor;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, child) {
        return LinearProgressIndicator(
          value: animatedValue,
          minHeight: minHeight,
          borderRadius: BorderRadius.circular(999),
          color: color,
          backgroundColor: backgroundColor,
        );
      },
    );
  }
}

Color _usageColor(BuildContext context, double usageRate) {
  final palette =
      Theme.of(context).extension<HongikPalette>() ?? HongikPalette.light;
  if (usageRate >= 85) {
    return palette.seatCrowded;
  }
  if (usageRate >= 65) {
    return palette.warning;
  }
  if (usageRate >= 40) {
    return palette.seatModerate;
  }
  return palette.seatAvailable;
}

String _formatRate(double rate) {
  final normalized = rate.clamp(0, 100);
  if (normalized == normalized.roundToDouble()) {
    return '${normalized.toStringAsFixed(0)}%';
  }
  return '${normalized.toStringAsFixed(1)}%';
}
