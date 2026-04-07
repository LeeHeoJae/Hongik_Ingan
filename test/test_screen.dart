import 'package:flutter/material.dart';
import 'package:hongik_ingan/core/user_dao.dart';
import 'package:hongik_ingan/screens/attendance_web_screen.dart';

import 'package:hongik_ingan/services/auth_service.dart';

class TestScreen extends StatefulWidget {
  const TestScreen({super.key});

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  final dao = UserDao();
  late final TextEditingController _idController = TextEditingController();
  late final TextEditingController _pwController = TextEditingController();

  bool _isLoading = false;
  bool _isLoggedIn = false;
  String _statusMessage = '대기 중 ..';
  final AuthService _authService = AuthService();

  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
      _statusMessage = '로그인 진행 중';
    });
    bool success = await _authService.login(
      _idController.text,
      _pwController.text,
    );
    setState(() {
      _isLoading = false;
      _isLoggedIn = true;
      _statusMessage = success ? '로그인 성공' : '로그인 실패';
    });
    if (success) {
      dao.save(_idController.text, _pwController.text);
    }
  }

  Future<void> _loadSavedId() async {
    final saved = await dao.load();
    if (saved.$1 == null || saved.$2 == null) return;
    setState(() {
      _idController.text = saved.$1!;
      _pwController.text = saved.$2!;
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSavedId();
    });
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
      appBar: AppBar(title: const Text('홍익인간 test screen')),
      body: !_isLoggedIn
          ? Column(
              children: [
                TextField(
                  controller: _idController,
                  decoration: const InputDecoration(labelText: '학번'),
                ),
                TextField(
                  obscureText: true,
                  controller: _pwController,
                  decoration: const InputDecoration(labelText: '비번'),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  child: const Text('로그인'),
                ),
                const Divider(height: 40, thickness: 2),
                Text(_statusMessage),
              ],
            )
          : AttendanceWebViewScreen(),
    );
  }
}
