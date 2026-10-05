import 'package:flutter/material.dart';
import 'package:hongik_ingan/features/app_install/domain/app_install_state.dart';

extension AppInstallTargetCopy on AppInstallTarget {
  String get installActionLabel =>
      this == AppInstallTarget.nativePrompt ? '앱 설치' : '설치 방법 보기';

  String get installActionDescription => this == AppInstallTarget.nativePrompt
      ? '이 브라우저에서 바로 설치할 수 있어요.'
      : installGuide.actionDescription;

  String get installPromoDescription => this == AppInstallTarget.nativePrompt
      ? '기기에서 앱처럼 바로 열 수 있어요.'
      : installGuide.promoDescription;

  AppInstallGuideCopy get installGuide => switch (this) {
    AppInstallTarget.iosManual => const AppInstallGuideCopy(
      subtitle: 'iPhone 및 iPad',
      icon: Icons.ios_share_rounded,
      actionDescription: '공유 메뉴에서 홈 화면에 추가하는 방법을 확인해요.',
      promoDescription: '홈 화면에서 바로 열 수 있어요.',
      introduction: '현재 브라우저의 공유 메뉴에서 홍익인간을 홈 화면에 추가해 주세요.',
      steps: [
        '화면 아래나 주소창에 있는 공유 버튼을 눌러 주세요.',
        '메뉴에서 홈 화면에 추가를 선택해 주세요.',
        '웹 앱으로 열기가 표시되면 켠 뒤 추가를 눌러 주세요.',
      ],
    ),
    AppInstallTarget.macSafariManual => const AppInstallGuideCopy(
      subtitle: 'Mac용 Safari',
      icon: Icons.desktop_mac_rounded,
      actionDescription: 'Safari에서 Dock에 추가하는 방법을 확인해요.',
      promoDescription: 'Dock에서 바로 열 수 있어요.',
      introduction: '메뉴 막대에서 파일 → Dock에 추가를 선택한 뒤 추가를 눌러 주세요.',
      note: 'Dock에 추가 메뉴가 없다면 Chrome이나 Edge의 설치 메뉴를 확인해 주세요.',
    ),
    AppInstallTarget.windowsFirefoxManual => const AppInstallGuideCopy(
      subtitle: 'Firefox에서 설치',
      icon: Icons.install_desktop_rounded,
      actionDescription: '주소창에서 앱으로 추가하는 방법을 확인해요.',
      promoDescription: '작업 표시줄에서 바로 열 수 있어요.',
      introduction: '주소창 오른쪽의 웹 앱 버튼을 눌러 홍익인간을 앱으로 추가해 주세요.',
    ),
    AppInstallTarget.androidManual => const AppInstallGuideCopy(
      subtitle: 'Android에서 설치',
      icon: Icons.install_mobile_rounded,
      actionDescription: '브라우저 메뉴에서 홈 화면에 추가하는 방법을 확인해요.',
      promoDescription: '홈 화면에서 바로 열 수 있어요.',
      introduction: '브라우저 메뉴에서 앱 설치 또는 홈 화면에 추가를 선택해 주세요.',
      note: '메뉴 이름은 브라우저에 따라 달라질 수 있어요.',
    ),
    AppInstallTarget.nativePrompt ||
    AppInstallTarget.browserManual => const AppInstallGuideCopy(
      subtitle: '브라우저에서 직접 설치',
      icon: Icons.install_desktop_rounded,
      actionDescription: '주소창이나 브라우저 메뉴에서 설치하는 방법을 확인해요.',
      promoDescription: '기기에서 앱처럼 바로 열 수 있어요.',
      introduction: '주소창의 설치 아이콘이나 브라우저 메뉴의 앱 설치를 선택해 주세요.',
      note: '메뉴 이름은 앱 설치 또는 페이지를 앱으로 설치처럼 다르게 표시될 수 있어요.',
    ),
    _ => const AppInstallGuideCopy(
      subtitle: '브라우저 설치 메뉴 확인',
      icon: Icons.language_rounded,
      actionDescription: '현재 브라우저의 설치 메뉴를 확인하는 방법을 안내해요.',
      promoDescription: '현재 브라우저의 설치 방법을 확인해 주세요.',
      introduction: '주소창이나 브라우저 메뉴에 앱 설치 또는 홈 화면에 추가가 있는지 확인해 주세요.',
      note:
          '설치 메뉴가 없다면 Chrome이나 Edge에서 열어 주세요. Mac에서는 Safari의 Dock에 추가도 사용할 수 있어요.',
    ),
  };
}

class AppInstallGuideCopy {
  const AppInstallGuideCopy({
    required this.subtitle,
    required this.icon,
    required this.actionDescription,
    required this.promoDescription,
    required this.introduction,
    this.steps = const [],
    this.note,
  });

  final String subtitle;
  final IconData icon;
  final String actionDescription;
  final String promoDescription;
  final String introduction;
  final List<String> steps;
  final String? note;
}
