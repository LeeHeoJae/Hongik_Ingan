import 'package:logger/logger.dart';

import '../deployment_environment.dart';
import 'log_diagnostics.dart';
import 'logger_io.dart'
    if (dart.library.js_interop) 'logger_web.dart'
    as platform_logger;

export 'log_diagnostics.dart' show LogLevel;

Logger? logger;

final _diagnostics = DiagnosticLogBuffer(emit: _emitLog);

Future<void> initLogger() async {
  logger = await platform_logger.createLogger();
}

Future<void> shareLogFile() async {
  _diagnostics.flush();
  await platform_logger.shareLogFile(
    onWarning: (message) => logMsg(message, level: LogLevel.warning),
    onError: (message) => logMsg(message, level: LogLevel.error),
  );
}

void enableDetailedLogging({Duration duration = const Duration(minutes: 10)}) {
  _diagnostics.enableDetailed(duration: duration);
  logMsg(
    'diagnostics detailedUntil=${DateTime.now().add(duration).toIso8601String()}',
    level: LogLevel.info,
  );
}

void disableDetailedLogging() {
  _diagnostics.disableDetailed();
  logMsg('diagnostics mode=summary', level: LogLevel.info);
}

void logMsg(
  String msg, {
  LogLevel level = LogLevel.debug,
  Object? error,
  StackTrace? stackTrace,
  Map<String, Object?> context = const {},
}) {
  final details = StringBuffer(boundedLogText(maskLogMessage(msg)));
  for (final field in context.entries) {
    details.write(' ${field.key}=${field.value}');
  }
  if (error != null) {
    details.write(
      ' errorType=${error.runtimeType} error=${boundedLogText(maskLogMessage(error.toString()))}',
    );
  }
  if (stackTrace != null) {
    details.write(
      '\n${boundedLogText(maskLogMessage(stackTrace.toString()), maxBytes: 8192)}',
    );
  }
  _diagnostics.add(maskLogMessage(details.toString()), level);
}

void _emitLog(DiagnosticLogRecord record) {
  final maskedMsg = record.message;
  final level = record.level;

  final activeLogger = logger;
  if (activeLogger == null) {
    platform_logger.writePlatformLog(
      maskedMsg,
      level.name,
      DeploymentEnvironment.appEnv,
    );
    return;
  }

  switch (level) {
    case LogLevel.debug:
      activeLogger.d(maskedMsg);
      break;
    case LogLevel.info:
      activeLogger.i(maskedMsg);
      break;
    case LogLevel.warning:
      activeLogger.w(maskedMsg);
      break;
    case LogLevel.error:
      activeLogger.e(maskedMsg);
      break;
  }
}

// 마스킹 {USER_ID: ***, PASSWD: ***}
String maskLogMessage(String msg) {
  var masked = msg.replaceAllMapped(
    RegExp(
      r'''\b(PASSWD|password|pwd|pass|USER_PWD|USER_ID|studentId|authCode|key|latitude|longitude|lat|lon|token|access_token|refresh_token|JSESSIONID)["']?\s*[:=]\s*(?:"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|[^,}\]\s\n&<>]+)''',
      caseSensitive: false,
    ),
    (match) => '${match.group(1)}: ***',
  );
  masked = masked.replaceAllMapped(
    RegExp(
      r'''(SetCookie\s*\(\s*['"][^'"]+['"]\s*,\s*)['"][^'"]*['"]''',
      caseSensitive: false,
    ),
    (match) => "${match.group(1)}'***'",
  );
  masked = masked.replaceAllMapped(
    RegExp(
      r'''\b(x-target-cookie-store|x-target-set-cookies|x-target-cookie|set-cookie|cookie|authorization)["']?\s*[:=]\s*([^\n]+)''',
      caseSensitive: false,
    ),
    (match) => '${match.group(1)}: ***',
  );
  masked = masked.replaceAllMapped(
    RegExp(r'<input\b[^>]*>', caseSensitive: false),
    (match) => match[0]!.replaceAll(
      RegExp(
        r'''\bvalue\s*=\s*(?:"[^"]*"|'[^']*'|[^\s>]+)''',
        caseSensitive: false,
      ),
      'value="***"',
    ),
  );
  masked = masked.replaceAllMapped(
    RegExp(r'https?://[^\s<>"\x27]+', caseSensitive: false),
    // URLs in exception strings can contain encoded credentials or proxy URLs.
    // Strip the complete query rather than trying to decode individual values.
    (match) {
      final uri = Uri.tryParse(match[0]!);
      if (uri == null) return '[url]';
      return '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}${uri.path}';
    },
  );
  return masked;
}
