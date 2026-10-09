import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hongik_ingan/core/logging/logger.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'domain/update_info.dart';

Future<UpdateInfo?> checkUpdate({
  Dio? client,
  Future<String> Function()? readCurrentVersion,
}) async {
  final dio =
      client ??
      Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 3),
          receiveTimeout: const Duration(seconds: 4),
        ),
      );
  try {
    String gistRawUrl = 'https://cutly.kr/K6vrdl';
    if (kDebugMode) {
      // 테스트 버전은 기록에 남지 않도록
      gistRawUrl =
          'https://gist.githubusercontent.com/LeeHeoJae/a502eae74c816183f7bd9a3563f51a1d/raw/version.json';
    }
    final response = await dio.get(gistRawUrl);
    final Map<String, dynamic> responseData = response.data is String
        ? jsonDecode(response.data)
        : response.data;
    final currentVersion =
        await (readCurrentVersion?.call() ??
            PackageInfo.fromPlatform().then((info) => info.version));
    final String latestVersion = responseData['latest_version'];
    final String updateUrl = responseData['update_url'];
    final String notice = responseData['notice'] ?? '';

    if (currentVersion != latestVersion) {
      logMsg('업데이트가 필요합니다');
      return UpdateInfo(
        currentVersion: currentVersion,
        latestVersion: latestVersion,
        updateUrl: updateUrl,
        notice: notice,
      );
    }
    return null;
  } catch (e, stack) {
    logMsg(
      '업데이트 확인 실패: $e',
      level: LogLevel.warning,
      error: e is DioException ? e.type : e,
      stackTrace: stack,
    );
    return null;
  } finally {
    if (client == null) dio.close();
  }
}
