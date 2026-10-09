import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hongik_ingan/core/app_info.dart';
import 'package:hongik_ingan/core/logging/logger.dart';
import 'package:hongik_ingan/core/presentation/widgets/debug_build_badge.dart';
import 'package:hongik_ingan/core/theme/color.dart';
import 'package:hongik_ingan/features/app_install/application/app_install_controller.dart';
import 'package:hongik_ingan/features/app_install/domain/app_install_state.dart';
import 'package:hongik_ingan/features/app_install/presentation/app_install_copy.dart';
import 'package:hongik_ingan/features/app_install/presentation/app_install_prompt.dart';
import 'package:hongik_ingan/features/attendance/application/attendance_controller.dart';
import 'package:hongik_ingan/features/attendance/application/attendance_history_provider.dart';
import 'package:hongik_ingan/features/attendance/presentation/attendance_section.dart';
import 'package:hongik_ingan/features/attendance/presentation/attendance_status_message.dart';
import 'package:hongik_ingan/features/attendance/presentation/attendance_records_view.dart';
import 'package:hongik_ingan/features/attendance/presentation/attendance_history_summary.dart';
import 'package:hongik_ingan/features/attendance/presentation/attendance_auto_refresh.dart';
import 'package:hongik_ingan/features/home/application/home_controller.dart';
import 'package:hongik_ingan/features/cafeteria_menu/application/cafeteria_menu_controller.dart';
import 'package:hongik_ingan/features/cafeteria_menu/domain/cafeteria_menu.dart';
import 'package:hongik_ingan/features/cafeteria_menu/presentation/cafeteria_menu_content.dart';
import 'package:hongik_ingan/features/seat/application/seat_controller.dart';
import 'package:hongik_ingan/features/seat/domain/seat.dart';
import 'package:hongik_ingan/features/seat/presentation/seat_auto_refresh.dart';
import 'package:hongik_ingan/features/seat/presentation/seat_status_content.dart';
import 'package:hongik_ingan/features/update/domain/update_info.dart';
import 'package:hongik_ingan/features/update/presentation/update_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

