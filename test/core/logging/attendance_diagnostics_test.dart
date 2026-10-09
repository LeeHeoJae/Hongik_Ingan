import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/core/logging/logger.dart' as app_log;
import 'package:hongik_ingan/core/network/school_log_interceptor.dart';
import 'package:hongik_ingan/core/network/school_request_options.dart';
import 'package:hongik_ingan/core/network/school_transport.dart';
import 'package:hongik_ingan/features/attendance/data/attendance_service.dart';
import 'package:hongik_ingan/features/attendance/domain/lecture.dart';
import 'package:logger/logger.dart';

void main() {
  late _Printer printer;
  late Logger capture;
  Logger? previous;
  setUp(() {
    previous = app_log.logger;
    printer = _Printer();
    capture = Logger(
      filter: ProductionFilter(),
      level: Level.all,
      printer: printer,
    );
    app_log.logger = capture;
    app_log.enableDetailedLogging(duration: Duration.zero);
    printer.events.clear();
  });
  tearDown(() async {
    app_log.disableDetailedLogging();
    app_log.logger = previous;
    await capture.close();
  });

  test(
    'HTTP 200 with invalid lecture markup flushes diagnostic response',
    () async {
      final result = await AttendanceService(
        _Transport('<html><title>unexpected maintenance page</title></html>'),
      ).getActiveLecture();
      expect(result.status, LectureFetchStatus.failure);
      final logs = printer.events.map((e) => e.message).join('\n');
      expect(logs, contains('unexpected maintenance page'));
      expect(logs, contains('requestId=semantic-test'));
      expect(logs, contains('status=200'));
      expect(printer.events.last.level, Level.error);
    },
  );

  test(
    'HTTP 200 session expiry retains reason and masks hidden inputs',
    () async {
      final result = await AttendanceService(
        _Transport(
          '<h1>통합 로그인</h1><input name="USER_ID" value="private-student">',
        ),
      ).getActiveLecture();
      expect(result.sessionExpired, isTrue);
      final logs = printer.events.map((e) => e.message).join('\n');
      expect(logs, contains('통합 로그인'));
      expect(logs, isNot(contains('private-student')));
      expect(logs, contains('requestId=semantic-test'));
    },
  );

  test(
    'unrecognized submission response is a warning with its recent body',
    () async {
      final service = AttendanceService(
        _Transport('<html>unexpected response</html>'),
      );
      await service.submitAttendance(
        Lecture(
          name: 'test',
          time: 'test',
          attendanceParams: {'course': 'test'},
        ),
        'private-code',
        '37.123',
        '126.123',
      );
      final logs = printer.events.map((e) => e.message).join('\n');
      expect(logs, contains('unexpected response'));
      expect(logs, contains('result=unconfirmed'));
      expect(printer.events.last.level, Level.warning);
      for (final secret in ['private-code', '37.123', '126.123']) {
        expect(logs, isNot(contains(secret)));
      }
    },
  );

  test('submission rejected before HTTP still records its reason', () async {
    await AttendanceService(_Transport('unused')).submitAttendance(
      Lecture(name: 'test', time: 'test', attendanceParams: {}),
      'private-code',
      null,
      null,
    );
    expect(printer.events.single.message, contains('reason=missingParameters'));
    expect(printer.events.single.level, Level.warning);
  });
}

class _Printer extends LogPrinter {
  final events = <LogEvent>[];
  @override
  List<String> log(LogEvent event) {
    events.add(event);
    return [];
  }
}

class _Transport implements SchoolHttpTransport {
  _Transport(this.body);
  final String body;

  Response<T> response<T>(String target) => Response<T>(
    requestOptions: RequestOptions(
      path: target,
      extra: {logRequestIdKey: 'semantic-test'},
    ),
    statusCode: 200,
    data: body as T,
  );

  @override
  Future<Response<T>> get<T>(
    String target, {
    Map<String, dynamic>? queryParameters,
    SchoolRequestOptions options = const SchoolRequestOptions(),
  }) async => response<T>(target);

  @override
  Future<Response<T>> post<T>(
    String target, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    SchoolRequestOptions options = const SchoolRequestOptions(),
  }) async => response<T>(target);
}
