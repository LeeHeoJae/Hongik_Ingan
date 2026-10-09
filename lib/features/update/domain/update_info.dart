final class UpdateInfo {
  const UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.updateUrl,
    this.notice = '',
  });

  final String currentVersion;
  final String latestVersion;
  final String updateUrl;
  final String notice;
}
