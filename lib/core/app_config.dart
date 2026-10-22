import 'package:shared_preferences/shared_preferences.dart';

import 'user_dao.dart';

class AppConfig {
  static final AppConfig _instance = AppConfig._internal();

  factory AppConfig({
    Future<SharedPreferences> Function()? loadPreferences,
    UserDao? userDao,
  }) {
    if (loadPreferences == null && userDao == null) return _instance;
    return AppConfig._internal(
      loadPreferences: loadPreferences,
      userDao: userDao,
    );
  }

  AppConfig._internal({
    Future<SharedPreferences> Function()? loadPreferences,
    UserDao? userDao,
  }) : _loadPreferences = loadPreferences ?? SharedPreferences.getInstance,
       _userDao = userDao ?? UserDao();

  final Future<SharedPreferences> Function() _loadPreferences;
  final UserDao _userDao;
  SharedPreferences? _prefs;
  Future<void>? _initFuture;
  bool _rememberMe = false;
  bool _autoLogin = false;

  String? savedId;
  String? savedPw;

  bool get isInitialized => _prefs != null;

  Future<void> init() =>
      _initFuture ??= _init().onError<Object>((error, stack) {
        _initFuture = null;
        Error.throwWithStackTrace(error, stack);
      });

  void clearSavedCredentials() {
    savedId = null;
    savedPw = null;
  }

  Future<void> _init() async {
    final prefs = await _loadPreferences();
    final rememberMe = prefs.getBool('remember_me') ?? false;
    final autoLogin = prefs.getBool('auto_login') ?? false;
    final credentials = rememberMe ? await _userDao.load() : (null, null);
    _rememberMe = rememberMe;
    _autoLogin = autoLogin;
    savedId = credentials.$1;
    savedPw = credentials.$2;
    _prefs = prefs;
  }

  // SharedPreferences updates its cache before the storage write completes.
  // Expose only values whose initialization or write has succeeded.
  bool get rememberMe => _rememberMe;

  Future<void> setRememberMe(bool value) async {
    await _setBool('remember_me', value);
    _rememberMe = value;
  }

  bool get autoLogin => _autoLogin;

  Future<void> setAutoLogin(bool value) async {
    await _setBool('auto_login', value);
    _autoLogin = value;
  }

  Future<void> _setBool(String key, bool value) async {
    await init();
    if (!await _prefs!.setBool(key, value)) {
      throw StateError('Login settings could not be saved.');
    }
  }
}
