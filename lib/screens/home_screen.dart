import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hongik_ingan/controllers/home_controller.dart';

import '../core/app_info.dart';
import '../core/logger.dart';
import '../core/theme/color.dart';
import '../services/check_update.dart';
import 'widgets/dashboard.dart';
import 'widgets/login_form.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _pwController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(homeControllerProvider.notifier)
          .initializeApp(_idController, _pwController);
      ref.read(homeControllerProvider.notifier).fetchUpdateInfo();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _idController.dispose();
    _pwController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      final homeState = ref.read(homeControllerProvider);
      if (homeState.isLoggedIn) {
        ref
            .read(homeControllerProvider.notifier)
            .checkSessionValidityAndReact(
              _idController.text,
              _pwController.text,
            );
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final homeState = ref.watch(homeControllerProvider);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GestureDetector(
                  onLongPress: () async {
                    await shareLogFile();
                  },
                  child: Icon(
                    Icons.school_rounded,
                    size: 64,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '홍익인간',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: colorScheme.onSurface,
                    letterSpacing: -1.2,
                  ),
                ),
                Text(
                  '전자출결 쾌속 패스',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 48),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: homeState.isLoggedIn
                      ? Dashboard(
                          userId: homeState.userId ?? _idController.text,
                          onLogout: () {
                            ref.read(homeControllerProvider.notifier).logout();
                          },
                        )
                      : LoginForm(
                          idController: _idController,
                          pwController: _pwController,
                          isLoading: homeState.isLoading,
                          rememberMe: homeState.rememberMe,
                          autoLogin: homeState.autoLogin,
                          onRememberMeChanged: (val) {
                            ref
                                .read(homeControllerProvider.notifier)
                                .onRememberMeChanged(val);
                          },
                          onAutoLoginChanged: (val) {
                            ref
                                .read(homeControllerProvider.notifier)
                                .onAutoLoginChanged(val);
                          },
                          onLogin: () async {
                            final result = await ref
                                .read(homeControllerProvider.notifier)
                                .login(_idController.text, _pwController.text);
                            if (result != 'success') {
                              if (mounted) {
                                _showSnackBar('로그인 실패: 아이디 또는 비번을 확인하세요.');
                              }
                            }
                          },
                        ),
                ),
                const SizedBox(height: 16),
                Text(
                  homeState.statusMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colorScheme.onSurface, fontSize: 12),
                ),
                const SizedBox(height: 32),
                _buildVersionInfo(homeState.updateInfo),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVersionInfo(Map<String, String>? updateInfo) {
    final colorScheme = Theme.of(context).colorScheme;
    if (AppInfo.version.isEmpty) return const SizedBox.shrink();
    final hasUpdate = updateInfo != null;

    return Center(
      child: InkWell(
        onTap: hasUpdate
            ? () {
                showUpdateDialog(
                  updateInfo['notice']!,
                  updateInfo['currentVersion']!,
                  updateInfo['latestVersion']!,
                  updateInfo['updateUrl']!,
                );
              }
            : () {
                _showSnackBar('최신버전입니다!');
              },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasUpdate) ...[
                const Icon(Icons.update, color: AppColor.wowGreen, size: 18),
                const SizedBox(width: 8),
              ],
              Text(
                'v${AppInfo.version}',
                style: TextStyle(color: colorScheme.onSurface, fontSize: 12),
              ),
              Icon(Icons.chevron_right, color: colorScheme.onSurface, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
