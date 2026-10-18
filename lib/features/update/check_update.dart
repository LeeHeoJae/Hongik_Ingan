import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hongik_ingan/core/logging/logger.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pub_semver/pub_semver.dart';
import 'domain/update_info.dart';
import 'domain/update_check_result.dart';

Future<UpdateCheckResult> checkUpdate({
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
    final updateUri = Uri.tryParse(updateUrl);
    if (currentVersion.trim().isEmpty ||
        latestVersion.trim().isEmpty ||
        updateUri == null ||
        !['https', 'http'].contains(updateUri.scheme) ||
        updateUri.host.isEmpty) {
      throw const FormatException('Invalid update metadata');
    }

    if (_releaseVersion(latestVersion) > _releaseVersion(currentVersion)) {
      logMsg('업데이트가 필요합니다');
      return UpdateCheckResult.available(
        UpdateInfo(
          currentVersion: currentVersion,
          latestVersion: latestVersion,
          updateUrl: updateUrl,
          notice: notice,
        ),
      );
    }
    return const UpdateCheckResult.upToDate();
  } catch (e, stack) {
    logMsg(
      '업데이트 확인 실패: $e',
      level: LogLevel.warning,
      error: e is DioException ? e.type : e,
      stackTrace: stack,
    );
    return const UpdateCheckResult.failed();
  } finally {
    if (client == null) dio.close();
  }
}

Version _releaseVersion(String value) {
  // Older metadata used major.minor; treat its missing patch as zero.
  final normalized = value.trim().replaceFirstMapped(
    RegExp(r'^(\d+\.\d+)(?=[-+]|$)'),
    (match) => '${match[1]}.0',
  );
  final parsed = Version.parse(normalized);
  // PackageInfo.version excludes the platform build number. Compare releases
  // on the same basis, retaining prerelease precedence but ignoring build data.
  return Version(
    parsed.major,
    parsed.minor,
    parsed.patch,
    pre: parsed.preRelease.isEmpty ? null : parsed.preRelease.join('.'),
  );
}
