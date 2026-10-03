import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hongik_ingan/core/app_info.dart';
import 'package:hongik_ingan/core/logging/logger.dart';
import 'package:hongik_ingan/core/presentation/widgets/debug_build_badge.dart';
import 'package:hongik_ingan/core/presentation/widgets/app_animated_switcher.dart';
import 'package:hongik_ingan/core/theme/color.dart';
import 'package:hongik_ingan/features/app_install/application/app_install_controller.dart';
import 'package:hongik_ingan/features/app_install/domain/app_install_state.dart';
import 'package:hongik_ingan/features/app_install/presentation/app_install_prompt.dart';
import 'package:hongik_ingan/features/attendance/application/attendance_controller.dart';
import 'package:hongik_ingan/features/attendance/presentation/attendance_section.dart';
import 'package:hongik_ingan/features/home/application/home_controller.dart';
import 'package:hongik_ingan/features/cafeteria_menu/application/cafeteria_menu_controller.dart';
import 'package:hongik_ingan/features/cafeteria_menu/domain/cafeteria_menu.dart';
import 'package:hongik_ingan/features/cafeteria_menu/presentation/cafeteria_menu_content.dart';
import 'package:hongik_ingan/features/seat/application/seat_controller.dart';
import 'package:hongik_ingan/features/seat/domain/seat.dart';
import 'package:hongik_ingan/features/seat/presentation/seat_auto_refresh.dart';
import 'package:hongik_ingan/features/seat/presentation/seat_status_content.dart';
import 'package:hongik_ingan/features/update/check_update.dart';
import 'package:url_launcher/url_launcher.dart';

import 'layouts/home_service_workspace.dart';
import 'widgets/login_form.dart';
import 'widgets/home_attendance_action_layout.dart';
import 'widgets/home_attendance_progress.dart';
import 'widgets/student_dashboard.dart';
import 'widgets/home_campus_summary.dart';

