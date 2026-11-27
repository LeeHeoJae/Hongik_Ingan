import 'dart:ui' show PlatformDispatcher;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 앱 바로가기("바로 출석")가 여는 첫 경로.
///
/// Android 앱 아이콘 바로가기는 intent extra `route`로, PWA manifest
/// shortcuts는 `/#/attend` 주소로 이 경로를 넘긴다.
const quickAttendRoute = '/attend';

/// 바로가기 요청을 기다리는 최대 시간.
///
/// 세션 확인, 재로그인, 수업 조회가 이 안에 끝나지 않으면 평소 홈 화면으로 둔다.
/// 나중에 수업이 잡혔을 때 입력창이 갑자기 뜨지 않게 하기 위해서다.
const quickAttendWindow = Duration(seconds: 90);

bool isQuickAttendRoute(String routeName) {
  final uri = Uri.tryParse(routeName);
  return uri != null && uri.path == quickAttendRoute;
}

/// 바로가기로 시작했을 때 출결 번호 입력창을 한 번만 자동으로 열기 위한 요청.
class QuickAttendLaunch {
  QuickAttendLaunch({required bool requested, Stopwatch? stopwatch})
    : _pending = requested,
      _stopwatch = stopwatch ?? (Stopwatch()..start());

  final Stopwatch _stopwatch;
  bool _pending;

  /// 아직 처리하지 않았고 유효 시간 안에 있는 요청인지.
  bool get isPending {
    if (_pending && _stopwatch.elapsed > quickAttendWindow) _pending = false;
    return _pending;
  }

  /// 요청을 처리한다. 처음 한 번만 true를 돌려준다.
  bool consume() {
    final pending = isPending;
    _pending = false;
    return pending;
  }

  /// 사용자가 직접 움직였거나 열 수 있는 수업이 없을 때 요청을 버린다.
  void cancel() => _pending = false;
}

final quickAttendLaunchProvider = Provider<QuickAttendLaunch>(
  (ref) => QuickAttendLaunch(
    requested: isQuickAttendRoute(PlatformDispatcher.instance.defaultRouteName),
  ),
);