import 'layouts/home_service_workspace.dart';
import 'home_service_summary_provider.dart';
import 'widgets/login_form.dart';
import 'widgets/app_info_dialog.dart';
import 'widgets/home_attendance_action_layout.dart';
import 'widgets/home_content_size_reporter.dart';
import 'widgets/home_attendance_density.dart';
import 'widgets/home_login_transition.dart';
import 'widgets/home_mobile_layout.dart';
import 'widgets/student_dashboard.dart';
import 'widgets/home_campus_summary.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _pwController = TextEditingController();
  final GlobalKey _serviceWorkspaceKey = GlobalKey();
  bool _campusServicesPrefetchStarted = false;
  bool _wasBackgrounded = false;
  String? _loginError;
  double _pageHeaderHeight = 48;
  double _pageFooterHeight = 0;
  double _attendanceHeadingHeight = 48;
  double _mobileAttendanceHeight = 280;
  HomeService _primaryService = HomeService.attendance;
  bool _installPromptDelayElapsed = false;
  bool _installGuideExpanded = false;
  AppInstallTarget? _requestedInstallTarget;
  Timer? _installPromptDelayTimer;
  Timer? _campusServicesPrefetchTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_initializeApp());
      _installPromptDelayTimer = Timer(const Duration(milliseconds: 1200), () {
        if (!mounted) return;
        setState(() => _installPromptDelayElapsed = true);
      });
    });
  }

  Future<void> _initializeApp() async {
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _installPromptDelayTimer?.cancel();
    _campusServicesPrefetchTimer?.cancel();
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

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _showAppInfo() {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Consumer(
          builder: (dialogContext, dialogRef, child) {
            final installState = dialogRef.watch(appInstallControllerProvider);
            return AppInfoDialog(
              version: AppInfo.version,
              installLabel: installState.target.installActionLabel,
              installDescription: installState.showInfoAction
                  ? installState.target.installActionDescription
                  : null,
              onInstall: installState.showInfoAction
                  ? () => _handleInfoInstallAction(
                      dialogContext,
                      installState.target,
                    )
                  : null,
              onOpenSource: () => launchUrl(
                Uri.parse('https://github.com/LeeHeoJae/Hongik_Ingan'),
                mode: LaunchMode.externalApplication,
              ),
              onShareLogs: kIsWeb ? null : shareLogFile,
            );
          },
        );
      },
    );
  }

  void _handleInfoInstallAction(
    BuildContext dialogContext,
    AppInstallTarget target,
  ) {
    if (target == AppInstallTarget.nativePrompt) {
      unawaited(_handleNativeInstallAction(dialogContext: dialogContext));
      return;
    }

    Navigator.of(dialogContext).pop();
    _openInstallGuide(target);
  }

  void _openInstallGuide(AppInstallTarget target) {
    setState(() {
      _requestedInstallTarget = target;
      _installGuideExpanded = true;
    });
  }

  void _closeRequestedInstallGuide() {
    _installPromptDelayTimer?.cancel();
    setState(() {
      _requestedInstallTarget = null;
      _installGuideExpanded = false;
      _installPromptDelayElapsed = false;
    });
  }

  Future<void> _handleNativeInstallAction({BuildContext? dialogContext}) async {
    if (ref.read(appInstallControllerProvider).isPrompting) return;
    final result = await ref
        .read(appInstallControllerProvider.notifier)
        .prompt();
    if (!mounted) return;
    if (dialogContext != null && !dialogContext.mounted) return;
    switch (result) {
      case AppInstallPromptResult.accepted:
        _showSnackBar('설치를 시작했어요.');
      case AppInstallPromptResult.error:
        _showSnackBar('설치 창을 열지 못했어요. 설치 방법을 확인해 주세요.');
        _openNativeInstallFallback(dialogContext);
      case AppInstallPromptResult.unavailable:
        _openNativeInstallFallback(dialogContext);
      case AppInstallPromptResult.dismissed:
        break;
    }
  }

  void _openNativeInstallFallback(BuildContext? dialogContext) {
    final installState = ref.read(appInstallControllerProvider);
    if (!installState.showInfoAction) return;
    if (dialogContext != null) {
      if (!dialogContext.mounted) return;
      Navigator.of(dialogContext).pop();
    }
    final target = installState.target == AppInstallTarget.nativePrompt
        ? AppInstallTarget.browserManual
        : installState.target;
    _openInstallGuide(target);
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
    ref.listen(homeCampusTimeProvider, (previous, next) {
      if (!_wasBackgrounded &&
          previous != null &&
          !MenuDateRange.isSameDate(previous, next)) {
        unawaited(_fetchSummaryMenu());
      }
    });
    final colorScheme = Theme.of(context).colorScheme;
    final keyboardIsVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    final isLoggedIn = ref.watch(
      homeControllerProvider.select((state) => state.isLoggedIn),
    );
    final userId = ref.watch(
      homeControllerProvider.select((state) => state.userId),
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
          ),
        ),
      ),
      _loginError,
      userId == null ? null : ref.watch(attendanceHistoryProvider(userId)),
    );
    final hasAttendanceInformation =
        isLoggedIn &&
        userId != null &&
        (ref.watch(
              attendanceProvider.select(
                (state) => state.currentLecture != null,
              ),
            ) ||
            (ref
                    .watch(attendanceHistoryProvider(userId))
                    .asData
                    ?.value
                    .isNotEmpty ??
                false));

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final horizontalPadding = constraints.maxWidth < 600
                    ? 16.0
                    : 28.0;
                final mobile = constraints.maxWidth < 600;
                final textScale =
                    MediaQuery.textScalerOf(context).scale(14) / 14;
                final contentWidth =
                    (constraints.maxWidth - horizontalPadding * 2)
                        .clamp(0.0, 900.0)
                        .toDouble();
                final mobileLayout = mobile
                    ? HomeMobileLayout.page(
                        availableHeight: constraints.maxHeight,
                        headerHeight: _pageHeaderHeight,
                        footerHeight: _pageFooterHeight,
                        minimumMainHeight:
                            _primaryService == HomeService.attendance
                            ? _mobileAttendanceHeight
                            : 320,
                        attendanceIsPrimary:
                            _primaryService == HomeService.attendance,
                        textScale: textScale,
                        minimumAuxiliaryHeight: [
                          for (final service in HomeService.values)
                            if (service != _primaryService)
                              HomeServiceWorkspace.minimumMobileSummaryHeight(
                                context,
                                service,
                                _buildServiceSummary(service, ref),
                                ((contentWidth - 12) / 2).clamp(
                                  0.0,
                                  double.infinity,
                                ),
                              ),
                        ].reduce((a, b) => a > b ? a : b),
                      )
                    : null;
                final compactChrome =
                    !mobile &&
                    _primaryService == HomeService.attendance &&
                    _pageHeaderHeight +
                            _pageFooterHeight +
                            _mobileAttendanceHeight +
                            56 >
                        constraints.maxHeight;
                final topPadding = mobile ? 0.0 : (compactChrome ? 8.0 : 16.0);
                final bottomPadding =
                    mobileLayout?.bottomPadding ?? (compactChrome ? 8.0 : 24.0);
                final headerGap =
                    mobileLayout?.headerGap ?? (compactChrome ? 8.0 : 16.0);
                final sideHeader =
                    HomeServiceWorkspace.usesWideLayout(contentWidth) &&
                    MediaQuery.textScalerOf(context).scale(14) <= 19;
                final header = HomeContentSizeReporter(
                  onSize: (size) {
                    if (!mounted ||
                        (_pageHeaderHeight - size.height).abs() < 0.5) {
                      return;
                    }
                    setState(() => _pageHeaderHeight = size.height);
                  },
                  child: _buildHeader(colorScheme),
                );
                final workspace = SeatAutoRefresh(
                  onRefresh: () => ref
                      .read(seatControllerProvider.notifier)
                      .fetchStatusForLocation(SeatLocation.tBuilding),
                  child: AttendanceAutoRefresh(
                    child: HomeServiceWorkspace(
                      key: _serviceWorkspaceKey,
                      attentionScope: isLoggedIn ? userId : null,
                      availableHeight: constraints.maxHeight,
                      viewportHeight:
                          mobileLayout?.viewportHeight ??
                          constraints.maxHeight -
                              topPadding -
                              bottomPadding -
                              _pageFooterHeight -
                              (sideHeader ? 0 : _pageHeaderHeight + headerGap),
                      measureContent: true,
                      adaptiveMobileLayout: mobile,
                      mobileLayout: mobileLayout,
                      balanceMobileAttendance:
                          hasAttendanceInformation && !keyboardIsVisible,
                      mobileHeaderGap: headerGap,
                      mobileHeader: mobile ? header : null,
                      mobileHeaderHeight: _pageHeaderHeight,
                      flexibleMobileHeader: mobile && !keyboardIsVisible,
                      attendanceLayoutKey: attendanceLayoutKey,
                      onAttendanceHeightChanged: (height) {
                        if (!mounted ||
                            (_mobileAttendanceHeight - height).abs() < 0.5) {
                          return;
                        }
                        setState(() => _mobileAttendanceHeight = height);
                      },
                      dockAuxiliaryBelow: constraints.maxWidth < 600,
                      detailBuilder: (service, isPrimary) =>
                          _buildServiceDetail(service, isPrimary, isLoggedIn),
                      summaryBuilder: _buildServiceSummary,
                      onPrimaryChanged: _onPrimaryChanged,
                      wideHeader: sideHeader ? header : null,
                      wideHeaderHeight: _pageHeaderHeight,
                    ),
                  ),
                );

                return SingleChildScrollView(
                  key: const ValueKey('home-page-scroll'),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    topPadding,
                    horizontalPadding,
                    bottomPadding,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 900,
                        minHeight:
                            (constraints.maxHeight - topPadding - bottomPadding)
                                .clamp(0.0, double.infinity),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: mobile
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!mobile && !sideHeader) ...[
                            header,
                            SizedBox(height: headerGap),
                          ],
                          workspace,
                          HomeContentSizeReporter(
                            onSize: (size) {
                              if (!mounted ||
                                  _pageFooterHeight == size.height) {
                                return;
                              }
                              setState(() => _pageFooterHeight = size.height);
                            },
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildVersionFooter(),
                                if (kDebugMode && !mobile) ...[
                                  const SizedBox(height: 12),
                                  const Align(
                                    alignment: Alignment.centerRight,
                                    child: DebugBuildBadge(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            Positioned.fill(
              child: _buildInstallOverlay(keyboardIsVisible: keyboardIsVisible),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme) {
    return Row(
      key: const ValueKey('home-page-header'),
      children: [
        Semantics(
          label: '홍익인간 앱 로고',
          hint: '길게 누르면 문제 해결용 로그를 공유합니다',
          image: true,
          child: GestureDetector(
            onLongPress: shareLogFile,
            child: Container(
              width: 44,
              height: 44,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: colorScheme.brightness == Brightness.light
                    ? AppColor.hkMidnightBlue
                    : colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Image.asset(
                'assets/images/icon_foreground.png',
                excludeFromSemantics: true,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '홍익인간',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
              Text(
                '신속 출결',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: '앱 정보 및 문제 해결',
          onPressed: _showAppInfo,
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          icon: const Icon(Icons.info_outline_rounded),
        ),
      ],
    );
  }

  Widget _buildVersionFooter() {
    if (kIsWeb || AppInfo.version.isEmpty) return const SizedBox.shrink();
    return Consumer(
      builder: (context, ref, child) {
        final updateInfo = ref.watch(
          homeControllerProvider.select((state) => state.updateInfo),
        );
        return Padding(
          padding: const EdgeInsets.only(top: 18),
          child: _buildVersionInfo(updateInfo),
        );
      },
    );
  }

  Widget _buildServiceDetail(
    HomeService service,
    bool isPrimary,
    bool isLoggedIn,
  ) {
    return switch (service) {
      HomeService.attendance => Consumer(
        builder: (context, detailRef, child) => _buildAttendanceDetail(
          isLoggedIn,
          detailRef: detailRef,
          density: HomeAttendanceDensityScope.of(context),
          extraSpace: HomeAttendanceDensityScope.extraSpaceOf(context),
        ),
      ),
      HomeService.seat => _buildSeatDetail(isPrimary),
      HomeService.menu => _buildMenuDetail(),
    };
  }

  Widget _buildAttendanceDetail(
    bool isLoggedIn, {
    required WidgetRef detailRef,
    HomeAttendanceDensity density = HomeAttendanceDensity.regular,
    double extraSpace = 0,
  }) {
    final desktop = MediaQuery.sizeOf(context).width >= 960;
    final recovering = detailRef.watch(
      homeControllerProvider.select(
        (state) =>
            state.isLoading &&
            state.loginStatus == LoginStatus.recoveringSession,
      ),
    );
    const loginSubtitle = '로그인하면 수업 정보를 자동으로 확인해요.';
    const attendanceSubtitle = '수업을 확인하고 출결 번호를 입력해요.';
    final userId = detailRef.watch(
      homeControllerProvider.select((state) => state.userId),
    );
    final showHistorySummary = detailRef.watch(
      attendanceProvider.select(
        (state) => state.currentLecture == null || state.error != null,
      ),
    );
    final historyWidth =
        MediaQuery.textScalerOf(context).scale(14) > 19 ||
            MediaQuery.sizeOf(context).width < 360
        ? 44.0
        : 116.0;
    final historyAtSummary = showHistorySummary && userId != null;
    final content = isLoggedIn
        ? AttendanceSection(
            informationExtraSpace: historyAtSummary ? 0 : extraSpace,
            layoutBuilder: (content, action) => HomeAttendanceActionLayout(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSessionContent(true),
                  const SizedBox(height: 4),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  content,
                  if (showHistorySummary && userId != null) ...[
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    AttendanceHistorySummary(
                      userId: userId,
                      onRecordPressed: () => showAttendanceRecords(
                        context,
                        userId,
                        initialTab: AttendanceRecordsTab.requests,
                      ),
                      extraSpace: extraSpace,
                    ),
                  ],
                ],
              ),
              action: action,
            ),
          )
        : recovering
        ? HomeAttendanceActionLayout(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildStudentDashboard(),
                const SizedBox(height: 4),
                const Divider(height: 1),
                const SizedBox(height: 16),
                _buildStatusMessage(),
              ],
            ),
            action: const ElevatedButton(
              onPressed: null,
              child: Text('다시 로그인 중'),
            ),
          )
        : _buildSessionContent(false);
    final panelContent = Column(
      key: const ValueKey('home-attendance-main-content'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            density.verticalPadding,
            16,
            density.headingGap / 2,
          ),
          child: HomeContentSizeReporter(
            onSize: (size) {
              if (!mounted ||
                  (_attendanceHeadingHeight - size.height).abs() < 0.5) {
                return;
              }
              setState(() => _attendanceHeadingHeight = size.height);
            },
            child: _buildPanelHeading(
              service: HomeService.attendance,
              title: desktop || isLoggedIn || recovering ? '전자출결' : '통합 로그인',
              trailing: isLoggedIn ? const AttendanceRecordsButton() : null,
              trailingWidth: historyWidth,
              subtitle: isLoggedIn || recovering
                  ? attendanceSubtitle
                  : loginSubtitle,
              alternateSubtitle: isLoggedIn
                  ? loginSubtitle
                  : attendanceSubtitle,
            ),
          ),
        ),
        SizedBox(height: density.headingGap / 2),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, density.verticalPadding),
          child: Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              key: const ValueKey('home-attendance-body'),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width >= 960
                    ? double.infinity
                    : 520,
              ),
              child: content,
            ),
          ),
        ),
      ],
    );
    return HomeAttendanceActionScope(
      bodyTop:
          density.verticalPadding +
          _attendanceHeadingHeight +
          density.headingGap,
      bottomPadding: density.verticalPadding,
      child: HomeLoginTransition(isLoggedIn: isLoggedIn, child: panelContent),
    );
  }

  Widget _buildSeatDetail(bool isPrimary) {
    return Consumer(
      builder: (context, ref, child) {
        final state = ref.watch(seatControllerProvider);
        final controller = ref.read(seatControllerProvider.notifier);
        final updatedAt = state.status?.updatedAt;
        final seatSubtitle = state.isSelectedLocationLoading
            ? '${state.selectedLocation.label} 좌석을 확인하고 있어요.'
            : updatedAt == null
            ? '건물을 선택해 좌석 현황을 확인해요.'
            : '${state.selectedLocation.label} · ${updatedAt.hour.toString().padLeft(2, '0')}:${updatedAt.minute.toString().padLeft(2, '0')} 기준';
        return SelectionArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildPanelHeading(
                  service: HomeService.seat,
                  title: '열람실 좌석 현황',
                  subtitle: seatSubtitle,
                  onRefresh: state.isSelectedLocationLoading
                      ? null
                      : () => unawaited(controller.refresh()),
                  isRefreshing: state.isSelectedLocationLoading,
                ),
                const SizedBox(height: 12),
                SeatAutoRefresh(
                  enabled: isPrimary,
                  onRefresh: controller.fetchSelectedStatus,
                  child: const SeatStatusContent(
                    compact: true,
                    useGrid: true,
                    naturalHeight: true,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenuDetail() {
    return Consumer(
      builder: (context, ref, child) {
        final state = ref.watch(cafeteriaMenuControllerProvider);
        final controller = ref.read(cafeteriaMenuControllerProvider.notifier);
        final menuSubtitle = state.isLoading
            ? '선택한 날짜의 메뉴를 확인하고 있어요.'
            : '${MenuDateRange.monthDayLabel(state.selectedDate)} (${MenuDateRange.weekdayLabel(state.selectedDate)}요일)';
        return SelectionArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildPanelHeading(
                  service: HomeService.menu,
                  title: '주간 식당 메뉴',
                  subtitle: menuSubtitle,
                  onRefresh: state.isLoading
                      ? null
                      : () => unawaited(controller.refresh()),
                  isRefreshing: state.isLoading,
                ),
                const SizedBox(height: 12),
                const CafeteriaMenuContent(
                  compact: true,
                  useAdaptiveGrid: true,
                  naturalHeight: true,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPanelHeading({
    required HomeService service,
    required String title,
    required String subtitle,
    String? alternateSubtitle,
    Widget? trailing,
    double trailingWidth = 44,
    VoidCallback? onRefresh,
    bool isRefreshing = false,
  }) {
    final palette =
        Theme.of(context).extension<HongikPalette>() ?? HongikPalette.light;
    final subtitleStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: palette.textSecondary);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: service.iconBackgroundColor(Theme.of(context)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            service.icon,
            color: Theme.of(context).brightness == Brightness.light
                ? palette.brandBlue
                : service.iconColor(Theme.of(context)),
            size: 21,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).brightness == Brightness.light
                            ? Theme.of(context).colorScheme.onSurface
                            : null,
                      ),
                    ),
                  ),
                  if (trailing != null)
                    SizedBox(
                      width: trailingWidth,
                      child: Align(
                        alignment: Alignment.topRight,
                        child: trailing,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              Stack(
                children: [
                  // Reserve wrapped subtitle height across authentication states.
                  if (alternateSubtitle != null)
                    Visibility(
                      visible: false,
                      maintainSize: true,
                      maintainAnimation: true,
                      maintainState: true,
                      child: Text(alternateSubtitle, style: subtitleStyle),
                    ),
                  Text(subtitle, style: subtitleStyle),
                ],
              ),
            ],
          ),
        ),
        if (onRefresh != null || isRefreshing)
          Semantics(
            container: true,
            label: isRefreshing ? '새로고침 중' : '새로고침',
            child: IconButton(
              onPressed: onRefresh,
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              icon: isRefreshing
                  ? const SizedBox(
                      width: 19,
                      height: 19,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded),
            ),
          ),
      ],
    );
  }

  HomeServiceSummaryData _buildServiceSummary(
    HomeService service,
    WidgetRef summaryRef,
  ) => summaryRef.watch(homeServiceSummaryProvider(service));
  void _onPrimaryChanged(HomeService service) {
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

  Widget _buildStatusMessage() {
    return Consumer(
      builder: (context, ref, child) {
        final home = ref.watch(homeControllerProvider);
        final loginError = !home.isLoading && !home.isLoggedIn
            ? _loginError
            : null;
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
      },
    );
  }

  Widget _buildInstallOverlay({required bool keyboardIsVisible}) {
    return Consumer(
      builder: (context, ref, child) {
        final installState = ref.watch(appInstallControllerProvider);
        final requestedTarget = _requestedInstallTarget;
        final isRequested = requestedTarget != null;
        final showProactivePrompt =
            _installPromptDelayElapsed && installState.showProactivePromo;

        if (!installState.showInfoAction ||
            (!isRequested && !showProactivePrompt) ||
            (keyboardIsVisible && !isRequested)) {
          return const SizedBox.shrink();
        }

        final target = requestedTarget ?? installState.target;
        return LayoutBuilder(
          builder: (context, constraints) {
            final useCornerPlacement = constraints.maxWidth >= 700;

            return Align(
              alignment: useCornerPlacement
                  ? Alignment.bottomRight
                  : Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: useCornerPlacement ? 380 : 520,
                    maxHeight: (constraints.maxHeight - 32).clamp(
                      0.0,
                      double.infinity,
                    ),
                  ),
                  child: AppInstallPrompt(
                    target: target,
                    showGuide: _installGuideExpanded,
                    onInstall: () {
                      unawaited(_handleNativeInstallAction());
                    },
                    onShowGuide: () {
                      setState(() => _installGuideExpanded = true);
                    },
                    onDismiss: () {
                      if (isRequested) {
                        _closeRequestedInstallGuide();
                        return;
                      }
                      setState(() => _installGuideExpanded = false);
                      unawaited(
                        ref
                            .read(appInstallControllerProvider.notifier)
                            .dismissPromo(),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSessionContent(bool isLoggedIn) {
    return KeyedSubtree(
      key: ValueKey(isLoggedIn),
      child: isLoggedIn ? _buildStudentDashboard() : _buildLoginForm(),
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
          layoutBuilder: (content, action) => HomeAttendanceActionLayout(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildStatusMessage(),
                const SizedBox(height: 12),
                content,
              ],
            ),
            action: action,
          ),
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
            setState(() => _loginError = null);
            final result = await ref
                .read(homeControllerProvider.notifier)
                .login(_idController.text, _pwController.text);
            if (result.isFailure) {
              if (mounted) {
                final message = result.displayMessage;
                setState(() => _loginError = message);
              }
            }
          },
        );
      },
    );
  }

  Widget _buildVersionInfo(UpdateInfo? updateInfo) {
    final colorScheme = Theme.of(context).colorScheme;
    final palette =
        Theme.of(context).extension<HongikPalette>() ?? HongikPalette.light;
    if (AppInfo.version.isEmpty) return const SizedBox.shrink();
    final hasUpdate = updateInfo != null;

    return Center(
      child: InkWell(
        key: const ValueKey('home-version-info'),
        onTap: hasUpdate
            ? () {
                showUpdateDialog(context, updateInfo);
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
              // 좌우의 시각적 수직 중심을 맞추기 위해 1px 위로 보정
              Transform.translate(
                offset: const Offset(0, -1),
                child: Text(
                  'v${AppInfo.version}',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 12,
                    height: 1,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: colorScheme.onSurface, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
