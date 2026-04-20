import 'package:flutter/material.dart';
import 'package:hongik_ingan/core/theme/color.dart';
import 'package:hongik_ingan/core/user_dao.dart';
import 'package:hongik_ingan/screens/attendance_web_screen.dart';
import 'package:hongik_ingan/services/check_update.dart';
import 'package:hongik_ingan/services/preference_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../services/auth_service.dart';
import 'widgets/dashboard.dart';
import 'widgets/login_form.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final dao = UserDao();
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _pwController = TextEditingController();

  bool _isLoading = false;
  bool _isLoggedIn = false;
  String _statusMessage = '서비스 이용을 위해 로그인해주세요.';

  bool _rememberMe = false;
  bool _autoLogin = false;
  bool _autoAttendance = false;

  final AuthService _authService = AuthService();
  final PreferenceService _prefService = PreferenceService();

  String _version = '';
  Map<String, String>? _updateInfo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _idController.dispose();
    _pwController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      if (_isLoggedIn) {
        _checkSessionValidityAndReact();
      }
    }
  }

  Future<void> _initializeApp() async {
    final updateInfo = await checkUpdate();
    final (rememberMe, autoLogin, autoAttendance) = await _prefService
        .loadSettings();
    final packageInfo = await PackageInfo.fromPlatform();

    if (!mounted) return;

    setState(() {
      _version = packageInfo.version;
      _updateInfo = updateInfo;
      _rememberMe = rememberMe;
      _autoLogin = autoLogin;
      _autoAttendance = autoAttendance;
    });
    await _loadSavedId();
    await _checkSessionValidityAndReact();
  }

  Future<void> _checkSessionValidityAndReact() async {
    final isSessionValid = await _authService.isSessionValid();
    if (isSessionValid) {
      if (!mounted) return;
      setState(() {
        _isLoggedIn = true;
        _statusMessage = '자동 로그인 되었습니다.';
      });
      if (_autoAttendance) {
        moveToAttendanceScreen();
      }
      return;
    }
    if (_rememberMe && _autoLogin) {
      _handleLogin(isAutoLogin: true);
    } else {
      setState(() {
        _isLoggedIn = false;
        _statusMessage = '세션이 만료되어 로그아웃되었습니다.';
      });
    }
  }

  Future<void> _loadSavedId() async {
    final saved = await dao.load();
    if (saved.$1 != null && saved.$2 != null) {
      if (!mounted) return;
      setState(() {
        _idController.text = saved.$1!;
        _pwController.text = saved.$2!;
      });
    }
  }

  Future<void> _handleLogin({bool isAutoLogin = false}) async {
    if (_idController.text.isEmpty || _pwController.text.isEmpty) {
      _showSnackBar('학번과 비밀번호를 모두 입력해주세요.');
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = '홍대 서버와 보안 통신 중...';
    });

    String success = await _authService.login(
      _idController.text,
      _pwController.text,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (success == 'success') {
        _isLoggedIn = true;
        _statusMessage = isAutoLogin
            ? '자동 로그인 되었습니다.'
            : '로그인 성공! 세션이 활성화되었습니다.';
        if (_rememberMe) {
          dao.save(_idController.text, _pwController.text);
        }
      } else {
        _isLoggedIn = false;
        _statusMessage = '로그인 실패. 정보를 확인해주세요.\n$success';
        _showSnackBar('로그인 실패: 아이디 또는 비번을 확인하세요.');
      }
    });
    if (success == 'success' && _autoAttendance) {
      moveToAttendanceScreen();
    }
  }

  void moveToAttendanceScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AttendanceWebViewScreen()),
    ).then((result) {
      if (result == 'logout') {
        if (!mounted) return;
        setState(() {
          _isLoggedIn = false;
          _statusMessage = '로그아웃 되었습니다.';
        });
        if (_autoLogin) {
          _handleLogin(isAutoLogin: true);
        }
      }
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: .floating,
        shape: RoundedRectangleBorder(borderRadius: .circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const .symmetric(horizontal: 28.0),
            child: Column(
              mainAxisAlignment: .center,
              crossAxisAlignment: .stretch,
              children: [
                Icon(
                  Icons.school_rounded,
                  size: 64,
                  color: colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  '홍익인간',
                  textAlign: .center,
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: .w900,
                    color: colorScheme.onSurface,
                    letterSpacing: -1.2,
                  ),
                ),
                Text(
                  '전자출결 쾌속 패스',
                  textAlign: .center,
                  style: TextStyle(
                    fontSize: 15,
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                    fontWeight: .w500,
                  ),
                ),
                const SizedBox(height: 48),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: _isLoggedIn
                      ? Dashboard(
                          userId: _idController.text,
                          onMoveToAttendance: moveToAttendanceScreen,
                          onLogout: () {
                            setState(() {
                              _isLoggedIn = false;
                              _statusMessage = '로그아웃 되었습니다.';
                            });
                          },
                        )
                      : LoginForm(
                          idController: _idController,
                          pwController: _pwController,
                          isLoading: _isLoading,
                          rememberMe: _rememberMe,
                          autoLogin: _autoLogin,
                          autoAttendance: _autoAttendance,
                          onRememberMeChanged: (val) {
                            setState(() {
                              _rememberMe = val;
                              if (!_rememberMe) _autoLogin = false;
                            });
                            _prefService.setRememberMe(_rememberMe);
                            _prefService.setAutoLogin(_autoLogin);
                          },
                          onAutoLoginChanged: (val) {
                            setState(() {
                              _autoLogin = val;
                              if (_autoLogin) _rememberMe = true;
                            });
                            _prefService.setRememberMe(_rememberMe);
                            _prefService.setAutoLogin(_autoLogin);
                          },
                          onAutoAttendanceChanged: (val) {
                            setState(() {
                              _autoAttendance = val;
                            });
                            _prefService.setAutoAttendance(_autoAttendance);
                          },
                          onLogin: () => _handleLogin(),
                        ),
                ),
                const SizedBox(height: 32),
                Text(
                  _statusMessage,
                  textAlign: .center,
                  style: TextStyle(
                    color: colorScheme.onSurface.withValues(alpha: 0.4),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
