import 'dart:async';
import 'dart:io';

import '../logging/logger.dart';

/// 출결 서버. 앱을 켜면 첫 학교 요청(세션 확인)이 가는 곳이다.
final Uri attendanceOrigin = Uri.parse('https://at.hongik.ac.kr/');

typedef SchoolSocketOpener = Future<ConnectionTask<Socket>> Function(
  Uri uri,
  String? proxyHost,
  int? proxyPort,
);

/// 학교 서버와의 TCP/TLS 연결을 미리 열어 두었다가, [HttpClient]가 그 서버로
/// 새 연결이 필요할 때 넘겨준다.
///
/// 미리 하는 일은 DNS 조회, TCP 연결, TLS 핸드셰이크뿐이고 HTTP 요청은 한 바이트도
/// 보내지 않는다. 그래서 학교 서버가 받는 요청의 순서, 개수, 내용(쿠키 포함)은
/// 이 클래스가 있든 없든 같다. 요청 직렬화(SchoolTransportNative)와도 무관하다.
///
/// 미리 연 연결은 한 번만 넘겨주고, [maxAge]가 지나도록 쓰이지 않으면 닫는다.
/// 오래 놀던 연결은 서버가 먼저 끊었을 수 있어서 넘기지 않는다.
final class SchoolPreconnector {
  SchoolPreconnector({
    this._open = openSchoolSocket,
    this.maxAge = const Duration(seconds: 5),
    void Function(String message)? log,
  }) : _log = log ?? _defaultLog;

  final SchoolSocketOpener _open;
  final void Function(String message) _log;

  /// 미리 연 연결을 넘겨줄 수 있는 최대 시간(연결 완료 시점부터).
  final Duration maxAge;

  final Map<String, _Preconnection> _pending = {};

  /// [origin] 서버로 연결을 하나 미리 열기 시작한다. 이미 열고 있으면 무시한다.
  void preconnect(Uri origin) {
    final key = _keyOf(origin);
    if (_pending.containsKey(key)) return;

    final Future<ConnectionTask<Socket>> task;
    try {
      task = _open(origin, null, null);
    } catch (error) {
      _log('school preconnect failed host=${origin.host} error=$error');
      return;
    }
    final preconnection = _Preconnection(task);
    _pending[key] = preconnection;
    preconnection.socket.then(
      (_) {
        preconnection.markConnected(maxAge, () {
          if (_pending[key] == preconnection) _pending.remove(key);
          _log(
            'school preconnect unused host=${origin.host} '
            'closedAfterMs=${maxAge.inMilliseconds}',
          );
        });
        _log(
          'school preconnect ready host=${origin.host} '
          'connectMs=${preconnection.connectMs}',
        );
      },
      onError: (Object error) {
        if (_pending[key] == preconnection) _pending.remove(key);
        _log(
          'school preconnect failed host=${origin.host} '
          'afterMs=${preconnection.elapsedMs} errorType=${error.runtimeType}',
        );
      },
    );
  }

  /// [HttpClient.connectionFactory]에 넣는 함수.
  ///
  /// 미리 열어 둔 연결이 있으면 그것을, 없으면 [HttpClient] 기본 동작과 같은
  /// 새 연결을 돌려준다.
  Future<ConnectionTask<Socket>> connect(
    Uri uri,
    String? proxyHost,
    int? proxyPort,
  ) {
    if (proxyHost == null) {
      final preconnection = _pending.remove(_keyOf(uri));
      if (preconnection != null) {
        final handover = _handOver(preconnection, uri);
        if (handover != null) return handover;
      }
    }
    return _open(uri, proxyHost, proxyPort);
  }

  /// 아직 넘기지 않은 연결을 모두 닫는다.
  void close() {
    for (final preconnection in _pending.values) {
      preconnection.discard();
    }
    _pending.clear();
  }

  Future<ConnectionTask<Socket>>? _handOver(_Preconnection p, Uri uri) {
    if (p.isConnected) {
      if (p.ageSinceConnected > maxAge) {
        p.discard();
        return null;
      }
      p.claim();
      _log(
        'school preconnect used host=${uri.host} '
        'connectMs=${p.connectMs} waitedMs=0',
      );
      return Future.value(ConnectionTask.fromSocket(p.socket, p.discard));
    }

    // 아직 핸드셰이크 중이면 그 연결을 기다린다. 실패하면 새로 연결한다.
    p.claim();
    final requestedAt = Stopwatch()..start();
    ConnectionTask<Socket>? fallback;
    var cancelled = false;
    final socket = p.socket.then<Socket>(
      (socket) {
        _log(
          'school preconnect used host=${uri.host} '
          'connectMs=${p.connectMs} waitedMs=${requestedAt.elapsedMilliseconds}',
        );
        return socket;
      },
      onError: (Object _) async {
        if (cancelled) throw const SocketException('Connection cancelled');
        final task = await _open(uri, null, null);
        fallback = task;
        if (cancelled) task.cancel();
        return task.socket;
      },
    );
    return Future.value(
      ConnectionTask.fromSocket(socket, () {
        cancelled = true;
        p.discard();
        fallback?.cancel();
      }),
    );
  }

  static String _keyOf(Uri uri) => '${uri.scheme}://${uri.host}:${uri.port}';

  static void _defaultLog(String message) =>
      logMsg(message, level: LogLevel.info);
}

/// [HttpClient]가 connectionFactory 없이 여는 것과 같은 방식으로 연결한다.
Future<ConnectionTask<Socket>> openSchoolSocket(
  Uri uri,
  String? proxyHost,
  int? proxyPort,
) {
  if (proxyHost != null) {
    return Socket.startConnect(proxyHost, proxyPort!);
  }
  if (uri.isScheme('https')) {
    return SecureSocket.startConnect(uri.host, uri.port);
  }
  return Socket.startConnect(uri.host, uri.port);
}

final class _Preconnection {
  _Preconnection(this._task) {
    socket = _task.then((task) => task.socket).then((socket) {
      _connectMs = _clock.elapsedMilliseconds;
      if (_discarded) {
        socket.destroy();
        throw const SocketException('Preconnection discarded');
      }
      return socket;
    });
    // 아무도 기다리지 않을 때 실패가 처리되지 않은 오류로 남지 않게 한다.
    socket.ignore();
  }

  final Future<ConnectionTask<Socket>> _task;
  final Stopwatch _clock = Stopwatch()..start();
  late final Future<Socket> socket;
  int? _connectMs;
  Timer? _expiry;
  bool _claimed = false;
  bool _discarded = false;

  bool get isConnected => _connectMs != null;
  int? get connectMs => _connectMs;
  int get elapsedMs => _clock.elapsedMilliseconds;
  Duration get ageSinceConnected =>
      Duration(milliseconds: _clock.elapsedMilliseconds - (_connectMs ?? 0));

  void markConnected(Duration maxAge, void Function() onExpired) {
    if (_claimed || _discarded) return;
    _expiry = Timer(maxAge, () {
      if (_claimed || _discarded) return;
      discard();
      onExpired();
    });
  }

  /// [HttpClient]에 넘겼으므로 더는 이쪽에서 닫지 않는다.
  void claim() {
    _claimed = true;
    _expiry?.cancel();
  }

  void discard() {
    if (_discarded) return;
    _discarded = true;
    _expiry?.cancel();
    _task.then((task) => task.cancel(), onError: (Object _) {});
    if (isConnected) {
      socket.then((socket) => socket.destroy(), onError: (Object _) {});
    }
  }
}
