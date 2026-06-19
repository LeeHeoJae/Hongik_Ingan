import 'package:flutter/material.dart';

class LoginForm extends StatefulWidget {
  final TextEditingController idController;
  final TextEditingController pwController;
  final bool isLoading;
  final bool rememberMe;
  final bool autoLogin;
  final ValueChanged<bool> onRememberMeChanged;
  final ValueChanged<bool> onAutoLoginChanged;
  final VoidCallback onLogin;

  const LoginForm({
    super.key,
    required this.idController,
    required this.pwController,
    required this.isLoading,
    required this.rememberMe,
    required this.autoLogin,
    required this.onRememberMeChanged,
    required this.onAutoLoginChanged,
    required this.onLogin,
  });

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildCheckboxTile({
    required String label,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 2.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: value,
                onChanged: onChanged,
                activeColor: colorScheme.primary,
                checkColor: colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                side: BorderSide(
                  color: colorScheme.onSurface.withValues(alpha: 0.3),
                  width: 1.5,
                ),
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: value
                    ? colorScheme.primary
                    : colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: value ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Column(
          children: [
            TextField(
              controller: widget.idController,
              keyboardType: TextInputType.text,
              style: TextStyle(color: colorScheme.onSurface),
              decoration: InputDecoration(
                labelText: '학번',
                labelStyle: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                prefixIcon: Icon(
                  Icons.badge_outlined,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: widget.idController,
                  builder: (context, value, child) {
                    if (value.text.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return IconButton(
                      icon: Icon(
                        Icons.cancel,
                        size: 20,
                        color: colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                      onPressed: () => widget.idController.clear(),
                    );
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: colorScheme.onSurface.withValues(alpha: 0.12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _PasswordTextField(controller: widget.pwController),
            const SizedBox(height: 24),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  _buildCheckboxTile(
                    label: '정보 저장',
                    value: widget.rememberMe,
                    onChanged: (val) =>
                        widget.onRememberMeChanged(val ?? false),
                  ),
                  const SizedBox(width: 6),
                  _buildCheckboxTile(
                    label: '자동 로그인',
                    value: widget.autoLogin,
                    onChanged: (val) => widget.onAutoLoginChanged(val ?? false),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 60,
              width: double.infinity,
              child: ElevatedButton(
                onPressed: widget.isLoading ? null : widget.onLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: widget.isLoading
                      ? SizedBox(
                          key: const ValueKey('loading'),
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: colorScheme.onPrimary,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          '통합 로그인',
                          key: ValueKey('text'),
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
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

class _PasswordTextField extends StatefulWidget {
  const _PasswordTextField({required this.controller});

  final TextEditingController controller;

  @override
  State<_PasswordTextField> createState() => _PasswordTextFieldState();
}

class _PasswordTextFieldState extends State<_PasswordTextField> {
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return TextField(
      controller: widget.controller,
      obscureText: _obscurePassword,
      style: TextStyle(color: colorScheme.onSurface),
      decoration: InputDecoration(
        labelText: '클래스넷 비밀번호',
        labelStyle: TextStyle(
          color: colorScheme.onSurface.withValues(alpha: 0.6),
        ),
        prefixIcon: Icon(
          Icons.lock_outline_rounded,
          color: colorScheme.onSurface.withValues(alpha: 0.6),
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
                return IconButton(
                  icon: Icon(
                    Icons.cancel,
                    size: 20,
                    color: colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                  onPressed: () => widget.controller.clear(),
                );
              },
            ),
            IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                size: 20,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ],
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: colorScheme.onSurface.withValues(alpha: 0.12),
          ),
        ),
      ),
    );
  }
}
