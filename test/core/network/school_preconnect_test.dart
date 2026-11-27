import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/core/network/school_preconnect.dart';

/// 로컬 HTTP 서버로 미리 연 연결이 실제 요청에 쓰이는지,
/// 그리고 서버가 받는 요청 수가 늘지 않는지 확인한다.
void main() {
  late HttpServer server;
  late Uri origin;
  late List<int> requestPorts;
  late List<String> logs;
  late List<int> openedPorts;

  SchoolPreconnector create({Duration maxAge = const Duration(seconds: 5)}) {
    return SchoolPreconnector(
      maxAge: maxAge,
      log: logs.add,
      open: (uri, proxyHost, proxyPort) async {
        final task = await openSchoolSocket(uri, proxyHost, proxyPort);
        return ConnectionTask.fromSocket(
          task.socket.then((socket) {
            openedPorts.add(socket.port);
            return socket;
          }),
          task.cancel,
        );
      },
    );
  }

  HttpClient clientFor(SchoolPreconnector preconnector) {
    final client = HttpClient()..connectionFactory = preconnector.connect;
    addTearDown(() => client.close(force: true));
    return client;
  }

  Future<String> fetch(HttpClient client, String path) async {
    final request = await client.getUrl(origin.resolve(path));
    final response = await request.close();
    return response.transform(const SystemEncoding().decoder).join();
  }

  setUp(() async {
    requestPorts = [];
    logs = [];
    openedPorts = [];
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    origin = Uri.parse('http://127.0.0.1:${server.port}/');
    server.listen((request) {
      requestPorts.add(request.connectionInfo!.remotePort);
      request.response
        ..write('ok ${request.uri.path}')
        ..close();
    });
  });

  tearDown(() => server.close(force: true));

  test('미리 연 연결로 첫 요청을 보내고 요청 수는 늘지 않는다', () async {
    final preconnector = create();
    addTearDown(preconnector.close);
    preconnector.preconnect(origin);
    await _until(() => logs.any((l) => l.contains('preconnect ready')));
    expect(requestPorts, isEmpty, reason: '미리 연결할 때 HTTP 요청을 보내면 안 된다');

    final body = await fetch(clientFor(preconnector), '/index.jsp');

    expect(body, 'ok /index.jsp');
    expect(requestPorts, hasLength(1));
    expect(openedPorts, hasLength(1));
    expect(requestPorts.single, openedPorts.single);
    expect(logs.last, contains('preconnect used'));
  });

  test('핸드셰이크 중에 요청이 오면 그 연결을 기다려서 쓴다', () async {
    final preconnector = create();
    addTearDown(preconnector.close);
    preconnector.preconnect(origin);

    final body = await fetch(clientFor(preconnector), '/index.jsp');

    expect(body, 'ok /index.jsp');
    expect(openedPorts, hasLength(1));
    expect(requestPorts, [openedPorts.single]);
  });

  test('미리 연 연결은 한 번만 넘기고 그다음 연결은 새로 연다', () async {
    final preconnector = create();
    addTearDown(preconnector.close);
    preconnector.preconnect(origin);
    final client = clientFor(preconnector)..maxConnectionsPerHost = 2;

    final first = client.getUrl(origin.resolve('/a'));
    final second = client.getUrl(origin.resolve('/b'));
    final responses = await Future.wait([
      (await first).close(),
      (await second).close(),
    ]);
    for (final response in responses) {
      await response.drain<void>();
    }

    expect(openedPorts, hasLength(2));
    expect(requestPorts, hasLength(2));
    expect(requestPorts.toSet(), openedPorts.toSet());
  });

  test('오래된 연결은 닫고 새로 연결한다', () async {
    final preconnector = create(maxAge: const Duration(milliseconds: 50));
    addTearDown(preconnector.close);
    preconnector.preconnect(origin);
    await _until(() => logs.any((l) => l.contains('preconnect unused')));

    final body = await fetch(clientFor(preconnector), '/index.jsp');

    expect(body, 'ok /index.jsp');
    expect(openedPorts, hasLength(2));
    expect(requestPorts, [openedPorts.last]);
  });

  test('미리 연결이 실패해도 요청은 평소대로 새로 연결한다', () async {
    var attempts = 0;
    final preconnector = SchoolPreconnector(
      log: logs.add,
      open: (uri, proxyHost, proxyPort) {
        attempts++;
        if (attempts == 1) {
          return Future.value(
            ConnectionTask.fromSocket(
              Future<Socket>.delayed(
                Duration.zero,
                () => throw const SocketException('refused'),
              ),
              () {},
            ),
          );
        }
        return openSchoolSocket(uri, proxyHost, proxyPort);
      },
    );
    addTearDown(preconnector.close);
    preconnector.preconnect(origin);

    final body = await fetch(clientFor(preconnector), '/index.jsp');

    expect(body, 'ok /index.jsp');
    expect(attempts, 2);
    expect(requestPorts, hasLength(1));
  });

  test('다른 서버나 프록시 연결에는 미리 연 연결을 쓰지 않는다', () async {
    final opened = <(Uri, String?)>[];
    final preconnector = SchoolPreconnector(
      log: logs.add,
      open: (uri, proxyHost, proxyPort) {
        opened.add((uri, proxyHost));
        return Future.value(
          ConnectionTask.fromSocket(Completer<Socket>().future, () {}),
        );
      },
    );
    addTearDown(preconnector.close);
    preconnector.preconnect(attendanceOrigin);

    unawaited(
      preconnector.connect(Uri.parse('https://my.hongik.ac.kr/x'), null, null),
    );
    unawaited(
      preconnector.connect(
        Uri.parse('https://at.hongik.ac.kr/index.jsp'),
        'proxy.local',
        8080,
      ),
    );

    expect(opened, hasLength(3));
    expect(opened[1].$1.host, 'my.hongik.ac.kr');
    expect(opened[2].$2, 'proxy.local');
  });
}

Future<void> _until(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('condition not met in time');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}
