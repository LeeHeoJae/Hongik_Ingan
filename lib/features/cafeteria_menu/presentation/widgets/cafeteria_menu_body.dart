import 'package:flutter/material.dart';
import 'package:hongik_ingan/core/presentation/widgets/content_loading_skeleton.dart';
import 'package:hongik_ingan/core/presentation/widgets/content_state_message.dart';
import 'package:hongik_ingan/features/cafeteria_menu/domain/cafeteria_menu.dart';
import 'package:hongik_ingan/features/cafeteria_menu/presentation/widgets/cafeteria_menu_section.dart';

class CafeteriaMenuBody extends StatelessWidget {
  const CafeteriaMenuBody({
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
      return const ContentLoadingSkeleton(key: ValueKey('loading'));
    }

    final menu = selectedMenu;
    if (menu == null) {
      return ContentStateMessage(
        key: const ValueKey('empty'),
        icon: Icons.restaurant_rounded,
        title: '메뉴를 준비하고 있어요',
        message: '선택한 날짜의 메뉴 정보를 아직 불러오지 못했어요.',
        actionLabel: '새로고침',
        onAction: onRefresh,
      );
    }

    if (menu.status == MenuDayStatus.networkError) {
      return ContentStateMessage(
        key: ValueKey('network-${menu.date}'),
        icon: Icons.wifi_off_rounded,
        title: '식당 메뉴를 불러오지 못했어요',
        message: menu.message ?? '식당 메뉴 페이지에 연결할 수 없어요.',
        tone: ContentStateTone.error,
        actionLabel: '다시 시도',
        onAction: onRefresh,
      );
    }

    if (menu.status == MenuDayStatus.parseFailed) {
      return ContentStateMessage(
        key: ValueKey('parse-${menu.date}'),
        icon: Icons.error_outline_rounded,
        title: '메뉴를 읽지 못했어요',
        message: menu.message ?? '식당 메뉴 페이지 형식이 변경됐을 수 있어요.',
        tone: ContentStateTone.error,
        actionLabel: '다시 시도',
        onAction: onRefresh,
      );
    }

    if (!menu.hasMenu) {
      final isClosed = menu.message != null;
      return ContentStateMessage(
        key: ValueKey('no-menu-${menu.date}'),
        icon: Icons.no_food_rounded,
        title: isClosed ? '운영하지 않는 날이에요' : '등록된 메뉴가 없어요',
        message: menu.message ?? '선택한 날짜에 등록된 식단 정보가 없어요.',
        actionLabel: '새로고침',
        onAction: onRefresh,
      );
    }

    final cafeteria = selectedCafeteria;
    if (cafeteria == null) {
      return ContentStateMessage(
        key: ValueKey('no-cafeteria-${menu.date}'),
        icon: Icons.storefront_rounded,
        title: '식당 정보가 없어요',
        message: '선택한 날짜에 표시할 식당 정보가 없어요.',
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
