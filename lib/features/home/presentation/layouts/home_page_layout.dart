import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hongik_ingan/core/time/campus_clock.dart';
import 'package:hongik_ingan/core/presentation/widgets/debug_build_badge.dart';
import 'package:hongik_ingan/features/cafeteria_menu/application/meal_choice_controller.dart';
import 'package:hongik_ingan/features/attendance/debug/attendance_test_controls.dart';
import 'package:hongik_ingan/features/attendance/presentation/attendance_auto_refresh.dart';
import 'package:hongik_ingan/features/seat/application/seat_controller.dart';
import 'package:hongik_ingan/features/seat/domain/seat.dart';
import 'package:hongik_ingan/features/seat/presentation/seat_auto_refresh.dart';
import '../home_attendance_presentation.dart';
import '../home_service_summary_provider.dart';
import '../widgets/home_content_size_reporter.dart';
import '../widgets/home_campus_summary.dart';
import '../widgets/home_mobile_layout.dart';
import '../widgets/home_splash_space.dart';
import '../widgets/login_form.dart';
import 'home_service_workspace.dart';

typedef HomePageDetailBuilder =
    Widget Function(
      BuildContext context,
      HomeService service,
      bool isPrimary,
      bool animateLayout,
      VoidCallback onContentSizeChanged,
    );

/// Owns page geometry and motion; service panels own their displayed content.
class HomePageLayout extends ConsumerStatefulWidget {
  const HomePageLayout({
    super.key,
    required this.presentation,
    required this.holdBackdrop,
    required this.attendanceLayoutKey,
    required this.primaryService,
    required this.onPrimaryChanged,
    required this.header,
    required this.footer,
    required this.installOverlay,
    required this.detailBuilder,
  });

  final HomeAttendancePresentation presentation;
  final bool holdBackdrop;
  final Object attendanceLayoutKey;
  final HomeService primaryService;
  final ValueChanged<HomeService> onPrimaryChanged;
  final Widget header;
  final Widget footer;
  final Widget installOverlay;
  final HomePageDetailBuilder detailBuilder;

  @override
  ConsumerState<HomePageLayout> createState() => _HomePageLayoutState();
}

class _HomePageLayoutState extends ConsumerState<HomePageLayout> {
  final GlobalKey _serviceWorkspaceKey = GlobalKey();
  double _previousKeyboardInset = 0;
  bool _keyboardResizing = false;
  Size? _previousViewportSize;
  bool _viewportResizing = false;
  int _viewportResizeGeneration = 0;
  int _viewportLayoutRevision = 0;
  bool get _layoutResizing => _keyboardResizing || _viewportResizing;
  Timer? _keyboardSettleTimer;
  double _pageHeaderHeight = 48;
  double _pageFooterHeight = 0;
  double _mobileAttendanceHeight = 280;

  @override
  void dispose() {
    _keyboardSettleTimer?.cancel();
    super.dispose();
  }

