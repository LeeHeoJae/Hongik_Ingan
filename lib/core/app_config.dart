import '../services/preference_service.dart';
import 'user_dao.dart';

class AppConfig {
  static final AppConfig _instance = AppConfig._internal();
  factory AppConfig() => _instance;
  AppConfig._internal();

  String? savedId;
  String? savedPw;
  bool rememberMe = false;
  bool autoLogin = false;
  bool autoAttendance = false;

  Future<void> init() async {
    final prefService = PreferenceService();
    final dao = UserDao();

    final record = prefService.loadSettings();
    rememberMe = record.$1;
    autoLogin = record.$2;
    autoAttendance = record.$3;

    if (rememberMe) {
      final credentials = await dao.load();
      savedId = credentials.$1;
      savedPw = credentials.$2;
    }
  }
}
