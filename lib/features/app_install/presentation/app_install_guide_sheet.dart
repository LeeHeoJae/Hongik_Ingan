import 'package:flutter/material.dart';
import 'package:hongik_ingan/core/theme/color.dart';
import 'package:hongik_ingan/features/app_install/domain/app_install_state.dart';

class AppInstallGuideContent extends StatelessWidget {
  const AppInstallGuideContent({
    super.key,
    required this.target,
    required this.onBack,
    required this.onDismiss,
  });

  final AppInstallTarget target;
  final VoidCallback onBack;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final guide = _guideFor(target);
    final palette =
        Theme.of(context).extension<HongikPalette>() ?? HongikPalette.light;
    final maxContentHeight = (MediaQuery.sizeOf(context).height * 0.36).clamp(
      160.0,
      280.0,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: palette.brandNavy.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(guide.icon, color: palette.brandNavy, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '앱 설치 안내',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    guide.subtitle,
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 13,
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
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxContentHeight),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  guide.introduction,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 14),
                for (var index = 0; index < guide.steps.length; index++) ...[
                  _InstallStep(number: index + 1, text: guide.steps[index]),
                  if (index != guide.steps.length - 1)
                    const SizedBox(height: 10),
                ],
                if (guide.note != null) ...[
                  const SizedBox(height: 14),
                  _InstallNote(text: guide.note!),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text('이전'),
          ),
        ),
      ],
    );
  }
}

class _InstallGuide {
  const _InstallGuide({
    required this.subtitle,
    required this.icon,
    required this.introduction,
    required this.steps,
    this.note,
  });

  final String subtitle;
  final IconData icon;
  final String introduction;
  final List<String> steps;
  final String? note;
}

_InstallGuide _guideFor(AppInstallTarget target) {
  return switch (target) {
    AppInstallTarget.iosManual => const _InstallGuide(
      subtitle: 'iPhone 및 iPad',
      icon: Icons.ios_share_rounded,
      introduction: '현재 브라우저의 공유 메뉴에서 홍익인간을 홈 화면에 추가할 수 있어요.',
      steps: [
        '화면 아래나 주소창에 있는 공유 버튼을 눌러 주세요.',
        '메뉴를 내려서 홈 화면에 추가를 선택해 주세요.',
        '웹 앱으로 열기가 표시되면 켠 뒤 추가를 눌러 주세요.',
      ],
      note: '구형 iOS에서는 웹 앱으로 열기 항목이 표시되지 않을 수 있어요. 이때는 바로 추가를 눌러 주세요.',
    ),
    AppInstallTarget.macSafariManual => const _InstallGuide(
      subtitle: 'Mac용 Safari',
      icon: Icons.desktop_mac_rounded,
      introduction: 'macOS Sonoma 14 이상에서는 홍익인간을 Dock에 앱으로 추가할 수 있어요.',
      steps: ['메뉴 막대에서 파일을 누른 뒤 Dock에 추가를 선택해 주세요.', '앱 이름을 확인하고 추가를 눌러 주세요.'],
      note: '설치한 웹 앱을 처음 열 때 로그인이 다시 필요할 수 있어요.',
    ),
    AppInstallTarget.unsupportedBrowser => const _InstallGuide(
      subtitle: '지원 브라우저 안내',
      icon: Icons.language_rounded,
      introduction: '현재 브라우저에서는 앱 설치 기능을 사용할 수 없어요.',
      steps: [
        'Chrome, Edge 또는 Safari로 홍익인간 웹사이트를 열어 주세요.',
        '설치 아이콘, 브라우저 메뉴 또는 공유 메뉴에서 앱 설치를 선택해 주세요.',
      ],
    ),
    _ => const _InstallGuide(
      subtitle: '브라우저에서 직접 설치',
      icon: Icons.install_desktop_rounded,
      introduction: '브라우저 메뉴에서 홍익인간을 앱이나 홈 화면 바로가기로 추가할 수 있어요.',
      steps: [
        '브라우저 메뉴를 열어 주세요.',
        '앱 설치, 페이지를 앱으로 설치 또는 홈 화면에 추가를 선택해 주세요.',
        '화면에 표시되는 설치 절차를 완료해 주세요.',
      ],
      note: '메뉴 이름과 설치 방식은 브라우저와 기기에 따라 달라질 수 있어요.',
    ),
  };
}

class _InstallStep extends StatelessWidget {
  const _InstallStep({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final palette =
        Theme.of(context).extension<HongikPalette>() ?? HongikPalette.light;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: palette.brandNavy.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Text(
            '$number',
            style: TextStyle(
              color: palette.brandNavy,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(text, style: const TextStyle(height: 1.45)),
          ),
        ),
      ],
    );
  }
}

class _InstallNote extends StatelessWidget {
  const _InstallNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 20,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
