import 'dart:collection';
import 'dart:convert';

enum LogLevel { debug, info, warning, error }

/// Limits apply after masking, before either buffering or writing.
String boundedLogText(String text, {int maxBytes = 4096}) {
  final bytes = utf8.encode(text);
  if (bytes.length <= maxBytes) return text;
  final suffix = '\n[truncated originalBytes=${bytes.length}]';
  var end = maxBytes - utf8.encode(suffix).length;
  if (end <= 0) return '[truncated]';
  while (end > 0 && (bytes[end] & 0xc0) == 0x80) {
    end--;
  }
  return '${utf8.decode(bytes.sublist(0, end))}$suffix';
}

class DiagnosticLogRecord {
  const DiagnosticLogRecord(this.message, this.level, this.time);

  final String message;
  final LogLevel level;
  final DateTime time;
}

/// Retains only details that have not already been emitted.
class DiagnosticLogBuffer {
  DiagnosticLogBuffer({
    required this.emit,
    this.maxEvents = 40,
    this.maxBytes = 64 * 1024,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final void Function(DiagnosticLogRecord) emit;
  final int maxEvents;
  final int maxBytes;
  final DateTime Function() _now;
  final _pending = Queue<DiagnosticLogRecord>();
  int _bytes = 0;
  int _dropped = 0;
  DateTime? _detailedUntil;

  bool get detailed =>
      _detailedUntil != null && _now().isBefore(_detailedUntil!);

  void enableDetailed({Duration duration = const Duration(minutes: 10)}) {
    _detailedUntil = _now().add(duration);
    flush();
  }

  void disableDetailed() => _detailedUntil = null;

  void add(String maskedMessage, LogLevel level) {
    final record = DiagnosticLogRecord(
      boundedLogText(maskedMessage, maxBytes: 16 * 1024),
      level,
      _now(),
    );
    if (level == LogLevel.debug && !detailed) {
      _pending.addLast(record);
      _bytes += utf8.encode(record.message).length;
      while (_pending.length > maxEvents || _bytes > maxBytes) {
        _bytes -= utf8.encode(_pending.removeFirst().message).length;
        _dropped++;
      }
      return;
    }
    if (level == LogLevel.warning || level == LogLevel.error) flush();
    emit(record);
  }

  void flush() {
    if (_dropped > 0) {
      emit(
        DiagnosticLogRecord(
          'diagnostics omittedEvents=$_dropped',
          LogLevel.debug,
          _now(),
        ),
      );
    }
    for (final record in _pending) {
      emit(
        DiagnosticLogRecord(
          '[context at=${record.time.toIso8601String()}] ${record.message}',
          record.level,
          record.time,
        ),
      );
    }
    _pending.clear();
    _bytes = 0;
    _dropped = 0;
  }
}
