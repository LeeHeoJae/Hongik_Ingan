import 'dart:async';
import 'dart:io';

import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'rotating_log_file.dart';

const _logFileName = 'logs.txt';
const _shareSnapshotDirectoryName = 'log_share_snapshots';
const _shareSnapshotPrefix = 'hongik_ingan_logs_';

_LazyFileOutput? _fileOutput;
Future<void>? _snapshotCleanup;

Future<Logger> createLogger() {
  final snapshotCleanup = _snapshotCleanup ??= _clearOldShareSnapshots();
  unawaited(snapshotCleanup);

  final fileOutput = _LazyFileOutput();
  _fileOutput = fileOutput;
  return Future.value(
    Logger(
      filter: _DiagnosticLogFilter(),
      printer: SimplePrinter(printTime: true, colors: false),
      output: MultiOutput([ConsoleOutput(), fileOutput]),
    ),
  );
}

class _DiagnosticLogFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) => true;
}

Future<void> shareLogFile({
  required void Function(String message) onWarning,
  required void Function(String message) onError,
}) async {
  try {
    await (_snapshotCleanup ??= _clearOldShareSnapshots());

    final temporaryDirectory = await getTemporaryDirectory();
    final snapshotDirectory = Directory(
      '${temporaryDirectory.path}/$_shareSnapshotDirectoryName',
    );
    if (!await snapshotDirectory.exists()) {
      await snapshotDirectory.create(recursive: true);
    }

    final snapshot = File(
      '${snapshotDirectory.path}/'
      '$_shareSnapshotPrefix${DateTime.now().microsecondsSinceEpoch}.txt',
    );
    final sharedFile = await _copyLogSnapshot(snapshot);
    if (sharedFile == null) {
      onWarning('로그 파일이 존재하지 않습니다.');
      return;
    }

    await SharePlus.instance.share(
      ShareParams(files: [XFile(sharedFile.path, mimeType: 'text/plain')]),
    );
  } catch (e) {
    onError('공유 중 오류 발생: $e');
  }
}

void writePlatformLog(String maskedMsg, String levelName, String appEnv) {}

Future<File?> _copyLogSnapshot(File destination) async {
  final fileOutput = _fileOutput;
  if (fileOutput != null) {
    return fileOutput.copyExistingLogTo(destination);
  }

  final directory = await getApplicationDocumentsDirectory();
  final source = File('${directory.path}/$_logFileName');
  if (!await source.exists()) {
    return null;
  }
  return RotatingLogFile(source).snapshot(destination);
}

Future<void> _clearOldShareSnapshots() async {
  try {
    final temporaryDirectory = await getTemporaryDirectory();
    final directory = Directory(
      '${temporaryDirectory.path}/$_shareSnapshotDirectoryName',
    );
    if (!await directory.exists()) {
      await directory.create(recursive: true);
      return;
    }

    await for (final entity in directory.list(followLinks: false)) {
      if (entity is File) {
        try {
          await entity.delete();
        } catch (_) {}
      }
    }
  } catch (_) {}
}

class _LazyFileOutput extends LogOutput {
  Future<RotatingLogFile>? _fileFuture;
  Future<void> _pendingOperation = Future.value();

  @override
  void output(OutputEvent event) {
    final text = '${event.lines.join('\n')}\n';
    _pendingOperation = _pendingOperation.then((_) => _write(text));
    unawaited(_pendingOperation);
  }

  Future<void> _write(String text) async {
    try {
      final file = await _ensureFile();
      await file.append(text);
    } catch (_) {}
  }

  Future<RotatingLogFile> _ensureFile() {
    return _fileFuture ??= _createFile();
  }

  Future<RotatingLogFile> _createFile() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$_logFileName');
    return RotatingLogFile(file);
  }

  Future<File?> copyExistingLogTo(File destination) {
    final snapshotOperation = _pendingOperation.then((_) async {
      final directory = await getApplicationDocumentsDirectory();
      final source = File('${directory.path}/$_logFileName');
      if (!await source.exists()) {
        return null;
      }
      final file = await _ensureFile();
      return file.snapshot(destination);
    });
    _pendingOperation = snapshotOperation.then<void>(
      (_) {},
      onError: (_, _) {},
    );
    return snapshotOperation;
  }

  @override
  Future<void> destroy() async => _pendingOperation;
}
