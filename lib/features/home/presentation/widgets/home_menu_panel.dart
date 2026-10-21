import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hongik_ingan/features/cafeteria_menu/application/cafeteria_menu_controller.dart';
import 'package:hongik_ingan/features/cafeteria_menu/domain/cafeteria_menu.dart';
import 'package:hongik_ingan/features/cafeteria_menu/presentation/cafeteria_menu_content.dart';
import '../layouts/home_service_workspace.dart';
import 'home_attendance_density.dart';
import 'home_panel_heading.dart';

class HomeMenuPanel extends ConsumerWidget {
  const HomeMenuPanel({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cafeteriaMenuControllerProvider);
    final density = HomeAttendanceDensityScope.of(context);
    final controller = ref.read(cafeteriaMenuControllerProvider.notifier);
    final menuSubtitle = state.isLoading
        ? '선택한 날짜의 메뉴를 확인하고 있어요.'
        : '${MenuDateRange.monthDayLabel(state.selectedDate)} (${MenuDateRange.weekdayLabel(state.selectedDate)}요일)';
    return SelectionArea(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: density.verticalPadding,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HomePanelHeading(
              service: HomeService.menu,
              title: '주간 식당 메뉴',
              subtitle: menuSubtitle,
              onRefresh: state.isLoading
                  ? null
                  : () => unawaited(controller.refresh()),
              isRefreshing: state.isLoading,
            ),
            SizedBox(height: density.detailHeadingGap),
            const CafeteriaMenuContent(naturalHeight: true),
          ],
        ),
      ),
    );
  }
}
