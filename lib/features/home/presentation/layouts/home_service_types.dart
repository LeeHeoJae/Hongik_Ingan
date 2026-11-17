part of 'home_service_workspace.dart';

enum HomeService { attendance, seat, menu }

extension HomeServiceLabel on HomeService {
  String get title => switch (this) {
    HomeService.attendance => '로그인·출결',
    HomeService.seat => '열람실',
    HomeService.menu => '학식 메뉴',
  };

  IconData get icon => switch (this) {
    HomeService.attendance => Icons.check_circle_rounded,
    HomeService.seat => Icons.local_library_rounded,
    HomeService.menu => Icons.restaurant_menu_rounded,
  };

  Color iconBackgroundColor(ThemeData theme) {
    return switch (this) {
      HomeService.attendance => theme.colorScheme.primaryContainer,
      HomeService.seat => theme.colorScheme.secondaryContainer,
      HomeService.menu => theme.colorScheme.tertiaryContainer,
    };
  }

  Color iconColor(ThemeData theme) {
    final palette = theme.extension<HongikPalette>() ?? HongikPalette.light;
    final dark = theme.brightness == Brightness.dark;
    return switch (this) {
      HomeService.attendance => palette.brandNavy,
      HomeService.seat =>
        dark ? theme.colorScheme.onSecondaryContainer : palette.seatAvailable,
      HomeService.menu =>
        dark ? theme.colorScheme.onTertiaryContainer : AppColor.wowAutumn,
    };
  }

  Color summaryIconColor(ThemeData theme) {
    final palette = theme.extension<HongikPalette>() ?? HongikPalette.light;
    if (this == HomeService.attendance &&
        theme.brightness == Brightness.light) {
      return palette.brandBlue;
    }
    return iconColor(theme);
  }
}

typedef HomeServiceDetailBuilder = Widget Function(
  HomeService service,
  bool isPrimary,
);
typedef HomeServiceSummaryBuilder = HomeServiceSummaryData Function(
  HomeService service,
  WidgetRef ref,
);