enum _InstallGuideOrigin { appInfo, installPrompt }

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
  bool _installPromptDelayElapsed = false;
  bool _installGuideExpanded = false;
  AppInstallTarget? _requestedInstallTarget;
  _InstallGuideOrigin? _installGuideOrigin;
  Timer? _installPromptDelayTimer;
  Timer? _campusServicesPrefetchTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(homeControllerProvider.notifier)
          .initializeApp(_idController, _pwController);
      _installPromptDelayTimer = Timer(const Duration(milliseconds: 1200), () {
        if (!mounted) return;
        setState(() => _installPromptDelayElapsed = true);
      });
    });
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
            final colorScheme = Theme.of(dialogContext).colorScheme;
            final installState = dialogRef.watch(appInstallControllerProvider);

            return AlertDialog(
              insetPadding: EdgeInsets.symmetric(
                horizontal: MediaQuery.sizeOf(dialogContext).width < 360
                    ? 16
                    : 40,
                vertical: 24,
              ),
              contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColor.hkMidnightBlue,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Image.asset('assets/images/icon_foreground.png'),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '앱 안내',
                            style: Theme.of(dialogContext).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '홍익인간은 홍익대학교 공식 앱이 아닌, 개인이 개발한 오픈소스 프로젝트예요.',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (AppInfo.version.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _AppInfoRow(
                        icon: Icons.info_outline_rounded,
                        label: '버전 정보',
                        value: 'v${AppInfo.version}',
                      ),
                    ],
                    if (installState.showInfoAction) ...[
                      const SizedBox(height: 12),
                      _AppInfoAction(
                        icon: Icons.install_mobile_rounded,
                        label: '앱 설치',
                        value: _installActionDescription(installState.target),
                        onTap: () => _handleInfoInstallAction(
                          dialogContext,
                          installState.target,
                        ),
                      ),
                    ],
                    if (!kIsWeb) ...[
                      const SizedBox(height: 12),
                      const _AppInfoRow(
                        icon: Icons.privacy_tip_outlined,
                        label: '문제 해결',
                        value: '개인정보를 가린 진단 로그를 공유할 수 있어요.',
                      ),
                    ],
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              actions: [
                TextButton.icon(
                  onPressed: () => launchUrl(
                    Uri.parse('https://github.com/LeeHeoJae/Hongik_Ingan'),
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.code_rounded, size: 18),
                  label: const Text('소스 코드'),
                ),
                if (!kIsWeb)
                  TextButton.icon(
                    onPressed: shareLogFile,
                    icon: const Icon(Icons.upload_file_outlined, size: 18),
                    label: const Text('진단 로그'),
                  ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('닫기'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _installActionDescription(AppInstallTarget target) {
    return switch (target) {
      AppInstallTarget.nativePrompt => '이 브라우저에서 바로 설치할 수 있어요.',
      AppInstallTarget.iosManual => '현재 브라우저에서 홈 화면에 추가하는 방법을 안내해 드려요.',
      AppInstallTarget.macSafariManual => 'Safari에서 Dock에 추가하는 방법을 안내해 드려요.',
      AppInstallTarget.unsupportedBrowser => '설치를 지원하는 브라우저를 안내해 드려요.',
      _ => '브라우저 메뉴에서 설치하는 방법을 안내해 드려요.',
    };
  }

  void _handleInfoInstallAction(
    BuildContext dialogContext,
    AppInstallTarget target,
  ) {
    if (target == AppInstallTarget.nativePrompt) {
      unawaited(_handleNativeInstallAction());
      return;
    }

    Navigator.of(dialogContext).pop();
    _openInstallGuide(target, origin: _InstallGuideOrigin.appInfo);
  }

  void _openInstallGuide(
    AppInstallTarget target, {
    _InstallGuideOrigin origin = _InstallGuideOrigin.installPrompt,
  }) {
    setState(() {
      _requestedInstallTarget = target;
      _installGuideExpanded = true;
      _installGuideOrigin = origin;
    });
  }

  void _closeRequestedInstallGuide({bool reopenAppInfo = false}) {
    setState(() {
      _requestedInstallTarget = null;
      _installGuideExpanded = false;
      _installGuideOrigin = null;
      _installPromptDelayElapsed = false;
    });

    if (!reopenAppInfo) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_showAppInfo());
    });
  }

  Future<void> _handleNativeInstallAction() async {
    final result = await ref
        .read(appInstallControllerProvider.notifier)
        .prompt();
    if (!mounted) return;
    switch (result) {
      case AppInstallPromptResult.accepted:
        _showSnackBar('설치를 시작했어요.');
      case AppInstallPromptResult.error:
        _showSnackBar('설치 창을 열지 못했어요. 브라우저 메뉴에서 다시 시도해 주세요.');
        _openInstallGuide(AppInstallTarget.browserManual);
      case AppInstallPromptResult.unavailable:
        _openInstallGuide(AppInstallTarget.browserManual);
      case AppInstallPromptResult.dismissed:
        break;
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
    ref.listen(homeCampusTimeProvider, (previous, next) {
      if (!_wasBackgrounded &&
          previous != null &&
          !MenuDateRange.isSameDate(previous, next)) {
        unawaited(_fetchSummaryMenu());
      }
    });
    final colorScheme = Theme.of(context).colorScheme;
    final isLoggedIn = ref.watch(
      homeControllerProvider.select((state) => state.isLoggedIn),
    );
    _ensureCampusServicesPrefetch();

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
                final dockMobileAuxiliary =
                    constraints.maxWidth < 600 &&
                    constraints.maxHeight >=
                        440 +
                            (MediaQuery.textScalerOf(context).scale(14) / 14 -
                                        1)
                                    .clamp(0.0, 1.0) *
                                260;
                final contentWidth =
                    (constraints.maxWidth - horizontalPadding * 2)
                        .clamp(0.0, 900.0)
                        .toDouble();
                final sideHeader =
                    HomeServiceWorkspace.usesWideLayout(contentWidth) &&
                    MediaQuery.textScalerOf(context).scale(14) <= 19;
                final workspace = SeatAutoRefresh(
                  onRefresh: () => ref
                      .read(seatControllerProvider.notifier)
                      .fetchStatusForLocation(SeatLocation.tBuilding),
                  child: HomeServiceWorkspace(
                    key: _serviceWorkspaceKey,
                    availableHeight: constraints.maxHeight,
                    measureContent: true,
                    dockAuxiliaryBelow: constraints.maxWidth < 600,
                    detailBuilder: (service, isPrimary) =>
                        _buildServiceDetail(service, isPrimary, isLoggedIn),
                    summaryBuilder: _buildServiceSummary,
                    onPrimaryChanged: _onPrimaryChanged,
                    wideHeader: sideHeader ? _buildHeader(colorScheme) : null,
                  ),
                );

                if (dockMobileAuxiliary) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeader(colorScheme),
                        const SizedBox(height: 16),
                        Expanded(child: workspace),
                        _buildVersionFooter(),
                        const SizedBox(height: 12),
                      ],
                    ),
                  );
                }

                return SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    16,
                    horizontalPadding,
                    24,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 900,
                        minHeight: (constraints.maxHeight - 40).clamp(
                          0.0,
                          double.infinity,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!sideHeader) ...[
                            _buildHeader(colorScheme),
                            const SizedBox(height: 16),
                          ],
                          workspace,
                          _buildVersionFooter(),
                          if (kDebugMode) ...[
                            const SizedBox(height: 12),
                            const Align(
                              alignment: Alignment.centerRight,
                              child: DebugBuildBadge(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            Positioned.fill(child: _buildInstallOverlay()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme) {
    return Row(
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
                color: colorScheme.primary,
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
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
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
      HomeService.attendance => _buildAttendanceDetail(isLoggedIn),
      HomeService.seat => _buildSeatDetail(isPrimary),
      HomeService.menu => _buildMenuDetail(),
    };
  }

  Widget _buildAttendanceDetail(bool isLoggedIn) {
    final desktop = MediaQuery.sizeOf(context).width >= 960;
    const loginSubtitle = '로그인하면 수업 정보를 자동으로 확인해요.';
    const attendanceSubtitle = '수업을 확인하고 출결 번호를 입력해요.';
    final content = isLoggedIn
        ? AttendanceSection(
            layoutBuilder: (content, action) => HomeAttendanceActionLayout(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSessionContent(true),
                  const SizedBox(height: 4),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  _buildStatusMessage(),
                  content,
                ],
              ),
              action: action,
            ),
          )
        : _buildSessionContent(false);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        key: const ValueKey('home-attendance-main-content'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPanelHeading(
            icon: Icons.check_circle_outline_rounded,
            title: desktop || isLoggedIn ? '전자출결' : '통합 로그인',
            subtitle: isLoggedIn ? attendanceSubtitle : loginSubtitle,
            alternateSubtitle: desktop
                ? null
                : isLoggedIn
                ? loginSubtitle
                : attendanceSubtitle,
            subtitleContent: desktop
                ? Consumer(
                    builder: (context, ref, child) {
                      final attendance = ref.watch(attendanceProvider);
                      final hasLecture =
                          attendance.currentLecture != null &&
                          attendance.error == null &&
                          attendance.phase != AttendancePhase.fetchingLecture;
                      return HomeAttendanceProgress(
                        currentStep: !isLoggedIn
                            ? 0
                            : hasLecture
                            ? 2
                            : 1,
                      );
                    },
                  )
                : null,
          ),
          const SizedBox(height: 18),
          Align(
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
        ],
      ),
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
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildPanelHeading(
                icon: Icons.local_library_rounded,
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
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildPanelHeading(
                icon: Icons.restaurant_menu_rounded,
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
        );
      },
    );
  }

  Widget _buildPanelHeading({
    required IconData icon,
    required String title,
    required String subtitle,
    String? alternateSubtitle,
    Widget? subtitleContent,
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
            color: palette.cardSurfaceMuted,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: palette.brandNavy, size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              subtitleContent ??
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
          IconButton(
            tooltip: isRefreshing ? '새로고침 중' : '새로고침',
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
      ],
    );
  }

  HomeServiceSummaryData _buildServiceSummary(
    HomeService service,
    WidgetRef summaryRef,
  ) {
    switch (service) {
      case HomeService.attendance:
        final home = summaryRef.watch(homeControllerProvider);
        final attendance = summaryRef.watch(attendanceProvider);
        if (!home.isLoggedIn) {
          return HomeServiceSummaryData(
            status: home.isLoading ? '로그인 확인 중' : '로그인 필요',
            secondary: home.isLoading
                ? home.statusMessage
                : '출결을 이용하려면 로그인해 주세요.',
          );
        }
        if (attendance.phase == AttendancePhase.fetchingLecture) {
          return const HomeServiceSummaryData(
            status: '수업 조회 중',
            secondary: '현재 수업을 확인하고 있어요.',
          );
        }
        if (attendance.error != null) {
          return HomeServiceSummaryData(
            status: '수업 조회 실패',
            secondary: attendance.error,
            facts: const [(label: '다음 동작', value: '다시 시도')],
          );
        }
        if (attendance.phase != AttendancePhase.idle) {
          final progress = switch (attendance.phase) {
            AttendancePhase.enteringCode => '번호 입력 중',
            AttendancePhase.locating => '위치 확인 중',
            AttendancePhase.submitting => '출석 제출 중',
            _ => '출결 진행 중',
          };
          return HomeServiceSummaryData(
            status: progress,
            secondary: attendance.currentLecture?.name,
          );
        }
        final lecture = attendance.currentLecture;
        if (lecture != null) {
          return HomeServiceSummaryData(
            status: lecture.name,
            secondary: lecture.time,
            facts: const [(label: '다음 동작', value: '출결 번호 입력')],
          );
        }
        return HomeServiceSummaryData(
          status: attendance.hasCheckedLecture ? '출결 가능한 수업 없음' : '수업 확인 전',
          secondary: attendance.hasCheckedLecture
              ? '새로고침으로 다시 확인할 수 있어요.'
              : '조회된 수업 정보가 아직 없어요.',
        );
      case HomeService.seat:
        return HomeCampusSummary.seats(
          summaryRef.watch(seatControllerProvider),
        );
      case HomeService.menu:
        return HomeCampusSummary.menu(
          summaryRef.watch(cafeteriaMenuControllerProvider),
          summaryRef.watch(homeCampusTimeProvider),
        );
    }
  }

  void _onPrimaryChanged(HomeService service) {
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
        final isLoading = ref.watch(
          homeControllerProvider.select((state) => state.isLoading),
        );
        final isLoggedIn = ref.watch(
          homeControllerProvider.select((state) => state.isLoggedIn),
        );
        final loginError = !isLoading && !isLoggedIn ? _loginError : null;
        final sessionMessage = ref.watch(
          homeControllerProvider.select((state) => state.statusMessage),
        );
        final statusMessage = loginError ?? sessionMessage;
        if (statusMessage == '서비스를 이용하려면 로그인해 주세요.' ||
            statusMessage == '로그인했어요. 세션을 활성화했어요.' ||
            statusMessage == '저장된 세션으로 로그인했어요.' ||
            statusMessage == '세션이 아직 유효해요.') {
          return const SizedBox.shrink();
        }
        final reduceMotion = MediaQuery.disableAnimationsOf(context);
        final palette =
            Theme.of(context).extension<HongikPalette>() ?? HongikPalette.light;

        return AnimatedSize(
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topLeft,
          clipBehavior: Clip.none,
          child: Semantics(
            liveRegion: true,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: palette.cardSurfaceMuted,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  isLoading
                      ? const SizedBox(
                          width: 19,
                          height: 19,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          loginError != null
                              ? Icons.error_outline_rounded
                              : Icons.info_outline_rounded,
                          size: 19,
                          color: loginError != null
                              ? Theme.of(context).colorScheme.error
                              : palette.textSecondary,
                        ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      statusMessage,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: loginError != null
                            ? Theme.of(context).colorScheme.error
                            : palette.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInstallOverlay() {
    return Consumer(
      builder: (context, ref, child) {
        final installState = ref.watch(appInstallControllerProvider);
        final requestedTarget = _requestedInstallTarget;
        final isRequested = requestedTarget != null;
        final showProactivePrompt =
            _installPromptDelayElapsed && installState.showProactivePromo;
        final keyboardIsVisible = MediaQuery.viewInsetsOf(context).bottom > 0;

        if ((!isRequested && !showProactivePrompt) || keyboardIsVisible) {
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
                    onBack: () {
                      if (_installGuideOrigin == _InstallGuideOrigin.appInfo) {
                        _closeRequestedInstallGuide(reopenAppInfo: true);
                        return;
                      }
                      setState(() => _installGuideExpanded = false);
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
        final desktop = MediaQuery.sizeOf(context).width >= 960;
        return LoginForm(
          layoutBuilder: (content, action) => HomeAttendanceActionLayout(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (desktop) _buildStatusMessage() else content,
                const SizedBox(height: 12),
                if (desktop) content else _buildStatusMessage(),
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
            if (result != 'Success') {
              if (mounted) {
                final message = _loginFailureMessage(result);
                if (desktop) {
                  setState(() => _loginError = message);
                } else {
                  _showSnackBar(message);
                }
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
        key: const ValueKey('home-version-info'),
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

class _AppInfoRow extends StatelessWidget {
  const _AppInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: colorScheme.primary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AppInfoAction extends StatelessWidget {
  const _AppInfoAction({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: colorScheme.primary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
