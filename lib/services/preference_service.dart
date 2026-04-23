import 'package:shared_preferences/shared_preferences.dart';

class PreferenceService {
  static const String _keyRememberMe = 'remember_me';
  static const String _keyAutoLogin = 'auto_login';
  static const String _keyAutoAttendance = 'auto_attendance';

  static SharedPreferences? prefs;

  static Future<void> init() async =>
      prefs ??= await SharedPreferences.getInstance();

  SharedPreferences get _p {
    assert(prefs != null, 'PreferenceService.init()을 먼저 실행하시오');
    return prefs!;
  }

  Future<void> setRememberMe(bool value) async =>
      await _p.setBool(_keyRememberMe, value);

  Future<void> setAutoLogin(bool value) async =>
      await _p.setBool(_keyAutoLogin, value);

  Future<void> setAutoAttendance(bool value) async =>
      await _p.setBool(_keyAutoAttendance, value);

  (bool, bool, bool) loadSettings() {
    return (
      _p.getBool(_keyRememberMe) ?? false,
      _p.getBool(_keyAutoLogin) ?? false,
      _p.getBool(_keyAutoAttendance) ?? false,
    );
  }
}
