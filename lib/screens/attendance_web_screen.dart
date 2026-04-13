import 'package:flutter/material.dart';
import 'package:hongik_ingan/core/logger.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../core/network_client.dart';

class AttendanceWebViewScreen extends StatefulWidget {
  const AttendanceWebViewScreen({super.key});

  @override
  State<AttendanceWebViewScreen> createState() =>
      _AttendanceWebViewScreenState();
}

class _AttendanceWebViewScreenState extends State<AttendanceWebViewScreen> {
  late final WebViewController _controller;
  bool _isInitialized = false;

  Future<void> syncCookiesToWebView() async {
    final cookieManager = WebViewCookieManager();
    await cookieManager.clearCookies();

    final jar = NetworkClient().cookieJar;

    final domains = [
      'https://my.hongik.ac.kr',
      'https://ap.hongik.ac.kr',
      'https://at.hongik.ac.kr',
    ];

    for (var domainUri in domains) {
      final cookies = await jar.loadForRequest(Uri.parse(domainUri));
      final host = Uri.parse(domainUri).host;

      for (var cookie in cookies) {
        String targetDomain =
            (cookie.name.startsWith('SUSER') || cookie.name.contains('hongik'))
            ? '.hongik.ac.kr'
            : host;

        await cookieManager.setCookie(
          WebViewCookie(
            name: cookie.name,
            value: cookie.value,
            domain: targetDomain,
            path: '/',
          ),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _initWebView();
    _grantPermission();
  }

  void _grantPermission() {
    Permission.locationWhenInUse.request();
  }

  Future<void> _initWebView() async {
    await syncCookiesToWebView();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36',
      )
      ..clearCache()
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (url.contains('logout')) {
              logMsg('로그아웃 버튼을 누름');
              Navigator.of(context).pop('logout');
            }
          },
          onWebResourceError: (WebResourceError error) {
            logMsg('WebResource 에러: $error');
          },
          onPageFinished: (String url) {
            logMsg('현재 페이지 로드 완료: $url');
          },
        ),
      )
      ..setOnConsoleMessage((JavaScriptConsoleMessage message) {
        logMsg('콘솔 메시지 발생: ${message.message}');
      });
    // ..loadRequest(Uri.parse('https://at.hongik.ac.kr/stud02.jsp'));
    if (_controller.platform is AndroidWebViewController) {
      final androidController =
          _controller.platform as AndroidWebViewController;
      androidController.setOnJavaScriptAlertDialog((
        JavaScriptAlertDialogRequest request,
      ) async {
        if (request.message.contains('SSO') || request.message.contains('오류')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('세션이 만료되어 로그아웃됩니다.'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );

          Navigator.of(context).pop('logout');
          logMsg('SSO 세션 만료');
        }
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('알림'),
            content: Text(request.message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('확인'),
              ),
            ],
          ),
        );
      });
      androidController.setGeolocationPermissionsPromptCallbacks(
        onShowPrompt: (GeolocationPermissionsRequestParams request) async {
          logMsg('gps 권한 요청');
          var status = await Permission.locationWhenInUse.request();
          if (status == .granted) {
            logMsg('gps 권한 부여 성공');
            return const GeolocationPermissionsResponse(
              allow: true,
              retain: true,
            );
          }
          logMsg('gps 권한 부여 실패');
          return const GeolocationPermissionsResponse(
            allow: false,
            retain: false,
          );
        },
      );
    }

    // await _controller.loadFlutterAsset('assets/attendance_test.html');
    await _controller.loadRequest(
      Uri.parse('https://at.hongik.ac.kr/index.jsp'),
      headers: {'Referer': 'https://my.hongik.ac.kr'},
    ); // index.jsp에 바로 접속하면 잘못된 접근으로 인식
    setState(() {
      _isInitialized = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('홍익인간 출결 현황')),
      body: _isInitialized
          ? WebViewWidget(controller: _controller)
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
