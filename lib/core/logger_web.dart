import 'dart:developer' as developer;

import 'package:logger/logger.dart';

Future<Logger> createLogger() async {
  return Logger(printer: SimplePrinter(printTime: true));
}

Future<void> shareLogFile({
  required void Function(String message) onWarning,
  required void Function(String message) onError,
}) async {
  onWarning('웹에서는 로그 파일 공유를 지원하지 않습니다.');
}

void writePlatformLog(String maskedMsg, String levelName) {
  final consoleMessage = '[HongikIngan][$levelName] $maskedMsg';
  developer.log(consoleMessage, name: 'HongikIngan')
  print(consoleMessage);
}
