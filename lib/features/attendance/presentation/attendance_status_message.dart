import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hongik_ingan/core/theme/color.dart';

/// A persistent status slot shared by login and attendance.
class AttendanceStatusMessage extends StatelessWidget {
  const AttendanceStatusMessage({
    super.key,
    required this.title,
    required this.icon,
    this.description,
    this.descriptionViewportLines,
    this.reserveDescriptionSpace = true,
    this.isError = false,
    this.isReady = false,
  }) : assert(descriptionViewportLines == null || descriptionViewportLines > 0);

  final String title;
  final IconData icon;
  final String? description;
  final int? descriptionViewportLines;
  final bool reserveDescriptionSpace;
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
        final viewportLines = descriptionViewportLines;
        final hasDescription = description?.trim().isNotEmpty ?? false;
        final descriptionContent = viewportLines == null
            ? ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: reserveDescriptionSpace ? descriptionHeight : 0,
                ),
                child: description == null
                    ? const SizedBox.shrink()
                    : ExcludeSemantics(
                        child: Text(description!, style: descriptionStyle),
                      ),
              )
            : SizedBox(
                height:
                    measure('설명', descriptionStyle, double.infinity) *
                    viewportLines,
                child: _ScrollableStatusDescription(
                  description: description,
                  style: descriptionStyle,
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
              if (reserveDescriptionSpace || hasDescription) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 24),
                  child: descriptionContent,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ScrollableStatusDescription extends StatefulWidget {
  const _ScrollableStatusDescription({
    required this.description,
    required this.style,
  });

  final String? description;
  final TextStyle style;

  @override
  State<_ScrollableStatusDescription> createState() =>
      _ScrollableStatusDescriptionState();
}

class _ScrollableStatusDescriptionState
    extends State<_ScrollableStatusDescription> {
  final _scrollController = ScrollController();
  final _focusNode = FocusNode(debugLabel: 'login-status-description');
  bool _hasOverflow = false;
  bool _focused = false;

  bool _handleMetrics(ScrollMetricsNotification notification) {
    final hasOverflow = notification.metrics.maxScrollExtent > 0;
    if (hasOverflow != _hasOverflow) {
      setState(() => _hasOverflow = hasOverflow);
    }
    return false;
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (!_scrollController.hasClients ||
        (event is! KeyDownEvent && event is! KeyRepeatEvent)) {
      return KeyEventResult.ignored;
    }
    final position = _scrollController.position;
    final page = position.viewportDimension * 0.8;
    final line = position.viewportDimension / 2;
    final target = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowDown => position.pixels + line,
      LogicalKeyboardKey.arrowUp => position.pixels - line,
      LogicalKeyboardKey.pageDown => position.pixels + page,
      LogicalKeyboardKey.pageUp => position.pixels - page,
      LogicalKeyboardKey.home => position.minScrollExtent,
      LogicalKeyboardKey.end => position.maxScrollExtent,
      _ => null,
    };
    if (target == null) return KeyEventResult.ignored;
    _scrollController.jumpTo(
      target.clamp(position.minScrollExtent, position.maxScrollExtent),
    );
    return KeyEventResult.handled;
  }

  @override
  void didUpdateWidget(covariant _ScrollableStatusDescription oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.description != widget.description) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
      });
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      includeSemantics: false,
      canRequestFocus: _hasOverflow,
      onKeyEvent: _handleKey,
      onFocusChange: (focused) => setState(() => _focused = focused),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: _focused
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
          ),
        ),
        child: NotificationListener<ScrollMetricsNotification>(
          onNotification: _handleMetrics,
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(
              context,
            ).copyWith(scrollbars: false),
            child: Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _scrollController,
                primary: false,
                padding: const EdgeInsets.only(right: 12),
                child: widget.description == null
                    ? const SizedBox.shrink()
                    : ExcludeSemantics(
                        child: Text(widget.description!, style: widget.style),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
