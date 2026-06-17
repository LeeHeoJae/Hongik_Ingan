import 'package:flutter/material.dart';
import 'package:hongik_ingan/core/theme/color.dart';
import 'package:hongik_ingan/screens/widgets/attendance_bottom_sheet.dart';
import 'package:hongik_ingan/screens/widgets/food_menu_bottom_sheet.dart';
import 'package:hongik_ingan/screens/widgets/study_room_status_bottom_sheet.dart';

class Dashboard extends StatefulWidget {
  final String userId;
  final VoidCallback onLogout;

  const Dashboard({super.key, required this.userId, required this.onLogout});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
          ),
        );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showAttendanceSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const AttendanceBottomSheet(),
    );
  }

  void _showCampusSheet(BuildContext context, Widget sheet) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => sheet,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette =
        Theme.of(context).extension<HongikPalette>() ?? HongikPalette.light;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(32, 34, 32, 30),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.06),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                children: [
                  SlideTransition(
                    position: _slideAnimation,
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: palette.brandNavy.withValues(
                          alpha: isDark ? 0.22 : 0.08,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.face_retouching_natural,
                        size: 42,
                        color: palette.brandNavy,
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),
                  SlideTransition(
                    position: _slideAnimation,
                    child: Text(
                      '반갑습니다, ${widget.userId.toUpperCase()}님',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(height: 34),
                  SlideTransition(
                    position: _slideAnimation,
                    child: ElevatedButton(
                      onPressed: () => _showAttendanceSheet(context),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 62),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(17),
                        ),
                        elevation: 5,
                        shadowColor: palette.brandBlue.withValues(alpha: 0.24),
                        backgroundColor: palette.brandBlue,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text(
                        '출결 번호 입력하러 가기',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),
                  SlideTransition(
                    position: _slideAnimation,
                    child: TextButton(
                      onPressed: widget.onLogout,
                      child: Text(
                        '로그아웃',
                        style: TextStyle(
                          color: colorScheme.onSurface.withValues(alpha: 0.46),
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            SlideTransition(
              position: _slideAnimation,
              child: _CampusQuickActions(
                onStudyRoomTap: () => _showCampusSheet(
                  context,
                  const StudyRoomStatusBottomSheet(),
                ),
                onFoodMenuTap: () =>
                    _showCampusSheet(context, const FoodMenuBottomSheet()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CampusQuickActions extends StatelessWidget {
  const _CampusQuickActions({
    required this.onStudyRoomTap,
    required this.onFoodMenuTap,
  });

  final VoidCallback onStudyRoomTap;
  final VoidCallback onFoodMenuTap;

  @override
  Widget build(BuildContext context) {
    final palette =
        Theme.of(context).extension<HongikPalette>() ?? HongikPalette.light;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CampusActionCard(
          icon: Icons.restaurant_menu_rounded,
          title: '오늘의 식당 메뉴',
          subtitle: '기숙사 식당 & 교직원 식당',
          iconColor: palette.warning,
          iconBackgroundColor: palette.warning.withValues(alpha: 0.12),
          onTap: onFoodMenuTap,
        ),
        const SizedBox(height: 16),
        _CampusActionCard(
          icon: Icons.local_library_rounded,
          title: '열람실 좌석 현황',
          subtitle: '학관 · T동 · R동 실시간 잔여석',
          iconColor: palette.brandBlue,
          iconBackgroundColor: palette.brandBlue.withValues(alpha: 0.1),
          onTap: onStudyRoomTap,
        ),
      ],
    );
  }
}

class _CampusActionCard extends StatelessWidget {
  const _CampusActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconColor,
    required this.iconBackgroundColor,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;
  final Color iconBackgroundColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.05),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: iconBackgroundColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 29),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colorScheme.onSurface.withValues(alpha: 0.54),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurface.withValues(alpha: 0.28),
                size: 30,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
