import 'package:shared_preferences/shared_preferences.dart';

class PreferenceService {
  static const String _keyRememberMe = 'remember_me';
  static const String _keyAutoLogin = 'auto_login';
  static const String _keyAutoAttendance = 'auto_attendance';

  Future<void> setRememberMe(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyRememberMe, value);
  }

  Future<void> setAutoLogin(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoLogin, value);
  }

  Future<void> setAutoAttendance(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoAttendance, value);
  }

  Future<(bool, bool, bool)> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      prefs.getBool(_keyRememberMe) ?? false,
      prefs.getBool(_keyAutoLogin) ?? false,
      prefs.getBool(_keyAutoAttendance) ?? false,
    );
  }
}
