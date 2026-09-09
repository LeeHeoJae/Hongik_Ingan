import 'package:package_info_plus/package_info_plus.dart';

class AppInfo {
  static String version = '';

  static void initialize(PackageInfo packageInfo) {
    version = packageInfo.version;
  }
}
