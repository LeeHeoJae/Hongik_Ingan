import 'dart:async';
import 'dart:io';

import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<Logger> createLogger() {
  return Future.value(
    Logger(
      printer: SimplePrinter(printTime: true),
      output: MultiOutput([ConsoleOutput(), _LazyFileOutput()]),
    ),
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

void writePlatformLog(String maskedMsg, String levelName, String appEnv) {}

class _LazyFileOutput extends LogOutput {
  File? _file;
  Future<File>? _fileFuture;

  @override
  void output(OutputEvent event) {
    final text = '${event.lines.join('\n')}\n';
    unawaited(_write(text));
  }

  Future<void> _write(String text) async {
    try {
      final file = await _ensureFile();
      await file.writeAsString(text, mode: FileMode.append);
    } catch (_) {}
  }

  Future<File> _ensureFile() {
    final existingFile = _file;
    if (existingFile != null) {
      return Future.value(existingFile);
    }

    return _fileFuture ??= _createFile();
  }

  Future<File> _createFile() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/logs.txt');
    if (!await file.exists()) {
      await file.create(recursive: true);
    }
    _file = file;
    return file;
  }
}
