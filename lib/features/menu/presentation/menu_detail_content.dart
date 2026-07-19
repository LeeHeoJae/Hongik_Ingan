import 'package:flutter/material.dart' hide MenuController;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hongik_ingan/features/menu/application/menu_controller.dart';
import 'package:hongik_ingan/features/menu/domain/menu.dart';
import 'package:hongik_ingan/features/menu/presentation/widgets/cafeteria_selector.dart';
import 'package:hongik_ingan/features/menu/presentation/widgets/menu_content_body.dart';
import 'package:hongik_ingan/features/menu/presentation/widgets/menu_date_selector.dart';

class MenuDetailContent extends ConsumerWidget {
  const MenuDetailContent({
    super.key,
    this.compact = false,
    this.useAdaptiveGrid = false,
  });

  final bool compact;
  final bool useAdaptiveGrid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(menuControllerProvider);
    final controller = ref.read(menuControllerProvider.notifier);
    final selectedMenu = state.selectedMenu;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MenuDateSelector(
          dates: state.dates,
          selectedDate: state.selectedDate,
          onSelected: controller.selectDate,
          compact: compact,
        ),
        if (_shouldShowCafeteriaSelector(selectedMenu)) ...[
          SizedBox(height: compact ? 10 : 14),
          CafeteriaSelector(
            cafeterias: selectedMenu!.cafeterias,
            selectedName: state.selectedCafeteria?.name,
            onSelected: controller.selectCafeteria,
            compact: compact,
          ),
        ],
        SizedBox(height: compact ? 12 : 16),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: MenuContentBody(
              isInitialLoading: state.isLoading && state.menus.isEmpty,
              selectedMenu: selectedMenu,
              selectedCafeteria: state.selectedCafeteria,
              onRefresh: controller.refresh,
              compact: compact,
              useAdaptiveGrid: useAdaptiveGrid,
            ),
          ),
        ),
      ],
    );
  }

  bool _shouldShowCafeteriaSelector(DailyMenu? menu) {
    return menu != null &&
        menu.status == MenuDayStatus.loaded &&
        menu.cafeterias.length > 1;
  }
}
