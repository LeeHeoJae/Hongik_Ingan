import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CodeEntryField extends StatelessWidget {
  const CodeEntryField({
    super.key,
    this.fieldKey,
    required this.controller,
    required this.length,
    required this.label,
    required this.onChanged,
    required this.onSubmitted,
    this.focusNode,
    this.readOnly = false,
    this.error,
  });

  final Key? fieldKey;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final int length;
  final String label;
  final bool readOnly;
  final String? error;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) => TextField(
    key: fieldKey,
    controller: controller,
    focusNode: focusNode,
    autofocus: true,
    readOnly: readOnly,
    keyboardType: TextInputType.number,
    textInputAction: TextInputAction.done,
    autofillHints: const [AutofillHints.oneTimeCode],
    autocorrect: false,
    enableSuggestions: false,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    maxLength: length,
    textAlign: TextAlign.center,
    scrollPadding: const EdgeInsets.all(12),
    style: const TextStyle(fontSize: 24, letterSpacing: 8),
    decoration: InputDecoration(
      labelText: label,
      error: error == null ? null : Text(error!),
      floatingLabelBehavior: FloatingLabelBehavior.always,
      counterText: '',
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: const OutlineInputBorder(),
    ),
    onChanged: onChanged,
    onSubmitted: onSubmitted,
  );
}

class CodeEntryHeading extends StatelessWidget {
  const CodeEntryHeading({super.key, required this.title, this.onClose});

  static const titleStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    height: 1.4,
  );

  final String title;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Semantics(
            header: true,
            label: title,
            excludeSemantics: true,
            child: Text(title, style: titleStyle),
          ),
        ),
      ),
      IconButton(
        tooltip: '닫기',
        onPressed: onClose,
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        icon: const Icon(Icons.close, semanticLabel: '닫기'),
      ),
    ],
  );
}

class CodeEntryAction extends StatelessWidget {
  const CodeEntryAction({super.key, required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        enableFeedback: false,
        minimumSize: const Size(88, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        elevation: colors.brightness == Brightness.dark ? 0 : 1,
        shadowColor: colors.brightness == Brightness.dark
            ? Colors.transparent
            : Colors.black.withValues(alpha: 0.12),
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
      ),
      child: Text(label),
    );
  }
}
