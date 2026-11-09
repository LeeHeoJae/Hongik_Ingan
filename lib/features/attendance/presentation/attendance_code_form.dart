import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:hongik_ingan/core/presentation/app_motion.dart';
import 'package:hongik_ingan/core/presentation/widgets/app_animated_switcher.dart';
import 'package:hongik_ingan/core/presentation/widgets/code_entry_controls.dart';
import 'package:hongik_ingan/features/attendance/domain/attendance_submission_result.dart';
import 'package:hongik_ingan/features/attendance/domain/lecture.dart';
import 'attendance_dialog_state.dart';
import 'attendance_dialog_motion.dart';
import 'attendance_result_dialog.dart';

/// Uses the dialog surface's staged fade instead of fading text over the page.
class AttendanceCodeRoute<T> extends DialogRoute<T> {
  AttendanceCodeRoute({required super.context, required super.builder})
    : _reduceMotion = MediaQuery.disableAnimationsOf(context),
      super(barrierDismissible: false, useSafeArea: false);

  final bool _reduceMotion;

  @override
  Duration get transitionDuration =>
      _reduceMotion ? Duration.zero : const Duration(milliseconds: 180);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}

class AttendanceCodeDialog extends StatefulWidget {
  const AttendanceCodeDialog({
    super.key,
    required this.lecture,
    required this.onSubmit,
    required this.onCancel,
    this.onRetry,
    this.flow,
  });

  final Lecture lecture;
  final ValueChanged<String> onSubmit;
  final VoidCallback onCancel;
  final VoidCallback? onRetry;
  final ValueListenable<AttendanceDialogState>? flow;

  @override
  State<AttendanceCodeDialog> createState() => _AttendanceCodeDialogState();
}

