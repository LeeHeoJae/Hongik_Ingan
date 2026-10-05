import 'package:flutter/material.dart';
import 'package:hongik_ingan/core/theme/color.dart';
import 'package:hongik_ingan/features/app_install/domain/app_install_state.dart';
import 'package:hongik_ingan/features/app_install/presentation/app_install_copy.dart';
import 'package:hongik_ingan/features/app_install/presentation/app_install_guide_sheet.dart';

class AppInstallPrompt extends StatelessWidget {
  const AppInstallPrompt({
    super.key,
    required this.target,
    required this.onInstall,
    required this.onDismiss,
    required this.showGuide,
    required this.onShowGuide,
  });

  final AppInstallTarget target;
  final VoidCallback onInstall;
  final VoidCallback onDismiss;
  final bool showGuide;
  final VoidCallback onShowGuide;

  @override
  Widget build(BuildContext context) {
    final palette =
        Theme.of(context).extension<HongikPalette>() ?? HongikPalette.light;
    final description = target.installPromoDescription;
    final actionLabel = target.installActionLabel;

    return Semantics(
      container: true,
      label: '홍익인간 앱 설치 안내. $description',
      child: Material(
        color: palette.cardSurface,
        elevation: 12,
        shadowColor: Colors.black.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: palette.brandNavy.withValues(alpha: 0.22),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              child: showGuide
                  ? AppInstallGuideContent(
                      key: const ValueKey('install-guide'),
                      target: target,
                      onDismiss: onDismiss,
                    )
                  : Column(
                      key: const ValueKey('install-prompt'),
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: palette.brandNavy.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: Icon(
                                Icons.install_mobile_rounded,
                                color: palette.brandNavy,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '홍익인간을 앱으로 설치',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    description,
                                    style: TextStyle(
                                      color: palette.textSecondary,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: '설치 안내 닫기',
                              onPressed: onDismiss,
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final stackActions = constraints.maxWidth < 300;
                            final laterButton = TextButton(
                              onPressed: onDismiss,
                              child: const Text('나중에'),
                            );
                            final installButton = FilledButton.icon(
                              onPressed: target == AppInstallTarget.nativePrompt
                                  ? onInstall
                                  : onShowGuide,
                              icon: const Icon(
                                Icons.install_mobile_rounded,
                                size: 18,
                              ),
                              label: Text(actionLabel),
                            );

                            if (stackActions) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [installButton, laterButton],
                              );
                            }
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                laterButton,
                                const SizedBox(width: 8),
                                installButton,
                              ],
                            );
                          },
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