  void _resumeViewportMotion(int generation, int revision) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _viewportResizeGeneration) return;
      if (revision != _viewportLayoutRevision) {
        _resumeViewportMotion(generation, _viewportLayoutRevision);
      } else {
        setState(() => _viewportResizing = false);
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  Widget build(BuildContext context) {
    final viewportSize = MediaQuery.sizeOf(context);
    if (_previousViewportSize != viewportSize) {
      final hadViewport = _previousViewportSize != null;
      _previousViewportSize = viewportSize;
      if (hadViewport) {
        _viewportResizing = true;
        final generation = ++_viewportResizeGeneration;
        final revision = _viewportLayoutRevision;
        // Observe a full frame of natural-size reporting before resuming.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || generation != _viewportResizeGeneration) return;
          _resumeViewportMotion(generation, revision);
        });
      }
    }
    final rawKeyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final keyboardInset = widget.holdBackdrop ? 0.0 : rawKeyboardInset;
    final keyboardIsVisible = keyboardInset > 0;
    if (_previousKeyboardInset != keyboardInset) {
      _previousKeyboardInset = keyboardInset;
      _keyboardResizing = true;
      _keyboardSettleTimer?.cancel();
      _keyboardSettleTimer = Timer(const Duration(milliseconds: 100), () {
        if (mounted) setState(() => _keyboardResizing = false);
      });
    }
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: widget.holdBackdrop
          ? media.copyWith(
              viewInsets: EdgeInsets.zero,
              padding: media.padding.copyWith(bottom: media.viewPadding.bottom),
            )
          : media,
      child: Scaffold(
        resizeToAvoidBottomInset: !widget.holdBackdrop,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: HomeSplashSpace(
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
                                widget.primaryService == HomeService.attendance
                                ? _mobileAttendanceHeight
                                : 320,
                            attendanceIsPrimary:
                                widget.primaryService == HomeService.attendance,
                            textScale: textScale,
                            minimumAuxiliaryHeight: [
                              for (final service in HomeService.values)
                                if (service != widget.primaryService)
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
                            attendanceHeightReduction:
                                widget.presentation.heightReduction,
                          )
                        : null;
                    final compactChrome =
                        !mobile &&
                        widget.primaryService == HomeService.attendance &&
                        _pageHeaderHeight +
                                _pageFooterHeight +
                                _mobileAttendanceHeight +
                                56 >
                            constraints.maxHeight;
                    final topPadding = mobile
                        ? 0.0
                        : (compactChrome ? 8.0 : 16.0);
                    final bottomPadding =
                        mobileLayout?.bottomPadding ??
                        (compactChrome ? 8.0 : 24.0);
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
                        _viewportLayoutRevision++;
                        setState(() => _pageHeaderHeight = size.height);
                      },
                      child: widget.header,
                    );
                    final workspace = SeatAutoRefresh(
                      onRefresh: () => ref
                          .read(seatControllerProvider.notifier)
                          .fetchStatusForLocation(SeatLocation.tBuilding),
                      child: AttendanceAutoRefresh(
                        child: HomeServiceWorkspace(
                          key: _serviceWorkspaceKey,
                          attentionScope: widget.presentation.isLoggedIn
                              ? widget.presentation.userId
                              : null,
                          availableHeight: constraints.maxHeight,
                          viewportHeight:
                              mobileLayout?.viewportHeight ??
                              constraints.maxHeight -
                                  topPadding -
                                  bottomPadding -
                                  _pageFooterHeight -
                                  (sideHeader
                                      ? 0
                                      : _pageHeaderHeight + headerGap),
                          adaptiveMobileLayout: mobile,
                          mobileLayout: mobileLayout,
                          attendanceHeightReduction:
                              widget.presentation.heightReduction,
                          balanceMobileAttendance:
                              widget.presentation.balanceSummary &&
                              !keyboardIsVisible,
                          mobileHeaderGap: headerGap,
                          mobileHeader: mobile ? header : null,
                          mobileHeaderHeight: _pageHeaderHeight,
                          flexibleMobileHeader: mobile && !keyboardIsVisible,
                          animateLayout: !_layoutResizing,
                          holdLayout: widget.holdBackdrop,
                          attendanceLayoutKey: widget.attendanceLayoutKey,
                          onAttendanceHeightChanged: (height) {
                            // This measures the held presentation, not live data.
                            // Resizing must update its natural height immediately.
                            if (!mounted ||
                                (_mobileAttendanceHeight - height).abs() <
                                    0.5) {
                              return;
                            }
                            _viewportLayoutRevision++;
                            setState(() => _mobileAttendanceHeight = height);
                          },
                          detailBuilder: (service, isPrimary) =>
                              widget.detailBuilder(
                                context,
                                service,
                                isPrimary,
                                service == HomeService.attendance &&
                                    !_layoutResizing,
                                () => _viewportLayoutRevision++,
                              ),
                          summaryBuilder: _buildServiceSummary,
                          onPrimaryChanged: widget.onPrimaryChanged,
                          wideHeader: sideHeader ? header : null,
                          wideHeaderHeight: _pageHeaderHeight,
                          reserveWideHeaderSpace: _pageHeaderHeight > 48,
                        ),
                      ),
                    );

                    final page = SingleChildScrollView(
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
                                (constraints.maxHeight -
                                        topPadding -
                                        bottomPadding)
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
                                  _viewportLayoutRevision++;
                                  setState(
                                    () => _pageFooterHeight = size.height,
                                  );
                                },
                                child: HomeSplashContent(child: widget.footer),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                    return NotificationListener<ScrollMetricsNotification>(
                      onNotification: LoginForm.handleScrollMetrics,
                      child: page,
                    );
                  },
                ),
                if (kDebugMode)
                  const Positioned(
                    right: 16,
                    bottom: 16,
                    child: Row(
                      key: ValueKey('home-debug-tools'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AttendanceTestControls(),
                        SizedBox(width: 8),
                        DebugBuildBadge(),
                      ],
                    ),
                  ),
                Positioned.fill(child: widget.installOverlay),
              ],
            ),
          ),
        ),
      ),
    );
  }

  HomeServiceSummaryData _buildServiceSummary(
    HomeService service,
    WidgetRef summaryRef,
  ) {
    final summary = summaryRef.watch(homeServiceSummaryProvider(service));
    if (service == HomeService.menu &&
        widget.primaryService != HomeService.menu &&
        TickerMode.valuesOf(summaryRef.context).enabled &&
        summary.hasMenuChoices) {
      final now = summaryRef.watch(homeCampusTimeProvider);
      summaryRef.watch(activeMealChoiceProvider(campusDateKey(now)));
    }
    return summary;
  }
}