class _AttendanceCodeDialogState extends State<AttendanceCodeDialog>
    with SingleTickerProviderStateMixin {
  Animation<double>? _routeAnimation;
  MediaQueryData? _closingMedia;
  MediaQueryData? _submittedMedia;
  final _inputKey = GlobalKey();
  late final _geometry = AttendanceDialogGeometry(
    AnimationController(
      vsync: this,
      duration: AppMotion.contentDuration,
      value: 1,
    ),
  );

  @override
  void initState() {
    super.initState();
    widget.flow?.addListener(_onFlowChanged);
  }

  @override
  void didUpdateWidget(AttendanceCodeDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.flow != widget.flow) {
      oldWidget.flow?.removeListener(_onFlowChanged);
      widget.flow?.addListener(_onFlowChanged);
    }
  }

  void _onFlowChanged() {
    if (!mounted) return;
    if (widget.flow!.value.stage == AttendanceDialogStage.input) {
      _submittedMedia = null;
    }
    if (widget.flow!.value.stage != AttendanceDialogStage.input &&
        _submittedMedia == null) {
      _submittedMedia = MediaQuery.of(context);
      FocusScope.of(context).unfocus();
    }
    setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animation = ModalRoute.of(context)?.animation;
    if (animation != _routeAnimation) {
      _routeAnimation?.removeStatusListener(_onStatus);
      _routeAnimation = animation;
      animation?.addStatusListener(_onStatus);
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.reverse && mounted) {
      _geometry.frozen = true;
      _geometry.controller.stop();
      setState(() => _closingMedia = MediaQuery.of(context));
    }
  }

  @override
  void dispose() {
    widget.flow?.removeListener(_onFlowChanged);
    _routeAnimation?.removeStatusListener(_onStatus);
    _geometry.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final animation = media.disableAnimations
        ? kAlwaysCompleteAnimation
        : _routeAnimation ?? kAlwaysCompleteAnimation;
    final submittedMedia = _submittedMedia;
    final pinnedMedia =
        _closingMedia ??
        submittedMedia?.copyWith(
          viewInsets: media.viewInsets.bottom == 0
              ? EdgeInsets.zero
              : submittedMedia.viewInsets,
        );
    return PopScope(
      canPop: widget.flow?.value.stage != AttendanceDialogStage.processing,
      child: MediaQuery(
        data:
            pinnedMedia?.copyWith(
              size: media.size,
              textScaler: media.textScaler,
              disableAnimations: media.disableAnimations,
            ) ??
            media,
        child: SafeArea(
          child: IgnorePointer(
            ignoring: _closingMedia != null,
            child: ExcludeFocus(
              excluding: _closingMedia != null,
              child: ExcludeSemantics(
                excluding: _closingMedia != null,
                child: Builder(
                  builder: (context) => FadeTransition(
                    opacity: animation.drive(
                      CurveTween(curve: const Interval(0, 0.25)),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final verticalInset =
                            constraints.maxHeight -
                                    MediaQuery.viewInsetsOf(context).bottom <
                                320
                            ? 4.0
                            : 12.0;
                        _geometry
                          ..targetInset = MediaQuery.viewInsetsOf(
                            context,
                          ).bottom
                          ..enabled = !media.disableAnimations;
                        _geometry.hold =
                            submittedMedia != null &&
                            media.viewInsets.bottom > 0;
                        final surface = Dialog(
                          alignment: widget.flow == null
                              ? null
                              : Alignment.topCenter,
                          insetPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: verticalInset,
                          ),
                          constraints: const BoxConstraints(maxWidth: 360),
                          insetAnimationDuration:
                              widget.flow == null && !media.disableAnimations
                              ? AppMotion.contentDuration
                              : Duration.zero,
                          insetAnimationCurve: Curves.easeInOutCubic,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: FadeTransition(
                            opacity: animation.drive(
                              CurveTween(
                                curve: const Interval(
                                  0.25,
                                  1,
                                  curve: Curves.easeOutCubic,
                                ),
                              ),
                            ),
                            child: _buildContent(context),
                          ),
                        );
                        if (widget.flow == null) return surface;
                        return AttendanceDialogPlacement(
                          geometry: _geometry,
                          verticalInset: verticalInset,
                          child: MediaQuery.removeViewInsets(
                            context: context,
                            removeBottom: true,
                            child: surface,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final flow = widget.flow?.value;
    final input = AttendanceCodeForm(
      key: _inputKey,
      lecture: widget.lecture,
      onSubmit: widget.onSubmit,
      onCancel: widget.onCancel,
      onRetry: widget.onRetry,
      flow: flow,
      geometry: flow == null ? null : _geometry,
    );
    return input;
  }
}

class _AttendanceStageBody extends StatelessWidget {
  const _AttendanceStageBody({required this.stage, required this.child});

  final AttendanceDialogStage stage;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return LayoutBuilder(
      builder: (context, constraints) => AppAnimatedSwitcher(
        switchInCurve: const Interval(0.35, 1, curve: Curves.easeOutCubic),
        switchOutCurve: const Interval(0.6, 1, curve: Curves.easeInCubic),
        layoutBuilder: AppAnimatedSwitcher.layoutForCurrentChild(
          constraints.maxWidth,
        ),
        child: KeyedSubtree(key: ValueKey(stage), child: child),
      ),
    );
  }
}

class AttendanceCodeForm extends StatefulWidget {
  const AttendanceCodeForm({
    super.key,
    required this.lecture,
    required this.onSubmit,
    required this.onCancel,
    this.onRetry,
    this.flow,
    this.geometry,
  });

  final Lecture lecture;
  final ValueChanged<String> onSubmit;
  final VoidCallback onCancel;
  final VoidCallback? onRetry;
  final AttendanceDialogState? flow;
  final AttendanceDialogGeometry? geometry;

  @override
  State<AttendanceCodeForm> createState() => _AttendanceCodeFormState();
}

class _AttendanceCodeFormState extends State<AttendanceCodeForm> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  final _fieldKey = GlobalKey();
  double? _availableHeight;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    widget.geometry?.controller.addStatusListener(_onGeometryStatus);
  }

  @override
  void didUpdateWidget(AttendanceCodeForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.flow?.stage == AttendanceDialogStage.result &&
        widget.flow?.stage == AttendanceDialogStage.input) {
      _finished = false;
      _controller.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
    if (oldWidget.geometry != widget.geometry) {
      oldWidget.geometry?.controller.removeStatusListener(_onGeometryStatus);
      widget.geometry?.controller.addStatusListener(_onGeometryStatus);
    }
  }

  void _onGeometryStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      // Target constraints were measured before the animated surface shrank.
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealField());
    }
  }

  void _revealField() {
    if (!mounted || !_focusNode.hasFocus || _finished) return;
    final fieldContext = _fieldKey.currentContext;
    if (fieldContext != null) {
      Scrollable.ensureVisible(
        fieldContext,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    }
  }

  @override
  void dispose() {
    widget.geometry?.controller.removeStatusListener(_onGeometryStatus);
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_finished || _controller.text.length != 4) return;
    _finished = true;
    FocusScope.of(context).unfocus();
    widget.onSubmit(_controller.text);
  }

  void _cancel() {
    if (_finished) return;
    _finished = true;
    FocusScope.of(context).unfocus();
    widget.onCancel();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final flow = widget.flow;
    final stage = flow?.stage ?? AttendanceDialogStage.input;
    final processing = stage == AttendanceDialogStage.processing;
    final result = stage == AttendanceDialogStage.result;
    final canRetry =
        result &&
        flow!.result!.outcome == AttendanceOutcome.failure &&
        widget.onRetry != null;
    final title = switch (stage) {
      AttendanceDialogStage.input => '출석 인증번호',
      AttendanceDialogStage.processing => '출석 처리 중',
      AttendanceDialogStage.result => '출결 안내',
    };
    final actionLabel = processing
        ? '처리 중'
        : result
        ? (canRetry ? '다시 입력' : '확인')
        : '제출';
    final field = CodeEntryField(
      fieldKey: _fieldKey,
      controller: _controller,
      focusNode: _focusNode,
      length: 4,
      label: '인증번호 4자리',
      onChanged: (_) => setState(() {}),
      onSubmitted: (_) => _submit(),
    );
    final submit = CodeEntryAction(
      onPressed: processing
          ? null
          : result
          ? canRetry
                ? widget.onRetry
                : () => Navigator.of(context).pop()
          : _controller.text.length == 4
          ? _submit
          : null,
      label: actionLabel,
    );
    final heading = CodeEntryHeading(
      title: title,
      onClose: processing
          ? null
          : result
          ? () => Navigator.of(context).pop()
          : _cancel,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        // The shared frame measures its target against the keyboard, while its
        // current surface remains free to animate from the previous height.
        // Without a shared frame, Dialog already removed the keyboard insets.
        final availableHeight =
            (constraints.maxHeight - (widget.geometry?.targetInset ?? 0)).clamp(
              0.0,
              constraints.maxHeight,
            );
        final width = (constraints.maxWidth - 32).clamp(1.0, double.infinity);
        final titleHeight =
            (_textHeight(
                      context,
                      title,
                      DefaultTextStyle.of(
                        context,
                      ).style.merge(CodeEntryHeading.titleStyle),
                      (width - 48).clamp(1.0, double.infinity),
                    ) +
                    16)
                .clamp(48.0, double.infinity);
        final buttonHeight =
            (_textHeight(
                      context,
                      actionLabel,
                      theme.textTheme.labelLarge!,
                      (width - 32).clamp(1.0, double.infinity),
                    ) +
                    24)
                .clamp(48.0, double.infinity);
        final labelTopPadding = MediaQuery.textScalerOf(context).scale(8);
        final fieldHeight =
            _textHeight(
              context,
              '0000',
              theme.textTheme.titleMedium!.copyWith(fontSize: 24),
              width,
            ) +
            40;
        // Use the same spacing in every stage, even as the body changes height.
        final compact = availableHeight < 320;
        final padding = EdgeInsets.fromLTRB(
          16,
          compact ? 4 : 8,
          16,
          compact ? 8 : 16,
        );
        final gap = compact ? 4.0 : 8.0;
        final scrollEverything =
            availableHeight <
            titleHeight +
                buttonHeight +
                fieldHeight +
                padding.vertical +
                4 +
                gap;

        if (_availableHeight != availableHeight) {
          _availableHeight = availableHeight;
          WidgetsBinding.instance.addPostFrameCallback((_) => _revealField());
        }

        final body = _AttendanceStageBody(
          stage: stage,
          child: switch (stage) {
            AttendanceDialogStage.input => Padding(
              padding: EdgeInsets.only(top: labelTopPadding),
              child: field,
            ),
            AttendanceDialogStage.processing => Semantics(
              liveRegion: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(flow!.message)),
                  ],
                ),
              ),
            ),
            AttendanceDialogStage.result => AttendanceResultDialog(
              result: flow!.result!,
              bodyOnly: true,
            ),
          },
        );
        Widget scrollable(Widget child, String name) => Scrollbar(
          key: ValueKey('${name}-${stage.name}'),
          controller: _scrollController,
          thumbVisibility: true,
          notificationPredicate: (notification) =>
              defaultScrollNotificationPredicate(notification) &&
              (widget.geometry?.targetNeedsScrollbar ?? true),
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(
              context,
            ).copyWith(scrollbars: false),
            child: SingleChildScrollView(
              key: ValueKey(name),
              controller: _scrollController,
              child: child,
            ),
          ),
        );

        final geometry = widget.geometry;
        if (geometry != null) {
          return AttendanceDialogFrame(
            geometry: geometry,
            padding: scrollEverything ? EdgeInsets.zero : padding,
            gap: scrollEverything ? 0 : gap,
            header: scrollEverything ? const SizedBox.shrink() : heading,
            body: scrollEverything
                ? scrollable(
                    Padding(
                      padding: padding,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          heading,
                          const SizedBox(height: 4),
                          body,
                          SizedBox(height: gap),
                          submit,
                        ],
                      ),
                    ),
                    'attendance-code-scroll-all',
                  )
                : scrollable(body, 'attendance-code-scroll-body'),
            action: scrollEverything ? const SizedBox.shrink() : submit,
          );
        }
        if (scrollEverything) {
          return scrollable(
            Padding(
              padding: padding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  heading,
                  const SizedBox(height: 4),
                  body,
                  SizedBox(height: gap),
                  submit,
                ],
              ),
            ),
            'attendance-code-scroll-all',
          );
        }
        return Padding(
          padding: padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              heading,
              const SizedBox(height: 4),
              Flexible(child: scrollable(body, 'attendance-code-scroll-body')),
              SizedBox(height: gap),
              submit,
            ],
          ),
        );
      },
    );
  }
}

double _textHeight(
  BuildContext context,
  String text,
  TextStyle style,
  double width,
) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  )..layout(maxWidth: width);
  final height = painter.height;
  painter.dispose();
  return height;
}
