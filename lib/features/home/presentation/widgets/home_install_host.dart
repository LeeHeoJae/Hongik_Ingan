import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:hongik_ingan/core/app_info.dart';
import 'package:hongik_ingan/core/logging/logger.dart';
import 'package:hongik_ingan/core/presentation/widgets/app_animated_switcher.dart';
import 'package:hongik_ingan/features/app_install/application/app_install_controller.dart';
import 'package:hongik_ingan/features/app_install/domain/app_install_state.dart';
import 'package:hongik_ingan/features/app_install/presentation/app_install_copy.dart';
import 'package:hongik_ingan/features/app_install/presentation/app_install_prompt.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_info_dialog.dart';

/// Owns the install prompt and the app-info entry point for this home session.
class HomeInstallHost extends ConsumerStatefulWidget {
  const HomeInstallHost({super.key, required this.builder});

  final Widget Function(
    BuildContext context,
    VoidCallback showAppInfo,
    Widget overlay,
  )
  builder;

  @override
  ConsumerState<HomeInstallHost> createState() => _HomeInstallHostState();
}

class _HomeInstallHostState extends ConsumerState<HomeInstallHost> {
  bool _installPromptDelayElapsed = false;
  bool _installGuideExpanded = false;
  AppInstallTarget? _requestedInstallTarget;
  Timer? _installPromptDelayTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _installPromptDelayTimer = Timer(const Duration(milliseconds: 1200), () {
        if (!mounted) return;
        setState(() => _installPromptDelayElapsed = true);
      });
    });
  }

  @override
  void dispose() {
    _installPromptDelayTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(
    context,
    _showAppInfo,
    _buildInstallOverlay(
      keyboardIsVisible: MediaQuery.viewInsetsOf(context).bottom > 0,
    ),
  );

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _showAppInfo() {
    final container = ProviderScope.containerOf(context, listen: false);
    return showDialog<void>(
      context: context,
      animationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : null,
      builder: (dialogContext) {
        return UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (dialogContext, dialogRef, child) {
              final installState = dialogRef.watch(
                appInstallControllerProvider,
              );
              return AppInfoDialog(
                version: AppInfo.version,
                installLabel: installState.target.installActionLabel,
                installDescription: installState.showInfoAction
                    ? installState.target.installActionDescription
                    : null,
                onInstall: installState.showInfoAction
                    ? () => _handleInfoInstallAction(
                        dialogContext,
                        installState.target,
                      )
                    : null,
                onOpenSource: () => launchUrl(
                  Uri.parse('https://github.com/LeeHeoJae/Hongik_Ingan'),
                  mode: LaunchMode.externalApplication,
                ),
                onShareLogs: kIsWeb ? null : shareLogFile,
              );
            },
          ),
        );
      },
    );
  }

  void _handleInfoInstallAction(
    BuildContext dialogContext,
    AppInstallTarget target,
  ) {
    if (target == AppInstallTarget.nativePrompt) {
      unawaited(_handleNativeInstallAction(dialogContext: dialogContext));
      return;
    }

    Navigator.of(dialogContext).pop();
    _openInstallGuide(target);
  }

  void _openInstallGuide(AppInstallTarget target) {
    setState(() {
      _requestedInstallTarget = target;
      _installGuideExpanded = true;
    });
  }

  void _closeRequestedInstallGuide() {
    _installPromptDelayTimer?.cancel();
    setState(() {
      _requestedInstallTarget = null;
      _installGuideExpanded = false;
      _installPromptDelayElapsed = false;
    });
  }

  Future<void> _handleNativeInstallAction({BuildContext? dialogContext}) async {
    if (ref.read(appInstallControllerProvider).isPrompting) return;
    final result = await ref
        .read(appInstallControllerProvider.notifier)
        .prompt();
    if (!mounted) return;
    if (dialogContext != null && !dialogContext.mounted) return;
    switch (result) {
      case AppInstallPromptResult.accepted:
        _showSnackBar('설치를 시작했어요.');
      case AppInstallPromptResult.error:
        _showSnackBar('설치 창을 열지 못했어요. 설치 방법을 확인해 주세요.');
        _openNativeInstallFallback(dialogContext);
      case AppInstallPromptResult.unavailable:
        _openNativeInstallFallback(dialogContext);
      case AppInstallPromptResult.dismissed:
        break;
    }
  }

  void _openNativeInstallFallback(BuildContext? dialogContext) {
    final installState = ref.read(appInstallControllerProvider);
    if (!installState.showInfoAction) return;
    if (dialogContext != null) {
      if (!dialogContext.mounted) return;
      Navigator.of(dialogContext).pop();
    }
    final target = installState.target == AppInstallTarget.nativePrompt
        ? AppInstallTarget.browserManual
        : installState.target;
    _openInstallGuide(target);
  }

  Widget _buildInstallOverlay({required bool keyboardIsVisible}) {
    return Consumer(
      builder: (context, ref, child) {
        final installState = ref.watch(appInstallControllerProvider);
        final requestedTarget = _requestedInstallTarget;
        final isRequested = requestedTarget != null;
        final showProactivePrompt =
            _installPromptDelayElapsed && installState.showProactivePromo;

        final visible =
            installState.showInfoAction &&
            (isRequested || showProactivePrompt) &&
            (!keyboardIsVisible || isRequested);

        final target = requestedTarget ?? installState.target;
        return AppAnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: !visible
              ? const SizedBox.shrink(key: ValueKey('install-overlay-hidden'))
              : LayoutBuilder(
                  key: const ValueKey('install-overlay-visible'),
                  builder: (context, constraints) {
                    final useCornerPlacement = constraints.maxWidth >= 700;

                    return Align(
                      alignment: useCornerPlacement
                          ? Alignment.bottomRight
                          : Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: useCornerPlacement ? 380 : 520,
                            maxHeight: (constraints.maxHeight - 32).clamp(
                              0.0,
                              double.infinity,
                            ),
                          ),
                          child: AppInstallPrompt(
                            target: target,
                            showGuide: _installGuideExpanded,
                            onInstall: () {
                              unawaited(_handleNativeInstallAction());
                            },
                            onShowGuide: () {
                              setState(() => _installGuideExpanded = true);
                            },
                            onDismiss: () {
                              if (isRequested) {
                                _closeRequestedInstallGuide();
                                return;
                              }
                              setState(() => _installGuideExpanded = false);
                              unawaited(
                                ref
                                    .read(appInstallControllerProvider.notifier)
                                    .dismissPromo(),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
