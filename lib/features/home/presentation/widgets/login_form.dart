import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hongik_ingan/core/theme/color.dart';

const _repositoryUri = 'https://github.com/LeeHeoJae/Hongik_Ingan';

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
  final FocusNode _passwordFocusNode = FocusNode();

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
    _passwordFocusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _submitLogin() {
    if (!widget.isLoading) {
      widget.onLogin();
    }
  }

  Future<void> _showCredentialInfo() {
    final platformMessage = kIsWeb
        ? '웹에서는 브라우저 보안 제약으로 인증 요청이 프록시를 잠시 거쳐요. 로그인 정보는 서버에 별도로 저장하지 않아요.'
        : '저장을 선택한 로그인 정보는 기기의 보안 저장소에 보관돼요.';

    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('로그인 정보 처리 안내'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _CredentialInfoRow(
                icon: Icons.shield_outlined,
                title: '인증 정보 처리',
                description: platformMessage,
              ),
              const SizedBox(height: 18),
              const _CredentialInfoRow(
                icon: Icons.phonelink_lock_outlined,
                title: '자동 로그인 주의',
                description: '저장된 정보로 로그인을 시도하므로 공용 기기에서는 사용하지 마세요.',
              ),
              const SizedBox(height: 18),
              const _CredentialInfoRow(
                icon: Icons.code_rounded,
                title: '비공식 오픈소스 앱',
                description: '홍익대학교 공식 앱이 아닌, 개인이 개발한 프로젝트이며 소스 코드를 공개하고 있어요.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => launchUrl(
              Uri.parse(_repositoryUri),
              mode: LaunchMode.externalApplication,
            ),
            child: const Text('소스 코드 보기'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
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
    final palette =
        Theme.of(context).extension<HongikPalette>() ?? HongikPalette.light;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: AutofillGroup(
          child: Column(
            children: [
              TextField(
                controller: widget.idController,
                keyboardType: TextInputType.text,
                autofillHints: const [AutofillHints.username],
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _passwordFocusNode.requestFocus(),
                style: TextStyle(color: colorScheme.onSurface),
                decoration: InputDecoration(
                  labelText: '학번',
                  labelStyle: TextStyle(color: palette.textSecondary),
                  prefixIcon: Icon(
                    Icons.badge_outlined,
                    color: palette.textSecondary,
                  ),
                  suffixIcon: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: widget.idController,
                    builder: (context, value, child) {
                      if (value.text.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return IconButton(
                        tooltip: '학번 지우기',
                        icon: Icon(
                          Icons.cancel,
                          size: 20,
                          color: palette.textSecondary.withValues(alpha: 0.72),
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
              _PasswordTextField(
                controller: widget.pwController,
                focusNode: _passwordFocusNode,
                onSubmitted: _submitLogin,
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
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
                      onChanged: (val) =>
                          widget.onAutoLoginChanged(val ?? false),
                    ),
                  ],
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _showCredentialInfo,
                  icon: const Icon(Icons.lock_outline_rounded, size: 16),
                  label: const Text(
                    '로그인 정보 처리 안내',
                    style: TextStyle(fontSize: 13),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    minimumSize: const Size(44, 44),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withValues(
                        alpha: widget.isLoading
                            ? colorScheme.brightness == Brightness.dark
                                  ? 0.05
                                  : 0.08
                            : colorScheme.brightness == Brightness.dark
                            ? 0.1
                            : 0.22,
                      ),
                      blurRadius: colorScheme.brightness == Brightness.dark
                          ? 14
                          : 22,
                      spreadRadius: colorScheme.brightness == Brightness.dark
                          ? 0
                          : 1,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: SizedBox(
                  height: 60,
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: widget.isLoading ? null : _submitLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: colorScheme.brightness == Brightness.dark
                          ? 2
                          : 3,
                      shadowColor: colorScheme.primary.withValues(
                        alpha: colorScheme.brightness == Brightness.dark
                            ? 0.08
                            : 0.16,
                      ),
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmitted;

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
      obscureText: _obscurePassword,
      keyboardType: TextInputType.visiblePassword,
      autofillHints: const [AutofillHints.password],
      textInputAction: TextInputAction.done,
      autocorrect: false,
      enableSuggestions: false,
      onSubmitted: (_) => widget.onSubmitted(),
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
                return IconButton(
                  tooltip: '비밀번호 지우기',
                  icon: Icon(
                    Icons.cancel,
                    size: 20,
                    color: palette.textSecondary.withValues(alpha: 0.72),
                  ),
                  onPressed: () => widget.controller.clear(),
                );
              },
            ),
            IconButton(
              tooltip: _obscurePassword ? '비밀번호 표시' : '비밀번호 숨기기',
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                size: 20,
                color: palette.textSecondary,
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
