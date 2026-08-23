import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hongik_ingan/core/app_info.dart';
import 'package:hongik_ingan/core/logging/logger.dart';
import 'package:hongik_ingan/core/presentation/widgets/app_animated_switcher.dart';
import 'package:hongik_ingan/core/theme/color.dart';
import 'package:hongik_ingan/features/home/application/home_controller.dart';
import 'package:hongik_ingan/features/cafeteria_menu/application/cafeteria_menu_controller.dart';
import 'package:hongik_ingan/features/cafeteria_menu/presentation/cafeteria_menu_bottom_sheet.dart';
import 'package:hongik_ingan/features/seat/application/seat_controller.dart';
import 'package:hongik_ingan/features/seat/presentation/seat_status_bottom_sheet.dart';
import 'package:hongik_ingan/features/update/check_update.dart';
import 'package:url_launcher/url_launcher.dart';

import 'layouts/home_compact_layout.dart';
import 'layouts/home_expanded_layout.dart';
import 'widgets/campus_service_shortcuts.dart';
import 'widgets/campus_services_panel.dart';
import 'widgets/login_form.dart';
import 'widgets/student_dashboard.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _pwController = TextEditingController();
  bool _campusServicesPrefetchStarted = false;
  bool _wasBackgrounded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(homeControllerProvider.notifier)
          .initializeApp(_idController, _pwController);
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

    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _wasBackgrounded = true;
      return;
    }

    if (state != AppLifecycleState.resumed || !_wasBackgrounded) {
      return;
    }

    _wasBackgrounded = false;
    final isLoggedIn = ref.read(homeControllerProvider).isLoggedIn;
    if (isLoggedIn) {
      unawaited(
        ref
            .read(homeControllerProvider.notifier)
            .revalidateSessionOnResume(_idController.text, _pwController.text),
      );
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

  void _showCampusServiceSheet(Widget sheet) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => sheet,
    );
  }

  Future<void> _showAppInfo() {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('앱 정보'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '홍익인간은 홍익대학교 공식 앱이 아닌, 개인이 개발한 오픈소스 프로젝트예요.',
                style: TextStyle(height: 1.5),
              ),
              if (AppInfo.version.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('버전 ${AppInfo.version}'),
              ],
              if (!kIsWeb) ...[
                const SizedBox(height: 12),
                const Text(
                  '문제가 생기면 아래 버튼으로 개인정보를 가린 진단 로그를 공유할 수 있어요.',
                  style: TextStyle(height: 1.5),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => launchUrl(
              Uri.parse('https://github.com/LeeHeoJae/Hongik_Ingan'),
              mode: LaunchMode.externalApplication,
            ),
            child: const Text('소스 코드'),
          ),
          if (!kIsWeb)
            const TextButton(onPressed: shareLogFile, child: Text('진단 로그 공유')),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  void _ensureCampusServicesPrefetch() {
    if (_campusServicesPrefetchStarted) return;
    _campusServicesPrefetchStarted = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 700), () {
        if (!mounted) return;
        unawaited(
          ref.read(cafeteriaMenuControllerProvider.notifier).fetchInitialMenu(),
        );
        unawaited(
          ref.read(seatControllerProvider.notifier).fetchSelectedStatus(),
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLoggedIn = ref.watch(
      homeControllerProvider.select((state) => state.isLoggedIn),
    );

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final showExpandedLayout =
                constraints.maxWidth >= 900 && constraints.maxHeight >= 560;
            final centerExpandedPanels =
                constraints.maxWidth >= 900 && constraints.maxHeight >= 760;

            if (showExpandedLayout) {
              _ensureCampusServicesPrefetch();
              return _buildExpandedLayout(
                context,
                colorScheme,
                isLoggedIn,
                centerVertically: centerExpandedPanels,
              );
            }

            return _buildCompactLayout(colorScheme, isLoggedIn);
          },
        ),
      ),
    );
  }

  Widget _buildCompactLayout(ColorScheme colorScheme, bool isLoggedIn) {
    return HomeCompactLayout(child: _buildHomeContent(colorScheme, isLoggedIn));
  }

  Widget _buildExpandedLayout(
    BuildContext context,
    ColorScheme colorScheme,
    bool isLoggedIn, {
    required bool centerVertically,
  }) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return HomeExpandedLayout(
      centerVertically: centerVertically,
      primary: _buildExpandedPrimaryPanel(
        context,
        colorScheme,
        isLoggedIn,
        bottomInset,
        centerVertically: centerVertically,
      ),
      secondary: CampusServicesPanel(centerVertically: centerVertically),
    );
  }

  Widget _buildExpandedPrimaryPanel(
    BuildContext context,
    ColorScheme colorScheme,
    bool isLoggedIn,
    double bottomInset, {
    required bool centerVertically,
  }) {
    final palette =
        Theme.of(context).extension<HongikPalette>() ?? HongikPalette.light;

    final panel = DecoratedBox(
      decoration: BoxDecoration(
        color: palette.cardSurface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: palette.cardOutline),
        boxShadow: [
          BoxShadow(
            color: palette.cardShadow,
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(30, 28, 30, 28 + bottomInset),
        child: _buildExpandedPrimaryContent(context, colorScheme, isLoggedIn),
      ),
    );

    if (!centerVertically) {
      return panel;
    }

    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 620),
        child: panel,
      ),
    );
  }

  Widget _buildExpandedPrimaryContent(
    BuildContext context,
    ColorScheme colorScheme,
    bool isLoggedIn,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(colorScheme, compact: false),
        const SizedBox(height: 28),
        _buildSessionContent(isLoggedIn),
        const SizedBox(height: 16),
        _buildStatusMessage(colorScheme),
        const SizedBox(height: 18),
        Consumer(
          builder: (context, ref, child) {
            if (kIsWeb) return const SizedBox.shrink();
            final updateInfo = ref.watch(
              homeControllerProvider.select((state) => state.updateInfo),
            );
            return _buildVersionInfo(updateInfo);
          },
        ),
      ],
    );
  }

  Widget _buildHomeContent(ColorScheme colorScheme, bool isLoggedIn) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(colorScheme, compact: true),
        const SizedBox(height: 28),
        _buildSessionContent(isLoggedIn),
        const SizedBox(height: 18),
        CampusServiceShortcuts(
          animateEntrance: isLoggedIn,
          onSeatTap: () =>
              _showCampusServiceSheet(const SeatStatusBottomSheet()),
          onMenuTap: () =>
              _showCampusServiceSheet(const CafeteriaMenuBottomSheet()),
        ),
        const SizedBox(height: 14),
        _buildStatusMessage(colorScheme),
        const SizedBox(height: 24),
        Consumer(
          builder: (context, ref, child) {
            if (kIsWeb) return const SizedBox.shrink();
            final updateInfo = ref.watch(
              homeControllerProvider.select((state) => state.updateInfo),
            );
            return _buildVersionInfo(updateInfo);
          },
        ),
      ],
    );
  }

  Widget _buildHeader(ColorScheme colorScheme, {required bool compact}) {
    final isDark = colorScheme.brightness == Brightness.dark;

    return Column(
      children: [
        Semantics(
          label: '홍익인간 앱 로고',
          hint: '길게 누르면 문제 해결용 로그를 공유합니다',
          image: true,
          child: GestureDetector(
            onLongPress: () async {
              await shareLogFile();
            },
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withValues(
                      alpha: isDark ? 0.2 : 0.5,
                    ),
                    blurRadius: isDark ? 16 : 24,
                  ),
                ],
              ),
              child: Image.asset(
                'assets/images/icon_foreground.png',
                width: 96,
                height: 96,
                excludeFromSemantics: true,
              ),
            ),
          ),
        ),
        SizedBox(height: compact ? 10 : 12),
        Text(
          '홍익인간',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: compact ? 30 : 33,
            fontWeight: FontWeight.w900,
            color: colorScheme.onSurface,
            letterSpacing: 0,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '신속 전자출결',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: compact ? 14 : 15,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 2),
            IconButton(
              tooltip: '앱 정보 및 문제 해결',
              onPressed: _showAppInfo,
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              icon: Icon(
                Icons.info_outline_rounded,
                size: 19,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusMessage(ColorScheme colorScheme) {
    return Consumer(
      builder: (context, ref, child) {
        final statusMessage = ref.watch(
          homeControllerProvider.select((state) => state.statusMessage),
        );
        final reduceMotion = MediaQuery.disableAnimationsOf(context);

        return AnimatedSize(
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Align(
              alignment: Alignment.center,
              child: Text(
                statusMessage,
                textAlign: TextAlign.center,
                style: TextStyle(color: colorScheme.onSurface, fontSize: 14),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSessionContent(bool isLoggedIn) {
    const duration = Duration(milliseconds: 240);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return AnimatedSize(
      duration: reduceMotion ? Duration.zero : duration,
      reverseDuration: reduceMotion ? Duration.zero : duration,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      clipBehavior: Clip.none,
      child: AppAnimatedSwitcher(
        duration: duration,
        child: KeyedSubtree(
          key: ValueKey(isLoggedIn),
          child: isLoggedIn ? _buildStudentDashboard() : _buildLoginForm(),
        ),
      ),
    );
  }

  Widget _buildStudentDashboard() {
    return Consumer(
      builder: (context, ref, child) {
        final userId = ref.watch(
          homeControllerProvider.select((state) => state.userId),
        );
        return StudentDashboard(
          userId: userId ?? _idController.text,
          onLogout: () {
            unawaited(ref.read(homeControllerProvider.notifier).logout());
          },
        );
      },
    );
  }

  Widget _buildLoginForm() {
    return Consumer(
      builder: (context, ref, child) {
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
          idController: _idController,
          pwController: _pwController,
          isLoading: isLoading,
          rememberMe: rememberMe,
          autoLogin: autoLogin,
          onRememberMeChanged: (val) {
            ref.read(homeControllerProvider.notifier).onRememberMeChanged(val);
          },
          onAutoLoginChanged: (val) {
            ref.read(homeControllerProvider.notifier).onAutoLoginChanged(val);
          },
          onLogin: () async {
            final result = await ref
                .read(homeControllerProvider.notifier)
                .login(_idController.text, _pwController.text);
            if (result != 'Success') {
              if (mounted) {
                _showSnackBar(_loginFailureMessage(result));
              }
            }
          },
        );
      },
    );
  }

  String _loginFailureMessage(String result) {
    if (result == '학번과 비밀번호를 모두 입력해 주세요.') {
      return result;
    }
    if (result.startsWith('Error::') || result == 'Unknown Error') {
      return '로그인 서버에 연결하지 못했어요. 네트워크를 확인하고 다시 시도해 주세요.';
    }
    if (result.contains('출결') || result.contains('시스템')) {
      return '$result 잠시 후 다시 시도해 주세요.';
    }
    return '로그인하지 못했어요. 학번과 비밀번호를 확인해 주세요.';
  }

  Widget _buildVersionInfo(Map<String, String>? updateInfo) {
    final colorScheme = Theme.of(context).colorScheme;
    final palette =
        Theme.of(context).extension<HongikPalette>() ?? HongikPalette.light;
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
                _showSnackBar('최신 버전이에요.');
              },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColor.hkMediumGray.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasUpdate) ...[
                Icon(Icons.update, color: palette.success, size: 18),
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
