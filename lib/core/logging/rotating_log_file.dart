import 'dart:convert';
import 'dart:io';

/// Calls are serialized so a share snapshot includes all preceding writes.
class RotatingLogFile {
  RotatingLogFile(
    this.file, {
    this.maxBytes = 2 * 1024 * 1024,
    this.maxFiles = 5,
  }) : assert(maxBytes > 64),
       assert(maxFiles > 0);

  final File file;
  final int maxBytes;
  final int maxFiles;
  Future<void> _pending = Future.value();
  bool _initialized = false;

  Future<T> _enqueue<T>(Future<T> Function() action) {
    final operation = _pending.then((_) => action());
    _pending = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  Future<void> append(String text) => _enqueue(() async {
    await _initialize();
    final bytes = _tail(utf8.encode(text));
    final size = await file.length();
    if (size > 0 && size + bytes.length > maxBytes) await _rotate();
    await file.writeAsBytes(bytes, mode: FileMode.append, flush: true);
  });

  Future<void> flush() => _pending;

  Future<File?> snapshot(File destination) => _enqueue(() async {
    if (!await file.exists()) return null;
    await _initialize();
    final output = destination.openWrite();
    try {
      for (var index = maxFiles - 1; index >= 0; index--) {
        final source = _fileAt(index);
        if (!await source.exists()) continue;
        output.writeln('--- ${source.uri.pathSegments.last} ---');
        await output.addStream(source.openRead());
        output.writeln();
      }
      await output.flush();
    } finally {
      await output.close();
    }
    return destination;
  });

  File _fileAt(int index) => index == 0 ? file : File('${file.path}.$index');

  Future<void> _initialize() async {
    if (_initialized) return;
    await file.parent.create(recursive: true);
    if (!await file.exists()) await file.create();
    // Bound a legacy unrotated file without loading it all into memory.
    for (var index = 0; index < maxFiles; index++) {
      final source = _fileAt(index);
      if (!await source.exists()) continue;
      final length = await source.length();
      if (length <= maxBytes) continue;
      final tail = <int>[];
      await for (final chunk in source.openRead(length - maxBytes)) {
        tail.addAll(chunk);
      }
      final marker = utf8.encode('[older log bytes omitted during rotation]\n');
      final remaining = tail.sublist(marker.length);
      while (remaining.isNotEmpty && (remaining.first & 0xc0) == 0x80) {
        remaining.removeAt(0);
      }
      await source.writeAsBytes([...marker, ...remaining], flush: true);
    }
    _initialized = true;
  }

  List<int> _tail(List<int> bytes) {
    if (bytes.length <= maxBytes) return bytes;
    final marker = utf8.encode('[oversized log entry truncated]\n');
    var start = bytes.length - maxBytes + marker.length;
    while (start < bytes.length && (bytes[start] & 0xc0) == 0x80) {
      start++;
    }
    return [...marker, ...bytes.sublist(start)];
  }

  Future<void> _rotate() async {
    final oldest = _fileAt(maxFiles - 1);
    if (await oldest.exists()) await oldest.delete();
    for (var index = maxFiles - 2; index >= 0; index--) {
      final source = _fileAt(index);
      if (await source.exists()) await source.rename(_fileAt(index + 1).path);
    }
    await file.create();
  }
}
