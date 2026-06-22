import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hongik_ingan/controllers/food_menu_controller.dart';
import 'package:hongik_ingan/controllers/home_controller.dart';
import 'package:hongik_ingan/controllers/study_room_controller.dart';

import '../core/app_info.dart';
import '../core/logger.dart';
import '../core/theme/color.dart';
import '../services/check_update.dart';
import 'widgets/dashboard.dart';
import 'widgets/food_menu_bottom_sheet.dart';
import 'widgets/login_form.dart';
import 'widgets/study_room_status_bottom_sheet.dart';
import 'widgets/wide_campus_panel.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _pwController = TextEditingController();
  bool _campusInfoPrefetchStarted = false;

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
    if (state == AppLifecycleState.resumed) {
      final isLoggedIn = ref.read(homeControllerProvider).isLoggedIn;
      if (isLoggedIn) {
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

  void _showCampusSheet(Widget sheet) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => sheet,
    );
  }

  void _ensureCampusInfoPrefetch() {
    if (_campusInfoPrefetchStarted) return;
    _campusInfoPrefetchStarted = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.read(foodMenuControllerProvider.notifier).fetchMenus());
      unawaited(ref.read(studyRoomControllerProvider.notifier).fetchStatuses());
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
            final useExpandedLayout =
                constraints.maxWidth >= 900 && constraints.maxHeight >= 560;
            final useDesktopTallLayout =
                constraints.maxWidth >= 900 && constraints.maxHeight >= 760;

            if (useExpandedLayout) {
              _ensureCampusInfoPrefetch();
              return _buildExpandedLayout(
                context,
                colorScheme,
                isLoggedIn,
                useDesktopTallLayout: useDesktopTallLayout,
              );
            }

            return _buildCompactLayout(context, colorScheme, isLoggedIn);
          },
        ),
      ),
    );
  }

  Widget _buildCompactLayout(
    BuildContext context,
    ColorScheme colorScheme,
    bool isLoggedIn,
  ) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final content = _buildHomeContent(
      context,
      colorScheme,
      isLoggedIn,
      useScrollFallback: true,
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(28, 24, 28, 24 + bottomInset),
          child: content,
        ),
      ),
    );
  }

  Widget _buildExpandedLayout(
    BuildContext context,
    ColorScheme colorScheme,
    bool isLoggedIn, {
    required bool useDesktopTallLayout,
  }) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 24),
      child: Align(
        alignment: useDesktopTallLayout
            ? Alignment.center
            : Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 6,
                child: WideCampusPanel(
                  useDesktopTallLayout: useDesktopTallLayout,
                  onFoodMenuTap: () =>
                      _showCampusSheet(const FoodMenuBottomSheet()),
                  onStudyRoomTap: () =>
                      _showCampusSheet(const StudyRoomStatusBottomSheet()),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 5,
                child: _buildExpandedPrimaryPanel(
                  context,
                  colorScheme,
                  isLoggedIn,
                  bottomInset,
                  useDesktopTallLayout: useDesktopTallLayout,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedPrimaryPanel(
    BuildContext context,
    ColorScheme colorScheme,
    bool isLoggedIn,
    double bottomInset, {
    required bool useDesktopTallLayout,
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

    if (!useDesktopTallLayout) {
      return panel;
    }

    return Align(
      alignment: useDesktopTallLayout ? Alignment.center : Alignment.topCenter,
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
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: isLoggedIn
              ? _buildDashboard(showCampusActions: false)
              : _buildLoginForm(),
        ),
        const SizedBox(height: 16),
        _buildAnimatedStatusMessage(colorScheme),
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

  Widget _buildHomeContent(
    BuildContext context,
    ColorScheme colorScheme,
    bool isLoggedIn, {
    required bool useScrollFallback,
  }) {
    final children = [
      _buildHeader(colorScheme, compact: useScrollFallback),
      SizedBox(height: useScrollFallback ? 28 : 34),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: isLoggedIn ? _buildDashboard() : _buildLoginForm(),
      ),
      if (!isLoggedIn) ...[
        SizedBox(height: useScrollFallback ? 18 : 20),
        CampusQuickActions(
          onStudyRoomTap: () =>
              _showCampusSheet(const StudyRoomStatusBottomSheet()),
          onFoodMenuTap: () => _showCampusSheet(const FoodMenuBottomSheet()),
        ),
      ],
      const SizedBox(height: 14),
      _buildAnimatedStatusMessage(colorScheme),
      SizedBox(height: useScrollFallback ? 24 : 20),
      Consumer(
        builder: (context, ref, child) {
          if (kIsWeb) return const SizedBox.shrink();
          final updateInfo = ref.watch(
            homeControllerProvider.select((state) => state.updateInfo),
          );
          return _buildVersionInfo(updateInfo);
        },
      ),
    ];

    if (useScrollFallback) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [const Spacer(flex: 2), ...children, const Spacer(flex: 3)],
    );
  }

  Widget _buildHeader(ColorScheme colorScheme, {required bool compact}) {
    return Column(
      children: [
        GestureDetector(
          onLongPress: () async {
            await shareLogFile();
          },
          child: Container(
            decoration: BoxDecoration(
              color: colorScheme.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.5),
                  blurRadius: 24,
                ),
              ],
            ),
            child: Image.asset(
              'assets/images/icon_foreground.png',
              width: 96,
              height: 96,
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
        Text(
          '신속 전자출결',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: compact ? 14 : 15,
            color: colorScheme.onSurface.withValues(alpha: 0.6),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildAnimatedStatusMessage(ColorScheme colorScheme) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: const Interval(0.62, 1.0, curve: Curves.easeOutCubic),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 14 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Consumer(
        builder: (context, ref, child) {
          final statusMessage = ref.watch(
            homeControllerProvider.select((state) => state.statusMessage),
          );
          return Text(
            statusMessage,
            textAlign: TextAlign.center,
            style: TextStyle(color: colorScheme.onSurface, fontSize: 12),
          );
        },
      ),
    );
  }

  Widget _buildDashboard({bool showCampusActions = true}) {
    return Consumer(
      builder: (context, ref, child) {
        final userId = ref.watch(
          homeControllerProvider.select((state) => state.userId),
        );
        return Dashboard(
          userId: userId ?? _idController.text,
          showCampusActions: showCampusActions,
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
                _showSnackBar('로그인 실패: 아이디 또는 비번을 확인하세요.');
              }
            }
          },
        );
      },
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
            color: AppColor.hkMediumGray.withValues(alpha: 0.1),
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
