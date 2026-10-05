import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hongik_ingan/core/theme/color.dart';
import 'package:hongik_ingan/features/cafeteria_menu/application/cafeteria_menu_controller.dart';
import 'package:hongik_ingan/features/cafeteria_menu/domain/cafeteria_menu.dart';
import 'package:hongik_ingan/features/cafeteria_menu/presentation/widgets/cafeteria_selector.dart';
import 'package:hongik_ingan/features/cafeteria_menu/presentation/widgets/cafeteria_menu_date_selector.dart';
import 'package:hongik_ingan/features/cafeteria_menu/presentation/widgets/cafeteria_menu_section.dart';

class CafeteriaMenuContent extends ConsumerWidget {
  const CafeteriaMenuContent({
    super.key,
    this.compact = false,
    this.useAdaptiveGrid = false,
    this.wideDetail = false,
    this.naturalHeight = false,
  });

  final bool compact;
  final bool useAdaptiveGrid;
  final bool wideDetail;
  final bool naturalHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cafeteriaMenuControllerProvider);
    final controller = ref.read(cafeteriaMenuControllerProvider.notifier);
    final menu = state.selectedMenu;
    final cafeteria = state.selectedCafeteria;
    final hasMenu =
        menu?.status == MenuDayStatus.loaded && cafeteria?.hasMenu == true;
    return LayoutBuilder(
      builder: (context, constraints) {
        final controlsWidth = constraints.maxWidth.clamp(0.0, 280.0);
        final content = Column(
          key: hasMenu
              ? const ValueKey('menu-results')
              : const ValueKey('menu-compact-state'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (state.baseDate.weekday >= DateTime.saturday) ...[
              Text(
                '${state.isShowingCurrentWeek ? '이번 주' : '다음 주'} · '
                '${MenuDateRange.monthDayLabel(state.dates.first)} ~ '
                '${MenuDateRange.monthDayLabel(state.dates.last)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (state.isShowingCurrentWeek)
                Text(
                  '다음 주 식단이 아직 공개되지 않아 이번 주 식단을 보여드려요.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              const SizedBox(height: 8),
            ],
            SelectionContainer.disabled(
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  SizedBox(
                    width: controlsWidth,
                    child: CafeteriaMenuDateSelector(
                      dates: state.dates,
                      selectedDate: state.selectedDate,
                      onSelected: controller.selectDate,
                      compact: true,
                    ),
                  ),
                  if (_shouldShowCafeteriaSelector(menu))
                    SizedBox(
                      width: controlsWidth,
                      child: CafeteriaSelector(
                        cafeterias: menu!.cafeterias,
                        selectedName: cafeteria?.name,
                        onSelected: controller.selectCafeteria,
                        compact: true,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (cafeteria != null && !_shouldShowCafeteriaSelector(menu)) ...[
              Text(
                cafeteria.name,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
            ],
            if (hasMenu)
              CafeteriaMenuSection(
                cafeteria: cafeteria!,
                compact: true,
                useAdaptiveGrid: useAdaptiveGrid,
              )
            else
              SelectionContainer.disabled(
                child: _buildCompactStatus(context, state, controller),
              ),
          ],
        );
        return naturalHeight
            ? content
            : SingleChildScrollView(
                key: const PageStorageKey('menu-detail-scroll'),
                child: content,
              );
      },
    );
  }

  Widget _buildCompactStatus(
    BuildContext context,
    CafeteriaMenuState state,
    CafeteriaMenuController controller,
  ) {
    final palette =
        Theme.of(context).extension<HongikPalette>() ?? HongikPalette.light;
    final menu = state.selectedMenu;
    final cafeteria = state.selectedCafeteria;
    final isLoading = state.isLoading && menu == null;
    late final IconData icon;
    late final String title;
    late final String message;
    late final String? actionLabel;
    var isError = false;

    if (isLoading) {
      icon = Icons.restaurant_menu_rounded;
      title = '메뉴 확인 중';
      message = '선택한 날짜의 메뉴를 확인하고 있어요.';
      actionLabel = null;
    } else if (menu == null && state.error != null) {
      icon = Icons.wifi_off_rounded;
      title = '식당 메뉴를 불러오지 못했어요';
      message = state.error!;
      actionLabel = '다시 시도';
      isError = true;
    } else if (menu == null) {
      icon = Icons.restaurant_rounded;
      title = '메뉴를 준비하고 있어요';
      message = '선택한 날짜의 메뉴 정보를 아직 불러오지 못했어요.';
      actionLabel = '새로고침';
    } else if (menu.status == MenuDayStatus.networkError) {
      icon = Icons.wifi_off_rounded;
      title = '식당 메뉴를 불러오지 못했어요';
      message = menu.message ?? '식당 메뉴 페이지에 연결할 수 없어요.';
      actionLabel = '다시 시도';
      isError = true;
    } else if (menu.status == MenuDayStatus.parseFailed) {
      icon = Icons.error_outline_rounded;
      title = '메뉴를 읽지 못했어요';
      message = menu.message ?? '식당 메뉴 페이지 형식이 변경됐을 수 있어요.';
      actionLabel = '다시 시도';
      isError = true;
    } else if (!menu.hasMenu) {
      icon = Icons.no_food_rounded;
      title = menu.message != null ? '운영하지 않는 날이에요' : '등록된 메뉴가 없어요';
      message = menu.message ?? '선택한 날짜에 등록된 식단 정보가 없어요.';
      actionLabel = '새로고침';
    } else if (cafeteria == null) {
      icon = Icons.storefront_rounded;
      title = '식당 정보가 없어요';
      message = '선택한 날짜에 표시할 식당 정보가 없어요.';
      actionLabel = '새로고침';
    } else {
      icon = Icons.no_food_rounded;
      title = '선택한 식당의 메뉴가 없어요';
      message = '다른 식당을 선택하거나 새로고침해 주세요.';
      actionLabel = '새로고침';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.cardSurfaceMuted,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (isLoading)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(
              icon,
              size: 22,
              color: isError ? palette.brandRed : palette.brandBlue,
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Semantics(
              label: '$title. $message',
              liveRegion: true,
              container: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    message,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (actionLabel != null) ...[
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: controller.refresh,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(96, 44),
                foregroundColor: palette.textSecondary,
                side: BorderSide(color: palette.cardOutline),
              ),
              child: Text(actionLabel),
            ),
          ],
        ],
      ),
    );
  }

  bool _shouldShowCafeteriaSelector(DailyMenu? menu) {
    return menu != null &&
        menu.status == MenuDayStatus.loaded &&
        menu.cafeterias.length > 1;
  }
}
