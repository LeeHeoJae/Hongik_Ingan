import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hongik_ingan/core/app.dart';
import 'package:hongik_ingan/core/logger.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

Future<Map<String, String>?> checkUpdate() async {
  try {
    String gistRawUrl = 'https://cutly.kr/K6vrdl';
    if (kDebugMode) {
      // 테스트 버전은 기록에 남지 않도록
      gistRawUrl =
          'https://gist.githubusercontent.com/LeeHeoJae/a502eae74c816183f7bd9a3563f51a1d/raw/version.json';
    }
    final response = await Dio().get(gistRawUrl);
    final Map<String, dynamic> responseData = response.data is String
        ? jsonDecode(response.data)
        : response.data;
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    final String currentVersion = packageInfo.version;
    final String latestVersion = responseData['latest_version'];
    final String updateUrl = responseData['update_url'];
    final String notice = responseData['notice'] ?? '';

    if (currentVersion != latestVersion) {
      logMsg('업데이트가 필요합니다');
      return {
        'currentVersion': currentVersion,
        'latestVersion': latestVersion,
        'updateUrl': updateUrl,
        'notice': notice,
      };
    }
    return null;
  } catch (e) {
    logMsg('업데이트 확인 실패: $e');
    return null;
  }
}

void showUpdateDialog(
  String content,
  String currentVersion,
  String targetVersion,
  String updateLink,
) {
  final context = navigatorKey.currentContext;
  if (context == null) return;
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('업데이트 알림'),
      content: Text(
        '현재 버전: $currentVersion\n다음 버전: $targetVersion\n업데이트 내역:\n[$content]',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('나중에'),
        ),
        TextButton(
          onPressed: () => launchUpdateUrl(updateLink),
          child: const Text('업데이트하기'),
        ),
      ],
    ),
  );
}

Future<void> launchUpdateUrl(String url) async {
  final updateUri = Uri.parse(url);
  await launchUrl(updateUri, mode: LaunchMode.externalApplication);
}
