import 'package:flutter/material.dart';
import 'package:hongik_ingan/core/theme/color.dart';
import 'package:hongik_ingan/features/seat/domain/seat.dart';

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
