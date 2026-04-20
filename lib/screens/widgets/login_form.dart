import 'package:flutter/material.dart';

class LoginForm extends StatefulWidget {
  final TextEditingController idController;
  final TextEditingController pwController;
  final bool isLoading;
  final bool rememberMe;
  final bool autoLogin;
  final bool autoAttendance;
  final ValueChanged<bool> onRememberMeChanged;
  final ValueChanged<bool> onAutoLoginChanged;
  final ValueChanged<bool> onAutoAttendanceChanged;
  final VoidCallback onLogin;

  const LoginForm({
    super.key,
    required this.idController,
    required this.pwController,
    required this.isLoading,
    required this.rememberMe,
    required this.autoLogin,
    required this.autoAttendance,
    required this.onRememberMeChanged,
    required this.onAutoLoginChanged,
    required this.onAutoAttendanceChanged,
    required this.onLogin,
  });

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  bool _obscurePassword = true;

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

    return Column(
      children: [
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: widget.idController,
          builder: (context, value, child) {
            return TextField(
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
                suffixIcon: value.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.cancel,
                          size: 20,
                          color: colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                        onPressed: () => widget.idController.clear(),
                      )
                    : null,
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
            );
          },
        ),
        const SizedBox(height: 16),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: widget.pwController,
          builder: (context, value, child) {
            return TextField(
              controller: widget.pwController,
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
                    if (value.text.isNotEmpty)
                      IconButton(
                        icon: Icon(
                          Icons.cancel,
                          size: 20,
                          color: colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                        onPressed: () => widget.pwController.clear(),
                      ),
                    IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        size: 20,
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ],
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
            );
          },
        ),
        const SizedBox(height: 24),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              _buildCheckboxTile(
                label: '정보 저장',
                value: widget.rememberMe,
                onChanged: (val) => widget.onRememberMeChanged(val ?? false),
              ),
              const SizedBox(width: 6),
              _buildCheckboxTile(
                label: '자동 로그인',
                value: widget.autoLogin,
                onChanged: (val) => widget.onAutoLoginChanged(val ?? false),
              ),
              const SizedBox(width: 6),
              _buildCheckboxTile(
                label: '출석창 바로 이동',
                value: widget.autoAttendance,
                onChanged: (val) =>
                    widget.onAutoAttendanceChanged(val ?? false),
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
            child: widget.isLoading
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: colorScheme.onPrimary,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    '통합 로그인',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ],
    );
  }
}
