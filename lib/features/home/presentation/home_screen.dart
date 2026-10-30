import 'dart:async';
import 'package:hongik_ingan/core/haptics/app_haptics.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hongik_ingan/core/app_info.dart';
import 'package:hongik_ingan/core/logging/logger.dart';
import 'package:hongik_ingan/core/theme/color.dart';
import 'package:hongik_ingan/features/attendance/application/attendance_controller.dart';
import 'package:hongik_ingan/features/attendance/application/attendance_history_provider.dart';
import 'package:hongik_ingan/features/home/application/home_controller.dart';
import 'package:hongik_ingan/features/cafeteria_menu/application/cafeteria_menu_controller.dart';
import 'package:hongik_ingan/features/cafeteria_menu/domain/cafeteria_menu.dart';
import 'package:hongik_ingan/features/seat/application/seat_controller.dart';
import 'package:hongik_ingan/features/update/domain/update_check_result.dart';
import 'package:hongik_ingan/features/update/presentation/update_dialog.dart';
import 'package:hongik_ingan/features/update/presentation/version_info_button.dart';

import 'layouts/home_service_workspace.dart';
import 'layouts/home_page_layout.dart';
import 'home_attendance_presentation.dart';
import 'widgets/home_attendance_panel.dart';
import 'widgets/home_login_panel.dart';
import 'home_splash_messages.dart';
import 'widgets/home_splash_brand.dart';
import 'widgets/home_splash_space.dart';
import 'widgets/student_dashboard.dart';
import 'widgets/home_campus_summary.dart';
import 'widgets/home_seat_panel.dart';
import 'widgets/home_menu_panel.dart';
import 'widgets/home_install_host.dart';

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
  bool _versionDialogOpen = false;
  bool _initializingSession = true;
  int _splashMessageRevision = 0;
  String? _loginError;
  HomeService _primaryService = HomeService.attendance;
  final _attendanceHold = HomeAttendancePresentationHold();
  Timer? _campusServicesPrefetchTimer;

  @override
  void initState() {
    super.initState();
    AppHaptics.instance.setActive(true);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_initializeApp());
    });
  }

  Future<void> _initializeApp() async {
    try {
      await _restoreInitialSession();
    } finally {
      if (mounted) setState(() => _initializingSession = false);
    }
  }

  Future<void> _restoreInitialSession() async {
    final idValue = _idController.value;
    final pwValue = _pwController.value;
    final controller = ref.read(homeControllerProvider.notifier);
    final saved = await controller.initializeApp();
    if (!mounted) return;
    if (saved.$1 != null && _idController.value == idValue) {
      _idController.text = saved.$1!;
    }
    if (saved.$2 != null && _pwController.value == pwValue) {
      _pwController.text = saved.$2!;
    }
    await controller.restoreInitialSession(
      _idController.text,
      _pwController.text,
    );
  }

  HomeAttendancePresentation _readAttendancePresentation() {
    final home = ref.read(homeControllerProvider);
    return HomeAttendancePresentation(
      isLoggedIn: home.isLoggedIn,
      recovering:
          _initializingSession ||
          (home.isLoading && home.loginStatus != LoginStatus.loggingIn),
      userId: home.userId,
      recoveryPhase: home.recoveryPhase,
      sessionLoading: home.isLoading,
      attendance: ref.read(attendanceProvider),
      history: home.userId == null
          ? null
          : ref.read(attendanceHistoryProvider(home.userId!)),
    );
  }

  void _onAttendanceInteractionChanged(bool active) {
    if (!mounted || _attendanceHold.active == active) return;
    setState(
      () => _attendanceHold.updateInteraction(
        active,
        _readAttendancePresentation(),
      ),
    );
  }

  @override
  void dispose() {
    AppHaptics.instance.setActive(false);
    WidgetsBinding.instance.removeObserver(this);
    _campusServicesPrefetchTimer?.cancel();
    _idController.dispose();
    _pwController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    AppHaptics.instance.setActive(state == AppLifecycleState.resumed);

    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _wasBackgrounded = true;
      return;
    }

    if (state != AppLifecycleState.resumed || !_wasBackgrounded) {
      return;
    }

    _wasBackgrounded = false;
    ref.invalidate(homeCampusTimeProvider);
    unawaited(_fetchSummaryMenu());
    final isLoggedIn = ref.read(homeControllerProvider).isLoggedIn;
    if (isLoggedIn) {
      unawaited(
        ref
            .read(homeControllerProvider.notifier)
            .revalidateSessionOnResume(_idController.text, _pwController.text),
      );
    }
  }

  void _ensureCampusServicesPrefetch() {
    if (_campusServicesPrefetchStarted) return;
    _campusServicesPrefetchStarted = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _campusServicesPrefetchTimer = Timer(
        const Duration(milliseconds: 700),
        () {
          if (!mounted) return;
          unawaited(_fetchSummaryMenu());
        },
      );
    });
  }

  Future<void> _fetchSummaryMenu() {
    final now = ref.read(homeCampusTimeProvider);
    return ref
        .read(cafeteriaMenuControllerProvider.notifier)
        .fetchMenuForDate(
          MenuDateRange.initialSelectedDateFor(now),
          baseDate: now,
        );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(homeControllerProvider, (previous, next) {
      if (next.isLoading || next.isLoggedIn) _loginError = null;
    });
    ref.listen(attendanceProvider, (previous, next) {
      final lecture = next.currentLecture;
      if (_initializingSession ||
          lecture == null ||
          !next.hasCheckedLecture ||
          next.phase != AttendancePhase.idle ||
          next.error != null ||
          next.sessionExpired ||
          next.isLectureStale ||
          next.submissionResult != null ||
          !ref.read(homeControllerProvider).isLoggedIn) {
        return;
      }
      final oldLecture = previous?.currentLecture;
      if (oldLecture == null ||
          lecture.name != oldLecture.name ||
          lecture.time != oldLecture.time ||
          !mapEquals(lecture.attendanceParams, oldLecture.attendanceParams)) {
        AppHaptics.instance.complete();
      }
    });
    ref.listen(homeCampusTimeProvider, (previous, next) {
      if (!_wasBackgrounded &&
          previous != null &&
          !MenuDateRange.isSameDate(previous, next)) {
        unawaited(_fetchSummaryMenu());
      }
    });
    final home = ref.watch(homeControllerProvider);
    final userId = home.userId;
    final holdBackdrop = _attendanceHold.resolveKeyboard(
      MediaQuery.viewInsetsOf(context).bottom,
    );
    _ensureCampusServicesPrefetch();
    final attendanceLayoutKey = (
      ref.watch(
        homeControllerProvider.select(
          (state) => (
            state.isLoading,
            state.isLoggedIn,
            state.loginStatus,
            state.statusMessage,
            state.rememberMe,
            state.autoLogin,
            state.userId,
            state.recoveryPhase,
          ),
        ),
      ),
      ref.watch(
        attendanceProvider.select(
          (state) => (
            state.currentLecture,
            state.phase,
            state.hasCheckedLecture,
            state.error,
            state.sessionExpired,
            state.submissionResult,
          ),
        ),
      ),
      _loginError,
      userId == null ? null : ref.watch(attendanceHistoryProvider(userId)),
    );

    final presentation = _attendanceHold.resolve(
      HomeAttendancePresentation(
        isLoggedIn: home.isLoggedIn,
        recovering:
            _initializingSession ||
            (home.isLoading && home.loginStatus != LoginStatus.loggingIn),
        userId: userId,
        recoveryPhase: home.recoveryPhase,
        sessionLoading: home.isLoading,
        attendance: ref.watch(attendanceProvider),
        history: userId == null
            ? null
            : ref.watch(attendanceHistoryProvider(userId)),
      ),
    );
    return HomeInstallHost(
      builder: (context, showAppInfo, installOverlay) => HomePageLayout(
        presentation: presentation,
        holdBackdrop: holdBackdrop,
        attendanceLayoutKey: attendanceLayoutKey,
        primaryService: _primaryService,
        onPrimaryChanged: _onPrimaryChanged,
        header: _buildHeader(Theme.of(context).colorScheme, showAppInfo),
        footer: _buildVersionFooter(),
        installOverlay: installOverlay,
        detailBuilder:
            (
              context,
              service,
              isPrimary,
              animateLayout,
              onContentSizeChanged,
            ) => _buildServiceDetail(
              service,
              isPrimary,
              presentation,
              animateLayout,
              onContentSizeChanged,
            ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme, VoidCallback showAppInfo) {
    return Stack(
      key: const ValueKey('home-page-header'),
      clipBehavior: Clip.none,
      children: [
        Positioned(top: 0, right: 0, child: _buildInfoButton(showAppInfo)),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HomeSplashObstacle(
              child: Semantics(
                label: '홍익인간 앱 로고',
                hint: '누르면 스플래시 문구를 바꾸고, 길게 누르면 문제 해결용 로그를 공유합니다',
                image: true,
                button: true,
                child: Material(
                  color: colorScheme.brightness == Brightness.light
                      ? AppColor.hkMidnightBlue
                      : colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () => setState(() => _splashMessageRevision++),
                    onLongPress: shareLogFile,
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Padding(
                        padding: const EdgeInsets.all(3),
                        child: Image.asset(
                          'assets/images/icon_foreground.png',
                          excludeFromSemantics: true,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: HomeSplashBrand(
                messages: ref.watch(homeSplashMessagesProvider),
                messageRevision: _splashMessageRevision,
                hidden: MediaQuery.viewInsetsOf(context).bottom > 0,
              ),
            ),
            const SizedBox(width: 48, height: 48),
          ],
        ),
      ],
    );
  }

  // Paint below the splash; its IgnorePointer keeps this target clickable.
  Widget _buildInfoButton(VoidCallback showAppInfo) => SizedBox(
    width: 48,
    height: 48,
    child: IconButton(
      tooltip: '앱 정보 및 문제 해결',
      onPressed: showAppInfo,
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      icon: const Icon(Icons.info_outline_rounded),
    ),
  );

  Widget _buildVersionFooter() {
    if (kIsWeb || AppInfo.version.isEmpty) return const SizedBox.shrink();
    return Consumer(
      builder: (context, ref, child) {
        final updateCheck = ref.watch(
          homeControllerProvider.select((state) => state.updateCheck),
        );
        return Padding(
          padding: const EdgeInsets.only(top: 18),
          child: Center(
            child: VersionInfoButton(
              key: const ValueKey('home-version-info'),
              version: AppInfo.version,
              hasUpdate: updateCheck.status == UpdateCheckStatus.available,
              onPressed: _showVersionInfo,
            ),
          ),
        );
      },
    );
  }

  Widget _buildServiceDetail(
    HomeService service,
    bool isPrimary,
    HomeAttendancePresentation presentation,
    bool animateLayout,
    VoidCallback onContentSizeChanged,
  ) => switch (service) {
    HomeService.attendance => HomeAttendancePanel(
      presentation: presentation,
      initializingSession: _initializingSession,
      animateLayout: animateLayout,
      onInteractionChanged: _onAttendanceInteractionChanged,
      onContentSizeChanged: onContentSizeChanged,
      sessionContentBuilder: _buildSessionContent,
      loginStatus: HomeLoginStatus(
        error: _loginError,
        initializing: _initializingSession,
      ),
    ),
    HomeService.seat => HomeSeatPanel(isPrimary: isPrimary),
    HomeService.menu => const HomeMenuPanel(),
  };

  void _onPrimaryChanged(HomeService service) {
    if (service == _primaryService) return;
    AppHaptics.instance.cancel();
    setState(() => _primaryService = service);
    switch (service) {
      case HomeService.attendance:
        break;
      case HomeService.seat:
        unawaited(
          ref.read(seatControllerProvider.notifier).fetchSelectedStatus(),
        );
        break;
      case HomeService.menu:
        unawaited(
          ref.read(cafeteriaMenuControllerProvider.notifier).fetchMenus(),
        );
        break;
    }
  }

  Widget _buildSessionContent(bool isLoggedIn) {
    return KeyedSubtree(
      key: ValueKey(isLoggedIn),
      child: isLoggedIn
          ? _buildStudentDashboard()
          : HomeLoginPanel(
              idController: _idController,
              pwController: _pwController,
              error: _loginError,
              onLogin: _login,
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

  Future<void> _login() async {
    if (ref.read(homeControllerProvider).isLoading) return;
    setState(() => _loginError = null);
    final result = await ref
        .read(homeControllerProvider.notifier)
        .login(_idController.text, _pwController.text);
    if (!mounted) return;
    if (result.isFailure) {
      AppHaptics.instance.error();
    } else if (result.isSuccess) {
      AppHaptics.instance.complete();
    }
    if (result.isFailure && mounted) {
      setState(() => _loginError = result.displayMessage);
    }
  }

  Future<void> _showVersionInfo() async {
    if (_versionDialogOpen) return;
    _versionDialogOpen = true;
    final container = ProviderScope.containerOf(context, listen: false);
    try {
      final closed = showDialog<void>(
        context: context,
        animationStyle: MediaQuery.disableAnimationsOf(context)
            ? AnimationStyle.noAnimation
            : null,
        builder: (context) => UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, child) => UpdateDialog(
              currentVersion: AppInfo.version,
              result: ref.watch(
                homeControllerProvider.select((state) => state.updateCheck),
              ),
              onRetry: () => ref
                  .read(homeControllerProvider.notifier)
                  .fetchUpdateInfo(userInitiated: true),
            ),
          ),
        ),
      );
      if (ref.read(homeControllerProvider).updateCheck.status ==
          UpdateCheckStatus.idle) {
        unawaited(
          ref
              .read(homeControllerProvider.notifier)
              .fetchUpdateInfo(userInitiated: true),
        );
      }
      await closed;
    } finally {
      _versionDialogOpen = false;
    }
  }
}
