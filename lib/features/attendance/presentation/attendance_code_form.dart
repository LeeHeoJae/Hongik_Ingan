import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hongik_ingan/features/attendance/domain/lecture.dart';

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
  bool _finished = false;

  @override
  void dispose() {
    _controller.dispose();
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
    final colors = Theme.of(context).colorScheme;
    final courseCode = RegExp(
      r'^\[(\d+)\]\s*(?=\S)',
    ).firstMatch(widget.lecture.name);
    final courseTitle = courseCode == null
        ? widget.lecture.name
        : widget.lecture.name.substring(courseCode.end);
    final field = TextField(
      controller: _controller,
      autofocus: true,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.oneTimeCode],
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      maxLength: 4,
      textAlign: TextAlign.center,
      scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
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
      tooltip: '닫기',
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      icon: const Icon(Icons.close),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '출석 인증번호',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            cancel,
          ],
        ),
        const SizedBox(height: 4),
        Container(
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
        ),
        const SizedBox(height: 8),
        field,
        const SizedBox(height: 8),
        submit,
      ],
    );
  }
}
