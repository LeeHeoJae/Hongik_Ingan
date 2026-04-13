import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:hongik_ingan/core/app.dart';
import 'package:hongik_ingan/core/logger.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> checkUpdate() async {
  try {
    const String gistRawUrl = 'https://cutly.kr/K6vrdl';
    final response = await Dio().get(gistRawUrl);
    final Map<String, dynamic> responseData = response.data is String
        ? jsonDecode(response.data)
        : response.data;
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    final String currentVersion = packageInfo.version;
    final String targetVersion = responseData['latest_version'];
    final String updateLink = responseData['update_url'];
    final String notice = responseData['notice'] ?? '';
    if (currentVersion != targetVersion) {
      logMsg('업데이트가 필요합니다');
      showUpdateDialog(notice, currentVersion, targetVersion, updateLink);
    }
  } catch (e) {
    logMsg('업데이트 확인 실패: $e');
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
      content: Text('현재 버전: $currentVersion\n다음 버전: $targetVersion\n$content'),
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
