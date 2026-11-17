part of 'login_form.dart';

class _CredentialInfoRow extends StatelessWidget {
  const _CredentialInfoRow({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final palette =
        Theme.of(context).extension<HongikPalette>() ?? HongikPalette.light;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 21, color: colorScheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(color: palette.textSecondary, height: 1.45),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PasswordTextField extends StatefulWidget {
  const _PasswordTextField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
    required this.isLoading,
    this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmitted;
  final bool isLoading;
  final VoidCallback? onChanged;

  @override
  State<_PasswordTextField> createState() => _PasswordTextFieldState();
}

class _PasswordTextFieldState extends State<_PasswordTextField> {
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final palette =
        Theme.of(context).extension<HongikPalette>() ?? HongikPalette.light;

    return TextField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      readOnly: widget.isLoading,
      obscureText: _obscurePassword,
      keyboardType: TextInputType.visiblePassword,
      autofillHints: const [AutofillHints.password],
      textInputAction: TextInputAction.done,
      autocorrect: false,
      enableSuggestions: false,
      onSubmitted: (_) => widget.onSubmitted(),
      onChanged: (_) => widget.onChanged?.call(),
      style: TextStyle(color: colorScheme.onSurface),
      decoration: InputDecoration(
        labelText: '클래스넷 비밀번호',
        labelStyle: TextStyle(color: palette.textSecondary),
        prefixIcon: Icon(
          Icons.lock_outline_rounded,
          color: palette.textSecondary,
        ),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: widget.controller,
              builder: (context, value, child) {
                if (value.text.isEmpty) {
                  return const SizedBox.shrink();
                }
                return _loginFocusOrder(
                  5,
                  IconButton(
                    icon: Icon(
                      Icons.cancel,
                      semanticLabel: '비밀번호 지우기',
                      size: 20,
                      color: palette.textSecondary.withValues(alpha: 0.72),
                    ),
                    onPressed: widget.isLoading
                        ? null
                        : () {
                            widget.controller.clear();
                            widget.onChanged?.call();
                          },
                  ),
                );
              },
            ),
            _loginFocusOrder(
              6,
              IconButton(
                tooltip: _obscurePassword ? '비밀번호 표시' : '비밀번호 숨기기',
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  size: 20,
                  color: palette.textSecondary,
                ),
                onPressed: widget.isLoading
                    ? null
                    : () =>
                          setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ],
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: palette.controlOutline),
        ),
      ),
    );
  }
}
