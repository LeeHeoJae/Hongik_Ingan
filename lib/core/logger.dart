import 'dart:io';

import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

late Logger logger;

Future<void> initLogger() async {
  final directory = await getApplicationDocumentsDirectory();
  final file = File('${directory.path}/logs.txt');
  logger = Logger(
    printer: SimplePrinter(printTime: true),
    output: MultiOutput([ConsoleOutput(), FileOutput(file: file)]),
  );
}

Future<void> shareLogFile() async {
  try {
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/logs.txt';
    final file = File(filePath);
    if (await file.exists()) {
      await SharePlus.instance.share(
        ShareParams(
          text: '홍익인간 앱 리포트 로그 파일입니다.',
          subject: '로그 파일 전송',
          files: [XFile(filePath)],
        ),
      );
    } else {
      logMsg('로그 파일이 존재하지 않습니다.');
    }
  } catch (e) {
    logMsg('공유 중 오류 발생: $e');
  }
}

void logMsg(String msg) {
  logger.d(msg);
}
