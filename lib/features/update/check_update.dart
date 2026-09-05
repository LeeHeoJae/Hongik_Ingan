import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hongik_ingan/core/app.dart';
import 'package:hongik_ingan/core/logging/logger.dart';
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
    final response = await Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 3),
        receiveTimeout: const Duration(seconds: 4),
      ),
    ).get(gistRawUrl);
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
    builder: (context) {
      final colorScheme = Theme.of(context).colorScheme;
      final releaseNotes = content.trim();

      return AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.system_update_rounded,
                color: colorScheme.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('새로운 버전이 있어요')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '더 안정적이고 편리한 홍익인간을 이용해 보세요.',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    _VersionLabel(label: '현재', version: currentVersion),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        color: colorScheme.onSurfaceVariant,
                        size: 18,
                      ),
                    ),
                    _VersionLabel(
                      label: '최신',
                      version: targetVersion,
                      highlighted: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '업데이트 내역',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                releaseNotes.isEmpty ? '더 나은 사용 경험을 위해 개선했어요.' : releaseNotes,
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('나중에'),
          ),
          FilledButton.icon(
            onPressed: () => launchUpdateUrl(updateLink),
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: const Text('업데이트하기'),
          ),
        ],
      );
    },
  );
}

class _VersionLabel extends StatelessWidget {
  const _VersionLabel({
    required this.label,
    required this.version,
    this.highlighted = false,
  });

  final String label;
  final String version;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = highlighted
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: color, fontSize: 12)),
          const SizedBox(height: 2),
          Text(
            'v$version',
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

Future<void> launchUpdateUrl(String url) async {
  final updateUri = Uri.parse(url);
  await launchUrl(updateUri, mode: LaunchMode.externalApplication);
}
