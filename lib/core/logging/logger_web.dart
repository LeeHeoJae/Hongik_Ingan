import 'package:logger/logger.dart';

import '../deployment_environment.dart';

Future<Logger> createLogger() async {
  return Logger(
    filter: ProductionFilter(),
    level: Level.all,
    printer: SimplePrinter(printTime: true, colors: false),
    output: _WebConsoleOutput(),
  );
}

Future<void> shareLogFile({
  required void Function(String message) onWarning,
  required void Function(String message) onError,
}) async {
  onWarning('웹에서는 로그 파일 공유를 지원하지 않습니다.');
}

void writePlatformLog(String maskedMsg, String levelName, String appEnv) {
  final consoleMessage = '[HongikIngan][$appEnv][$levelName] $maskedMsg';
  // ignore: avoid_print
  print(consoleMessage);
}

class _WebConsoleOutput extends LogOutput {
  @override
  void output(OutputEvent event) {
    writePlatformLog(
      event.lines.join('\n'),
      event.level.name,
      DeploymentEnvironment.appEnv,
    );
  }
}
