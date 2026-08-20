import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hongik_ingan/core/presentation/widgets/app_bottom_sheet_scaffold.dart';
import 'package:hongik_ingan/features/cafeteria_menu/application/cafeteria_menu_controller.dart';
import 'package:hongik_ingan/features/cafeteria_menu/domain/cafeteria_menu.dart';
import 'package:hongik_ingan/features/cafeteria_menu/presentation/cafeteria_menu_content.dart';

class CafeteriaMenuBottomSheet extends ConsumerStatefulWidget {
  const CafeteriaMenuBottomSheet({super.key});

  @override
  ConsumerState<CafeteriaMenuBottomSheet> createState() =>
      _CafeteriaMenuBottomSheetState();
}

class _CafeteriaMenuBottomSheetState
    extends ConsumerState<CafeteriaMenuBottomSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(cafeteriaMenuControllerProvider.notifier).fetchMenus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cafeteriaMenuControllerProvider);
    final controller = ref.read(cafeteriaMenuControllerProvider.notifier);
    return AppBottomSheetScaffold(
      title: '주간 식당 메뉴',
      subtitle:
          '${MenuDateRange.monthDayLabel(state.selectedDate)} '
          '(${MenuDateRange.weekdayLabel(state.selectedDate)}요일)',
      icon: Icons.restaurant_menu_rounded,
      isRefreshing: state.isLoading && state.menus.isNotEmpty,
      onRefresh: controller.refresh,
      child: const CafeteriaMenuContent(),
    );
  }
}
