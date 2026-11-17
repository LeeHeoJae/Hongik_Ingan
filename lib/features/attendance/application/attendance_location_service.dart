import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hongik_ingan/core/logging/logger.dart';

/// 기기 설정을 바꿔야 해결되는 위치 오류. 앱에서만 사용.
class LocationSettingsException implements Exception {
  const LocationSettingsException(this.message, this.openSettings);

  final String message;
  final Future<bool> Function() openSettings;

  @override
  String toString() => message;
}

class AttendanceLocationService {
  const AttendanceLocationService();

  static const locationTimeout = Duration(seconds: 10);
  static const locationPermissionTimeout = Duration(seconds: 30);

  /// 사용자의 현재 위치 좌표를 불러옴.
  Future<Position> getUsersLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled().timeout(
      locationTimeout,
      onTimeout: _throwLocationTimeout,
    );
    if (!serviceEnabled) {
      if (!kIsWeb) {
        throw const LocationSettingsException(
          '위치 서비스가 꺼져 있어요.',
          Geolocator.openLocationSettings,
        );
      }
      throw Exception('위치 서비스가 꺼져 있어요.');
    }

    var permission = await Geolocator.checkPermission().timeout(
      locationTimeout,
      onTimeout: _throwLocationTimeout,
    );
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission().timeout(
        locationPermissionTimeout,
        onTimeout: () => throw Exception(
          kIsWeb
              ? '위치 권한 확인 시간이 초과됐어요. 브라우저 또는 기기에서 위치 권한을 허용한 뒤 다시 시도해 주세요.'
              : '위치 권한 확인 시간이 초과됐어요. 위치 권한을 허용한 뒤 다시 시도해 주세요.',
        ),
      );
    }
    if (permission == LocationPermission.denied) {
      throw Exception('출석 확인을 위해 위치 권한이 필요해요.');
    }
    if (permission == LocationPermission.deniedForever) {
      if (!kIsWeb) {
        throw const LocationSettingsException(
          '위치 권한이 거부돼 있어요. 설정에서 위치 권한을 허용해 주세요.',
          Geolocator.openAppSettings,
        );
      }
      throw Exception('위치 권한이 영구적으로 거부됐어요. 브라우저 또는 기기 설정에서 권한을 허용해 주세요.');
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: locationTimeout,
        ),
      ).timeout(locationTimeout);
      return position;
    } on TimeoutException {
      _throwLocationTimeout();
    } catch (e, stack) {
      logMsg(
        '위치 가져오기 실패: $e',
        level: LogLevel.warning,
        error: e,
        stackTrace: stack,
      );
      throw Exception('위치를 가져오지 못했어요. 기기의 GPS가 켜져 있는지 확인해 주세요.');
    }
  }

  Never _throwLocationTimeout() {
    throw Exception('위치 확인 시간이 초과됐어요. 위치 서비스를 확인한 뒤 다시 시도해 주세요.');
  }
}
