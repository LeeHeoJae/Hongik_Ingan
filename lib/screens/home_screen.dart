import 'package:flutter/material.dart';
import 'package:hongik_ingan/core/user_dao.dart';
import 'package:hongik_ingan/screens/attendance_web_screen.dart';
import '../services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final dao = UserDao();
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _pwController = TextEditingController();

  bool _isLoading = false;
  bool _isLoggedIn = false;
  bool _obscurePassword = true; // 비밀번호 숨김 상태 변수
  String _statusMessage = '서비스 이용을 위해 로그인해주세요.';

  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _loadSavedId();

    // 텍스트 변경 감지하여 지우기 버튼 활성화/비활성화를 위해 리스너 추가
    _idController.addListener(() => setState(() {}));
    _pwController.addListener(() => setState(() {}));
  }

  Future<void> _loadSavedId() async {
    final saved = await dao.load();
    if (saved.$1 != null && saved.$2 != null) {
      setState(() {
        _idController.text = saved.$1!;
        _pwController.text = saved.$2!;
      });
    }
  }

  Future<void> _handleLogin() async {
    if (_idController.text.isEmpty || _pwController.text.isEmpty) {
      _showSnackBar('학번과 비밀번호를 모두 입력해주세요.');
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = '홍대 서버와 보안 통신 중...';
    });

    bool success = await _authService.login(
      _idController.text,
      _pwController.text,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (success) {
        _isLoggedIn = true;
        _statusMessage = '로그인 성공! 세션이 활성화되었습니다.';
        dao.save(_idController.text, _pwController.text);
      } else {
        _statusMessage = '로그인 실패. 정보를 확인해주세요.';
        _showSnackBar('로그인 실패: 아이디 또는 비번을 확인하세요.');
      }
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  void dispose() {
    _idController.dispose();
    _pwController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 로고 및 타이틀
                const Icon(
                  Icons.school_rounded,
                  size: 64,
                  color: Color(0xFF05014A),
                ),
                const SizedBox(height: 16),
                const Text(
                  '홍익인간',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF05014A),
                    letterSpacing: -1.2,
                  ),
                ),
                const Text(
                  '전자출결 쾌속 패스',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.blueGrey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 48),

                // 메인 카드 섹션
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: _isLoggedIn ? _buildDashboard() : _buildLoginForm(),
                ),

                const SizedBox(height: 32),
                // 하단 안내
                Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[500], fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 1. 로그인 폼 UI (개선형)
  Widget _buildLoginForm() {
    return Column(
      children: [
        // 학번 입력창
        TextField(
          controller: _idController,
          keyboardType: TextInputType.text,
          decoration: InputDecoration(
            labelText: '학번',
            prefixIcon: const Icon(Icons.badge_outlined),
            suffixIcon: _idController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(
                      Icons.cancel,
                      size: 20,
                      color: Colors.grey,
                    ),
                    onPressed: () => _idController.clear(),
                  )
                : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.black12),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // 비밀번호 입력창
        TextField(
          controller: _pwController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: '클래스넷 비밀번호',
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_pwController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(
                      Icons.cancel,
                      size: 20,
                      color: Colors.grey,
                    ),
                    onPressed: () => _pwController.clear(),
                  ),
                IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ],
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.black12),
            ),
          ),
        ),
        const SizedBox(height: 24),
        // 로그인 버튼
        SizedBox(
          height: 60,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF05014A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    '통합 로그인',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ],
    );
  }

  // 2. 로그인 후 대시보드 UI (개선형)
  Widget _buildDashboard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.face_retouching_natural,
              size: 40,
              color: Color(0xFF05014A),
            ), // Hongik Midnight Blue
          ),
          const SizedBox(height: 16),
          Text(
            '반갑습니다, ${_idController.text}님',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            '현재 출결 세션이 유효합니다.',
            style: TextStyle(color: Color(0xFF22DD79), fontWeight: FontWeight.w600), // Wow Green
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AttendanceWebViewScreen(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF0381FE), // Hongik Azure Blue
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 60),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              '출결 번호 입력하러 가기',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => setState(() => _isLoggedIn = false),
            child: const Text(
              '로그아웃 / 계정 전환',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}
