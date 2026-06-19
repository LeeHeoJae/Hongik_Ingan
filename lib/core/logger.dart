import 'package:logger/logger.dart';

import 'deployment_environment.dart';
import 'logger_io.dart'
    if (dart.library.html) 'logger_web.dart'
    as platform_logger;

late Logger logger;

enum LogLevel { debug, info, warning, error }

Future<void> initLogger() async {
  logger = await platform_logger.createLogger();
}

Future<void> shareLogFile() async {
  await platform_logger.shareLogFile(
    onWarning: (message) => logMsg(message, level: LogLevel.warning),
    onError: (message) => logMsg(message, level: LogLevel.error),
  );
}

void logMsg(String msg, {LogLevel level = LogLevel.debug}) {
  final maskedMsg = maskLogMessage(msg);
  platform_logger.writePlatformLog(
    maskedMsg,
    level.name,
    DeploymentEnvironment.appEnv,
  );

  switch (level) {
    case LogLevel.debug:
      logger.d(maskedMsg);
      break;
    case LogLevel.info:
      logger.i(maskedMsg);
      break;
    case LogLevel.warning:
      logger.w(maskedMsg);
      break;
    case LogLevel.error:
      logger.e(maskedMsg);
      break;
  }
}

// 마스킹 {USER_ID: ***, PASSWD: ***}
String maskLogMessage(String msg) {
  var masked = msg.replaceAllMapped(
    RegExp(
      r'(PASSWD|password|pwd|pass|USER_PWD|USER_ID|studentId|authCode|key|latitude|longitude)\s*[:=]\s*([^,}\]\s\n&]+)',
      caseSensitive: false,
    ),
    (match) => '${match.group(1)}: ***',
  );
  masked = masked.replaceAllMapped(
    RegExp(
      r'(cookie|set-cookie|x-target-cookie)\s*[:=]\s*([^,\n]+)',
      caseSensitive: false,
    ),
    (match) => '${match.group(1)}: ***',
  );
  return masked;
}
