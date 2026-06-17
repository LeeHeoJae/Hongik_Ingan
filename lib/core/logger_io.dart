import 'dart:io';

import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<Logger> createLogger() async {
  final directory = await getApplicationDocumentsDirectory();
  final file = File('${directory.path}/logs.txt');
  if (!await file.exists()) {
    await file.create(recursive: true);
  }
  return Logger(
    printer: SimplePrinter(printTime: true),
    output: MultiOutput([ConsoleOutput(), FileOutput(file: file)]),
  );
}

Future<void> shareLogFile({
  required void Function(String message) onWarning,
  required void Function(String message) onError,
}) async {
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
      onWarning('로그 파일이 존재하지 않습니다.');
    }
  } catch (e) {
    onError('공유 중 오류 발생: $e');
  }
}

void writePlatformLog(String maskedMsg, String levelName) {}
