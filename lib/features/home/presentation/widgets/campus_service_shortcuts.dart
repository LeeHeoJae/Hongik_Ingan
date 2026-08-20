import 'package:flutter/material.dart';
import 'package:hongik_ingan/core/theme/color.dart';
import 'package:hongik_ingan/features/home/presentation/widgets/panel_entrance_transition.dart';

class CampusServiceShortcuts extends StatefulWidget {
  const CampusServiceShortcuts({
    super.key,
    required this.onSeatTap,
    required this.onMenuTap,
    this.animateEntrance = false,
  });

  final VoidCallback onSeatTap;
  final VoidCallback onMenuTap;
  final bool animateEntrance;

  @override
  State<CampusServiceShortcuts> createState() => _CampusServiceShortcutsState();
}

class _CampusServiceShortcutsState extends State<CampusServiceShortcuts>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      value: widget.animateEntrance ? 0 : 1,
    );
    if (widget.animateEntrance) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette =
        Theme.of(context).extension<HongikPalette>() ?? HongikPalette.light;

    final menuCard = _CampusServiceShortcutCard(
      icon: Icons.restaurant_menu_rounded,
      title: '주간 식당 메뉴',
      iconColor: palette.warning,
      iconBackgroundColor: palette.warning.withValues(alpha: 0.12),
      onTap: widget.onMenuTap,
    );
    final seatCard = _CampusServiceShortcutCard(
      icon: Icons.local_library_rounded,
      title: '열람실 좌석 현황',
      iconColor: palette.brandBlue,
      iconBackgroundColor: palette.brandBlue.withValues(alpha: 0.1),
      onTap: widget.onSeatTap,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 300) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _animate(menuCard, 0.28, 0.76),
              const SizedBox(height: 10),
              _animate(seatCard, 0.42, 0.92),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _animate(menuCard, 0.28, 0.76)),
            const SizedBox(width: 10),
            Expanded(child: _animate(seatCard, 0.42, 0.92)),
          ],
        );
      },
    );
  }

  Widget _animate(Widget child, double begin, double end) {
    return PanelEntranceTransition(
      controller: _controller,
      begin: begin,
      end: end,
      slideOffset: 0.16,
      child: child,
    );
  }
}

class _CampusServiceShortcutCard extends StatelessWidget {
  const _CampusServiceShortcutCard({
    required this.icon,
    required this.title,
    required this.iconColor,
    required this.iconBackgroundColor,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final Color iconColor;
  final Color iconBackgroundColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final palette =
        Theme.of(context).extension<HongikPalette>() ?? HongikPalette.light;

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: iconColor.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: palette.cardSurface,
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: palette.cardOutline),
            ),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: iconBackgroundColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: iconColor, size: 25),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
