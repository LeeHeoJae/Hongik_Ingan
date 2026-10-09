import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/core/logging/log_diagnostics.dart';
import 'package:hongik_ingan/core/logging/logger.dart' as app_log;
import 'package:logger/logger.dart';

void main() {
  test('warnings flush recent details once with original timestamps', () {
    final records = <DiagnosticLogRecord>[];
    final now = DateTime(2026, 10, 9);
    final buffer = DiagnosticLogBuffer(emit: records.add, now: () => now);
    buffer.add('stage=login', LogLevel.debug);
    buffer.add('request completed', LogLevel.info);
    expect(records.map((e) => e.message), ['request completed']);
    buffer.add('session expired', LogLevel.warning);
    expect(records[1].message, contains('context at=${now.toIso8601String()}'));
    expect(records[1].message, contains('stage=login'));
    buffer.add('retry failed', LogLevel.error);
    expect(
      records.where((e) => e.message.contains('stage=login')),
      hasLength(1),
    );
  });

  test('buffer evicts oldest records by count and reports loss', () {
    final records = <DiagnosticLogRecord>[];
    final buffer = DiagnosticLogBuffer(emit: records.add, maxEvents: 2);
    for (var i = 0; i < 4; i++) {
      buffer.add('event=$i', LogLevel.debug);
    }
    buffer.flush();
    expect(records.first.message, 'diagnostics omittedEvents=2');
    expect(records.map((e) => e.message).join(), isNot(contains('event=1')));
    expect(records.last.message, contains('event=3'));
  });

  test('buffer also limits total UTF-8 bytes', () {
    final records = <DiagnosticLogRecord>[];
    final buffer = DiagnosticLogBuffer(emit: records.add, maxBytes: 12);
    buffer.add('가나다', LogLevel.debug);
    buffer.add('라마바', LogLevel.debug);
    buffer.flush();
    expect(records.first.message, contains('omittedEvents=1'));
    expect(records.last.message, contains('라마바'));
  });

  test('detailed logging expires and resumes buffering automatically', () {
    var now = DateTime(2026, 10, 9);
    final records = <DiagnosticLogRecord>[];
    final buffer = DiagnosticLogBuffer(emit: records.add, now: () => now);
    buffer.enableDetailed(duration: const Duration(minutes: 1));
    buffer.add('first', LogLevel.debug);
    now = now.add(const Duration(minutes: 1));
    buffer.add('second', LogLevel.debug);
    expect(buffer.detailed, isFalse);
    expect(records.map((e) => e.message), ['first']);
    buffer.add('failure', LogLevel.error);
    expect(records[1].message, contains('second'));
  });

  test('truncation preserves UTF-8 and marks omitted data', () {
    final text = boundedLogText('가나다😀' * 2000, maxBytes: 256);
    expect(utf8.encode(text).length, lessThanOrEqualTo(256));
    expect(text, contains('truncated originalBytes='));
    expect(text, isNot(contains('\uFFFD')));
  });

  test(
    'quoted credentials, cookie stores, HTML inputs and URLs are masked',
    () {
      final masked = app_log.maskLogMessage('''
{"password": "secret with spaces", "studentId": "private-student"}
{authCode: private-code, latitude: 37.123, longitude: 126.123}
X-Target-Cookie-Store: private-inventory
Authorization: Bearer private-token
SetCookie('SESSION', 'private-cookie')
<input name="USER_ID" value="private-input">
https://user:private-userinfo@example.test/path?unknown=private-query
''');
      for (final secret in [
        'secret with spaces',
        'private-student',
        'private-code',
        '37.123',
        '126.123',
        'private-inventory',
        'private-token',
        'private-cookie',
        'private-input',
        'private-userinfo',
        'private-query',
      ]) {
        expect(masked, isNot(contains(secret)));
      }
      expect(masked, contains('https://example.test/path'));
    },
  );

  test(
    'masked details, error and stack remain available after suppression',
    () async {
      final printer = _CapturePrinter();
      final previous = app_log.logger;
      final logger = Logger(
        filter: ProductionFilter(),
        level: Level.all,
        printer: printer,
      );
      app_log.logger = logger;
      addTearDown(() async {
        app_log.disableDetailedLogging();
        app_log.logger = previous;
        await logger.close();
      });
      app_log.logMsg('PASSWD=private-password stage=login');
      expect(printer.events, isEmpty);
      app_log.logMsg(
        'parse failed',
        level: LogLevel.error,
        error: const FormatException('invalid markup'),
        stackTrace: StackTrace.fromString(
          '#0 parseLecture (attendance_service.dart:123)',
        ),
        context: {'requestId': 'test-1'},
      );
      final text = printer.events.map((e) => e.message).join('\n');
      expect(text, isNot(contains('private-password')));
      expect(text, contains('stage=login'));
      expect(text, contains('FormatException'));
      expect(text, contains('attendance_service.dart:123'));
      expect(text, contains('requestId=test-1'));
    },
  );
}

class _CapturePrinter extends LogPrinter {
  final events = <LogEvent>[];
  @override
  List<String> log(LogEvent event) {
    events.add(event);
    return [];
  }
}
