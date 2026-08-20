import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hongik_ingan/features/cafeteria_menu/application/cafeteria_menu_controller.dart';
import 'package:hongik_ingan/features/cafeteria_menu/domain/cafeteria_menu.dart';
import 'package:hongik_ingan/features/cafeteria_menu/presentation/widgets/cafeteria_selector.dart';
import 'package:hongik_ingan/features/cafeteria_menu/presentation/widgets/cafeteria_menu_body.dart';
import 'package:hongik_ingan/features/cafeteria_menu/presentation/widgets/cafeteria_menu_date_selector.dart';

class CafeteriaMenuContent extends ConsumerWidget {
  const CafeteriaMenuContent({
    super.key,
    this.compact = false,
    this.useAdaptiveGrid = false,
  });

  final bool compact;
  final bool useAdaptiveGrid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cafeteriaMenuControllerProvider);
    final controller = ref.read(cafeteriaMenuControllerProvider.notifier);
    final selectedMenu = state.selectedMenu;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CafeteriaMenuDateSelector(
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
            child: CafeteriaMenuBody(
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
