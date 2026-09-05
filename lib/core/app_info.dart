import 'package:package_info_plus/package_info_plus.dart';

class AppInfo {
  static String version = '';
  static String buildNumber = '';

  static void initialize(PackageInfo packageInfo) {
    version = packageInfo.version;
    buildNumber = packageInfo.buildNumber;
  }
}
