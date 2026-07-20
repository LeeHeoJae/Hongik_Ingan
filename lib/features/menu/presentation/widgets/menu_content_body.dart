import 'package:flutter/material.dart';
import 'package:hongik_ingan/features/campus/presentation/campus_sheet_scaffold.dart';
import 'package:hongik_ingan/features/menu/domain/menu.dart';
import 'package:hongik_ingan/features/menu/presentation/widgets/cafeteria_menu_section.dart';

class MenuContentBody extends StatelessWidget {
  const MenuContentBody({
    super.key,
    required this.isInitialLoading,
    required this.selectedMenu,
    required this.selectedCafeteria,
    required this.onRefresh,
    required this.compact,
    required this.useAdaptiveGrid,
  });

  final bool isInitialLoading;
  final DailyMenu? selectedMenu;
  final CafeteriaMenu? selectedCafeteria;
  final VoidCallback onRefresh;
  final bool compact;
  final bool useAdaptiveGrid;

  @override
  Widget build(BuildContext context) {
    if (isInitialLoading) {
      return const CampusLoadingSkeleton(key: ValueKey('loading'));
    }

    final menu = selectedMenu;
    if (menu == null) {
      return CampusStateMessage(
        key: const ValueKey('empty'),
        icon: Icons.restaurant_rounded,
        title: '메뉴를 준비하고 있습니다',
        message: '선택한 날짜의 메뉴 정보를 아직 불러오지 못했습니다.',
        actionLabel: '새로고침',
        onAction: onRefresh,
      );
    }

    if (menu.status == MenuDayStatus.networkError) {
      return CampusStateMessage(
        key: ValueKey('network-${menu.date}'),
        icon: Icons.wifi_off_rounded,
        title: '식당 메뉴를 불러오지 못했습니다',
        message: menu.message ?? '식당 메뉴 페이지에 연결할 수 없습니다.',
        tone: CampusStateTone.error,
        actionLabel: '다시 시도',
        onAction: onRefresh,
      );
    }

    if (menu.status == MenuDayStatus.parseFailed) {
      return CampusStateMessage(
        key: ValueKey('parse-${menu.date}'),
        icon: Icons.error_outline_rounded,
        title: '메뉴를 읽지 못했습니다',
        message: menu.message ?? '식당 메뉴 페이지 형식이 변경되었을 수 있습니다.',
        tone: CampusStateTone.error,
        actionLabel: '다시 시도',
        onAction: onRefresh,
      );
    }

    if (!menu.hasMenu) {
      final isClosed = menu.message != null;
      return CampusStateMessage(
        key: ValueKey('no-menu-${menu.date}'),
        icon: Icons.no_food_rounded,
        title: isClosed ? '운영하지 않는 날입니다' : '등록된 메뉴가 없습니다',
        message: menu.message ?? '선택한 날짜에 등록된 식단 정보가 없습니다.',
        actionLabel: '새로고침',
        onAction: onRefresh,
      );
    }

    final cafeteria = selectedCafeteria;
    if (cafeteria == null) {
      return CampusStateMessage(
        key: ValueKey('no-cafeteria-${menu.date}'),
        icon: Icons.storefront_rounded,
        title: '식당 정보가 없습니다',
        message: '선택한 날짜에 표시할 식당 정보가 없습니다.',
        actionLabel: '새로고침',
        onAction: onRefresh,
      );
    }

    return ListView(
      key: ValueKey('content-${menu.date}-${cafeteria.name}'),
      padding: const EdgeInsets.only(bottom: 2),
      children: [
        CafeteriaMenuSection(
          cafeteria: cafeteria,
          compact: compact,
          useAdaptiveGrid: useAdaptiveGrid,
        ),
      ],
    );
  }
}
