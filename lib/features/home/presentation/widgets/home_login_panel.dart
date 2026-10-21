import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hongik_ingan/features/home/application/home_controller.dart';
import 'package:hongik_ingan/features/attendance/presentation/attendance_status_message.dart';
import 'home_login_transition.dart';
import 'login_form.dart';

class HomeLoginPanel extends ConsumerWidget {
  const HomeLoginPanel({
    super.key,
    required this.idController,
    required this.pwController,
    required this.onLogin,
    this.error,
  });
  final TextEditingController idController;
  final TextEditingController pwController;
  final Future<void> Function() onLogin;
  final String? error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(
      homeControllerProvider.select((state) => state.isLoading),
    );
    final rememberMe = ref.watch(
      homeControllerProvider.select((state) => state.rememberMe),
    );
    final autoLogin = ref.watch(
      homeControllerProvider.select((state) => state.autoLogin),
    );
    return LoginForm(
      presentationBuilder: (fields, action) => HomeLoginBody(
        status: HomeLoginStatus(error: error),
        fields: fields,
        action: action,
      ),
      idController: idController,
      pwController: pwController,
      isLoading: isLoading,
      rememberMe: rememberMe,
      autoLogin: autoLogin,
      onRememberMeChanged: (val) {
        ref.read(homeControllerProvider.notifier).onRememberMeChanged(val);
      },
      onAutoLoginChanged: (val) {
        ref.read(homeControllerProvider.notifier).onAutoLoginChanged(val);
      },
      onLogin: onLogin,
    );
  }
}

class HomeLoginStatus extends ConsumerWidget {
  const HomeLoginStatus({super.key, this.error});
  final String? error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(homeControllerProvider);
    final loginError = !home.isLoading && !home.isLoggedIn ? error : null;
    final status = home.isLoading
        ? home.loginStatus == LoginStatus.required
              ? LoginStatus.loggingIn
              : home.loginStatus
        : loginError != null
        ? LoginStatus.failed
        : home.loginStatus;
    final title = switch (status) {
      LoginStatus.required => '로그인이 필요해요',
      LoginStatus.checkingSession => '로그인 상태 확인 중',
      LoginStatus.loggingIn => '로그인 중',
      LoginStatus.recoveringSession => '다시 로그인 중',
      LoginStatus.failed => '로그인하지 못했어요',
      LoginStatus.expired => '다시 로그인이 필요해요',
      LoginStatus.verificationFailed => '로그인 상태 확인 실패',
    };
    final description = switch (status) {
      LoginStatus.failed => loginError ?? home.statusMessage,
      LoginStatus.expired => '세션이 만료됐어요.',
      LoginStatus.verificationFailed => '네트워크 연결을 확인해 주세요.',
      _ => null,
    };
    final isError =
        status == LoginStatus.failed ||
        status == LoginStatus.verificationFailed;
    return AttendanceStatusMessage(
      key: const ValueKey('login-status-message'),
      descriptionViewportLines: MediaQuery.sizeOf(context).width < 600
          ? null
          : 2,
      reserveDescriptionSpace: MediaQuery.sizeOf(context).width >= 600,
      title: title,
      description: description,
      isError: isError,
      icon: isError
          ? Icons.error_outline_rounded
          : home.isLoading
          ? Icons.refresh_rounded
          : Icons.lock_outline_rounded,
    );
  }
}
