import 'package:flutter/material.dart';
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
          onPageFinished: (String url) {
            print('현재 페이지 로드 완료: $url');
          },
        ),
      )
      ..setOnConsoleMessage((JavaScriptConsoleMessage message) {
        printLog('콘솔 메시지 발생: ${message.message}');
      });
    // ..loadRequest(Uri.parse('https://at.hongik.ac.kr/stud02.jsp'));
    if (_controller.platform is AndroidWebViewController) {
      final androidController = _controller
          .platform as AndroidWebViewController;
      androidController.setGeolocationPermissionsPromptCallbacks(
          onShowPrompt: (GeolocationPermissionsRequestParams request) async {
            print('gps 권한 요청');
        var status = await Permission.locationWhenInUse.request();
            if (status == .granted) {
              print('gps 권한 부여 성공');
              return const GeolocationPermissionsResponse(
                  allow: true, retain: true);
        }
            print('gps 권한 부여 실패');
            return const GeolocationPermissionsResponse(
                allow: false, retain: false);
      });
    // ..loadRequest(Uri.parse('https://at.hongik.ac.kr/stud02.jsp'));

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
