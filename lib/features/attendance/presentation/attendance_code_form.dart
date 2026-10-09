import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hongik_ingan/features/attendance/domain/lecture.dart';

class AttendanceCodeDialog extends StatelessWidget {
  const AttendanceCodeDialog({
    super.key,
    required this.lecture,
    required this.onSubmit,
    required this.onCancel,
  });

  final Lecture lecture;
  final ValueChanged<String> onSubmit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical:
            constraints.maxHeight - MediaQuery.viewInsetsOf(context).bottom <
                320
            ? 4
            : 12,
      ),
      constraints: const BoxConstraints(maxWidth: 360),
      insetAnimationDuration: Duration.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: AttendanceCodeForm(
        lecture: lecture,
        onSubmit: onSubmit,
        onCancel: onCancel,
      ),
    ),
  );
}

class AttendanceCodeForm extends StatefulWidget {
  const AttendanceCodeForm({
    super.key,
    required this.lecture,
    required this.onSubmit,
    required this.onCancel,
  });

  final Lecture lecture;
  final ValueChanged<String> onSubmit;
  final VoidCallback onCancel;

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
  void dispose() {
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
    final colors = Theme.of(context).colorScheme;
    final courseCode = RegExp(
      r'^\[(\d+)\]\s*(?=\S)',
    ).firstMatch(widget.lecture.name);
    final courseTitle = courseCode == null
        ? widget.lecture.name
        : widget.lecture.name.substring(courseCode.end);
    final field = TextField(
      key: _fieldKey,
      controller: _controller,
      focusNode: _focusNode,
      autofocus: true,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.oneTimeCode],
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      maxLength: 4,
      textAlign: TextAlign.center,
      scrollPadding: const EdgeInsets.all(12),
      style: const TextStyle(fontSize: 24, letterSpacing: 8),
      decoration: const InputDecoration(
        labelText: '인증번호 4자리',
        floatingLabelBehavior: FloatingLabelBehavior.always,
        counterText: '',
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(),
      ),
      onChanged: (_) => setState(() {}),
      onSubmitted: (_) => _submit(),
    );
    final submit = ElevatedButton(
      onPressed: _controller.text.length == 4 ? _submit : null,
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(88, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        elevation: colors.brightness == Brightness.dark ? 0 : 1,
        shadowColor: colors.brightness == Brightness.dark
            ? Colors.transparent
            : Colors.black.withValues(alpha: 0.12),
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
      ),
      child: const Text('제출'),
    );
    final cancel = IconButton(
      onPressed: _cancel,
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      icon: const Icon(Icons.close, semanticLabel: '닫기'),
    );

    const titleStyle = TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.bold,
      height: 1.4,
    );
    final heading = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Semantics(
              header: true,
              label: '출석 인증번호',
              excludeSemantics: true,
              child: const Wrap(
                spacing: 4,
                children: [
                  Text('출석', style: titleStyle),
                  Text('인증번호', style: titleStyle),
                ],
              ),
            ),
          ),
        ),
        cancel,
      ],
    );
    final course = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.primary.withValues(alpha: 0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              Icons.menu_book_rounded,
              size: 20,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  if (courseCode != null)
                    TextSpan(
                      text: '${courseCode.group(1)}  ',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  TextSpan(text: courseTitle),
                ],
              ),
              semanticsLabel: widget.lecture.name,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 1.35,
                color: colors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Dialog already removed keyboard insets. Use its remaining constraints.
        final width = (constraints.maxWidth - 32).clamp(1.0, double.infinity);
        final titleHeight =
            (_textHeight(
                      context,
                      '출석 인증번호',
                      DefaultTextStyle.of(context).style.merge(titleStyle),
                      (width - 48).clamp(1.0, double.infinity),
                    ) +
                    16)
                .clamp(48.0, double.infinity);
        final buttonHeight =
            (_textHeight(
                      context,
                      '제출',
                      theme.textTheme.labelLarge!,
                      (width - 32).clamp(1.0, double.infinity),
                    ) +
                    24)
                .clamp(48.0, double.infinity);
        final fieldHeight =
            _textHeight(
              context,
              '0000',
              theme.textTheme.titleMedium!.copyWith(fontSize: 24),
              width,
            ) +
            40;
        final courseHeight =
            _textHeight(
              context,
              widget.lecture.name,
              theme.textTheme.bodyMedium!.copyWith(fontSize: 15, height: 1.35),
              (width - 48).clamp(1.0, double.infinity),
            ) +
            16;
        final compact =
            constraints.maxHeight <
            titleHeight + courseHeight + fieldHeight + buttonHeight + 44;
        final padding = EdgeInsets.fromLTRB(
          16,
          compact ? 4 : 8,
          16,
          compact ? 8 : 16,
        );
        final gap = compact ? 4.0 : 8.0;
        final scrollEverything =
            constraints.maxHeight <
            titleHeight +
                buttonHeight +
                fieldHeight +
                padding.vertical +
                4 +
                gap;

        if (_availableHeight != constraints.maxHeight) {
          _availableHeight = constraints.maxHeight;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !_focusNode.hasFocus || _finished) return;
            final fieldContext = _fieldKey.currentContext;
            if (fieldContext != null) {
              Scrollable.ensureVisible(
                fieldContext,
                alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
              );
            }
          });
        }

        final body = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            course,
            SizedBox(height: gap),
            field,
          ],
        );
        Widget scrollable(Widget child, String name) => Scrollbar(
          controller: _scrollController,
          thumbVisibility: true,
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
