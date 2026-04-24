import 'package:shared_preferences/shared_preferences.dart';

import 'user_dao.dart';

class AppConfig {
  static final AppConfig _instance = AppConfig._internal();

  factory AppConfig() => _instance;

  AppConfig._internal();

  late SharedPreferences _prefs;

  String? savedId;
  String? savedPw;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    if (rememberMe) {
      final dao = UserDao();
      final credentials = await dao.load();
      savedId = credentials.$1;
      savedPw = credentials.$2;
    }
  }

  bool get rememberMe => _prefs.getBool('remember_me') ?? false;

  Future<void> setRememberMe(bool value) async =>
      await _prefs.setBool('remember_me', value);

  bool get autoLogin => _prefs.getBool('auto_login') ?? false;

  Future<void> setAutoLogin(bool value) async =>
      await _prefs.setBool('auto_login', value);

  bool get autoAttendance => _prefs.getBool('auto_attendance') ?? false;

  Future<void> setAutoAttendance(bool value) async =>
      await _prefs.setBool('auto_attendance', value);
}
