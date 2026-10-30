import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hongik_ingan/core/presentation/app_motion.dart';
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
    this.centerLoginStatus = false,
  }) : assert(descriptionViewportLines == null || descriptionViewportLines > 0);

  final String title;
  final IconData icon;
  final String? description;
  final int? descriptionViewportLines;
  final bool reserveDescriptionSpace;
  final bool isError;
  final bool isReady;
  final bool centerLoginStatus;

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
      fontSize: MediaQuery.sizeOf(context).width >= 600 ? 18 : null,
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
        double measure(
          String text,
          TextStyle style,
          double width, {
          bool firstLineOnly = false,
        }) {
          final painter = TextPainter(
            text: TextSpan(text: text, style: style),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
            locale: Localizations.maybeLocaleOf(context),
          )..layout(maxWidth: width.clamp(1, double.infinity));
          final height = firstLineOnly
              ? painter.computeLineMetrics().firstOrNull?.height ??
                    painter.height
              : painter.height;
          painter.dispose();
          return height;
        }

        // Reserve ordinary messages only; long text remains free to grow.
        final titleHeight = measure(
          '출결 가능한 수업이 없어요',
          titleStyle,
          constraints.maxWidth - 24,
        );
        final titleLineHeight = measure(
          title,
          titleStyle,
          constraints.maxWidth - 24,
          firstLineOnly: true,
        );
        final descriptionHeight = measure(
          '출결 서버에 연결하지 못했어요.',
          descriptionStyle,
          constraints.maxWidth - 24,
        );
        final viewportLines = descriptionViewportLines;
        final hasDescription = description?.trim().isNotEmpty ?? false;
        if (centerLoginStatus) {
          return _CenteredLoginStatus(
            title: title,
            icon: icon,
            description: hasDescription ? description : null,
            titleStyle: titleStyle,
            descriptionStyle: descriptionStyle,
            color: color,
            titleLineHeight: titleLineHeight,
            descriptionLineHeight: measure(
              '설명',
              descriptionStyle,
              double.infinity,
            ),
            viewportLines: viewportLines,
            width: constraints.maxWidth,
          );
        }
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
                      SizedBox(
                        width: 18,
                        height: titleLineHeight,
                        child: Center(
                          child: Icon(icon, size: 18, color: color),
                        ),
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

class _CenteredLoginStatus extends StatefulWidget {
  const _CenteredLoginStatus({
    required this.title,
    required this.icon,
    required this.description,
    required this.titleStyle,
    required this.descriptionStyle,
    required this.color,
    required this.titleLineHeight,
    required this.descriptionLineHeight,
    required this.viewportLines,
    required this.width,
  });

  final String title;
  final IconData icon;
  final String? description;
  final TextStyle titleStyle;
  final TextStyle descriptionStyle;
  final Color color;
  final double titleLineHeight;
  final double descriptionLineHeight;
  final int? viewportLines;
  final double width;

  @override
  State<_CenteredLoginStatus> createState() => _CenteredLoginStatusState();
}

class _CenteredLoginStatusState extends State<_CenteredLoginStatus> {
  String? _visibleDescription;

  @override
  void initState() {
    super.initState();
    _visibleDescription = widget.description;
  }

  @override
  void didUpdateWidget(covariant _CenteredLoginStatus oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.description != null) _visibleDescription = widget.description;
  }

  @override
  Widget build(BuildContext context) {
    final hasDescription = widget.description != null;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : AppMotion.contentDuration;
    double textHeight(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        locale: Localizations.maybeLocaleOf(context),
      )..layout(maxWidth: (widget.width - 24).clamp(1, double.infinity));
      final height = painter.height;
      painter.dispose();
      return height;
    }

    final titleHeight = textHeight(widget.title, widget.titleStyle);
    final descriptionHeight = widget.viewportLines != null
        ? widget.descriptionLineHeight * widget.viewportLines!
        : _visibleDescription == null
        ? widget.descriptionLineHeight
        : textHeight(
            _visibleDescription!,
            widget.descriptionStyle,
          ).clamp(widget.descriptionLineHeight, double.infinity);
    const gap = 8.0;
    final slotHeight = titleHeight + gap + descriptionHeight;
    final titleTop = hasDescription ? 0.0 : (gap + descriptionHeight) / 2;

    return Semantics(
      container: true,
      explicitChildNodes: true,
      liveRegion: true,
      label: hasDescription
          ? '${widget.title}\n${widget.description}'
          : widget.title,
      child: SizedBox(
        height: slotHeight,
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: duration,
              curve: Curves.easeInOutCubic,
              top: titleTop,
              left: 0,
              right: 0,
              child: ExcludeSemantics(
                child: SizedBox(
                  height: titleHeight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 18,
                        height: widget.titleLineHeight,
                        child: Center(
                          child: Icon(
                            widget.icon,
                            size: 18,
                            color: widget.color,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(widget.title, style: widget.titleStyle),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            AnimatedPositioned(
              duration: duration,
              curve: Curves.easeInOutCubic,
              top: titleTop + titleHeight + gap,
              left: 24,
              right: 0,
              height: descriptionHeight,
              child: IgnorePointer(
                ignoring: !hasDescription,
                child: ExcludeFocus(
                  excluding: !hasDescription,
                  child: ExcludeSemantics(
                    excluding: !hasDescription,
                    child: AnimatedOpacity(
                      opacity: hasDescription ? 1 : 0,
                      duration: duration,
                      onEnd: () {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted &&
                              widget.description == null &&
                              _visibleDescription != null) {
                            setState(() => _visibleDescription = null);
                          }
                        });
                      },
                      child: widget.viewportLines == null
                          ? ExcludeSemantics(
                              child: Text(
                                _visibleDescription ?? '',
                                style: widget.descriptionStyle,
                              ),
                            )
                          : _ScrollableStatusDescription(
                              description: _visibleDescription,
                              style: widget.descriptionStyle,
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
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
