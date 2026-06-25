import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hongik_ingan/core/theme/color.dart';
import 'package:hongik_ingan/features/food_menu/application/food_menu_controller.dart';
import 'package:hongik_ingan/features/food_menu/domain/food_menu.dart';
import 'package:hongik_ingan/features/food_menu/presentation/food_menu_detail_content.dart';

class FoodMenuBottomSheet extends ConsumerStatefulWidget {
  const FoodMenuBottomSheet({super.key});

  @override
  ConsumerState<FoodMenuBottomSheet> createState() =>
      _FoodMenuBottomSheetState();
}

class _FoodMenuBottomSheetState extends ConsumerState<FoodMenuBottomSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(foodMenuControllerProvider.notifier).fetchMenus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(foodMenuControllerProvider);
    final controller = ref.read(foodMenuControllerProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;
    final palette =
        Theme.of(context).extension<HongikPalette>() ?? HongikPalette.light;

    return FractionallySizedBox(
      heightFactor: 0.9,
      alignment: Alignment.bottomCenter,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 660),
          child: Material(
            color: colorScheme.surface,
            elevation: 8,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            clipBehavior: Clip.antiAlias,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: colorScheme.onSurface.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    _FoodSheetHeader(
                      selectedDate: state.selectedDate,
                      isRefreshing: state.isLoading && state.menus.isNotEmpty,
                      accentColor: palette.brandNavy,
                      onRefresh: controller.refresh,
                      onClose: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(height: 14),
                    const Expanded(child: FoodMenuDetailContent()),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FoodSheetHeader extends StatelessWidget {
  const _FoodSheetHeader({
    required this.selectedDate,
    required this.isRefreshing,
    required this.accentColor,
    required this.onRefresh,
    required this.onClose,
  });

  final DateTime selectedDate;
  final bool isRefreshing;
  final Color accentColor;
  final VoidCallback onRefresh;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Container(
          width: 42,
          height: 40,
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(
            Icons.restaurant_menu_rounded,
            color: accentColor,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '오늘의 학식 정보',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${FoodMenuDateRange.monthDayLabel(selectedDate)} (${FoodMenuDateRange.weekdayLabel(selectedDate)}요일)',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.56),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: '새로고침',
          onPressed: isRefreshing ? null : onRefresh,
          style: IconButton.styleFrom(
            foregroundColor: colorScheme.onSurface.withValues(alpha: 0.72),
          ),
          icon: isRefreshing
              ? const SizedBox(
                  width: 19,
                  height: 19,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                )
              : const Icon(Icons.refresh_rounded),
        ),
        IconButton(
          tooltip: '닫기',
          onPressed: onClose,
          style: IconButton.styleFrom(
            foregroundColor: colorScheme.onSurface.withValues(alpha: 0.72),
          ),
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    );
  }
}
