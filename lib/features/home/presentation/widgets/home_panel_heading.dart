import 'package:flutter/material.dart';
import 'package:hongik_ingan/core/theme/color.dart';
import '../layouts/home_service_workspace.dart';

class HomePanelHeading extends StatelessWidget {
  const HomePanelHeading({
    super.key,
    required this.service,
    required this.title,
    required this.subtitle,
    this.alternateSubtitle,
    this.trailing,
    this.trailingWidth = 44,
    this.onRefresh,
    this.isRefreshing = false,
    this.transition,
  });
  final HomeService service;
  final String title;
  final String subtitle;
  final String? alternateSubtitle;
  final Widget? trailing;
  final double trailingWidth;
  final VoidCallback? onRefresh;
  final bool isRefreshing;
  final Animation<double>? transition;

  @override
  Widget build(BuildContext context) {
    final trailing = this.trailing;
    final transition = this.transition;
    final alternateSubtitle = this.alternateSubtitle;
    final palette =
        Theme.of(context).extension<HongikPalette>() ?? HongikPalette.light;
    final subtitleStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: palette.textSecondary);
    final sharedHeadingSpace =
        service == HomeService.attendance &&
        MediaQuery.sizeOf(context).width < 600;
    final headingAction = trailing == null || transition == null
        ? trailing
        : AnimatedBuilder(
            animation: transition,
            child: FadeTransition(opacity: transition, child: trailing),
            builder: (context, child) => IgnorePointer(
              ignoring: transition.value == 0,
              child: ExcludeFocus(
                excluding: transition.value == 0,
                child: child!,
              ),
            ),
          );
    final headingText = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: service == HomeService.attendance ? 32 : 0,
          ),
          child: Padding(
            padding: EdgeInsets.only(
              right: sharedHeadingSpace ? trailingWidth : 0,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).brightness == Brightness.light
                          ? Theme.of(context).colorScheme.onSurface
                          : null,
                    ),
                  ),
                ),
                if (trailing != null && !sharedHeadingSpace)
                  SizedBox(
                    width: trailingWidth,
                    child: Align(
                      alignment: Alignment.topRight,
                      child: headingAction,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 3),
        Stack(
          children: [
            if (alternateSubtitle != null)
              Visibility(
                visible: false,
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                child: Text(alternateSubtitle, style: subtitleStyle),
              ),
            if (transition == null)
              Text(subtitle, style: subtitleStyle)
            else
              FadeTransition(
                opacity: transition,
                child: Text(subtitle, style: subtitleStyle),
              ),
          ],
        ),
      ],
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: service.iconBackgroundColor(Theme.of(context)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            service.icon,
            color: service.summaryIconColor(Theme.of(context)),
            size: 21,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: sharedHeadingSpace
              ? Stack(
                  children: [
                    headingText,
                    Positioned(
                      top: 0,
                      right: 0,
                      child: SizedBox(
                        width: trailingWidth,
                        child: headingAction,
                      ),
                    ),
                  ],
                )
              : headingText,
        ),
        if (onRefresh != null || isRefreshing)
          Semantics(
            container: true,
            label: isRefreshing ? '새로고침 중' : '새로고침',
            child: IconButton(
              onPressed: onRefresh,
              enableFeedback: false,
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              icon: isRefreshing
                  ? const SizedBox(
                      width: 19,
                      height: 19,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded),
            ),
          ),
      ],
    );
  }
}
