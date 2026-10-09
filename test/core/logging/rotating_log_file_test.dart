import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/core/logging/rotating_log_file.dart';

void main() {
  late Directory directory;
  setUp(
    () async =>
        directory = await Directory.systemTemp.createTemp('log_rotation_'),
  );
  tearDown(() async => directory.delete(recursive: true));

  test(
    'rotation bounds file count and snapshot preserves chronological order',
    () async {
      final file = File('${directory.path}/logs.txt');
      final log = RotatingLogFile(file, maxBytes: 128, maxFiles: 3);
      for (var index = 0; index < 6; index++) {
        await log.append('event=$index ${'x' * 90}\n');
      }
      final files = await directory.list().where((f) => f is File).toList();
      expect(files, hasLength(3));
      for (final entry in files.cast<File>()) {
        expect(await entry.length(), lessThanOrEqualTo(128));
      }
      final snapshot = await log.snapshot(File('${directory.path}/shared.txt'));
      final text = await snapshot!.readAsString();
      expect(text, isNot(contains('event=2')));
      expect(text.indexOf('event=3'), lessThan(text.indexOf('event=4')));
      expect(text.indexOf('event=4'), lessThan(text.indexOf('event=5')));
    },
  );

  test(
    'queued snapshots wait for writes and do not include later writes',
    () async {
      final log = RotatingLogFile(File('${directory.path}/logs.txt'));
      final first = log.append('before\n');
      final sharing = log.snapshot(File('${directory.path}/shared.txt'));
      final last = log.append('after\n');
      await first;
      final snapshot = await sharing;
      await last;
      expect(await snapshot!.readAsString(), contains('before'));
      expect(await snapshot.readAsString(), isNot(contains('after')));
    },
  );

  test(
    'legacy oversized file is bounded without breaking Korean text',
    () async {
      final file = File('${directory.path}/logs.txt');
      await file.writeAsString('가나다😀' * 500);
      final log = RotatingLogFile(file, maxBytes: 128);
      final snapshot = await log.snapshot(File('${directory.path}/shared.txt'));
      expect(await file.length(), lessThanOrEqualTo(128));
      expect(await file.readAsString(), isNot(contains('\uFFFD')));
      expect(
        await snapshot!.readAsString(),
        contains('older log bytes omitted'),
      );
    },
  );

  test('oversized entries are limited and UTF-8 remains valid', () async {
    final file = File('${directory.path}/logs.txt');
    final log = RotatingLogFile(file, maxBytes: 128, maxFiles: 1);
    await log.append('previous\n');
    await log.append('😀가' * 100);
    expect(await file.length(), lessThanOrEqualTo(128));
    final text = utf8.decode(await file.readAsBytes());
    expect(text, contains('oversized log entry truncated'));
    expect(text, isNot(contains('previous')));
    expect(await directory.list().length, 1);
  });

  test('sharing before the first write does not create an empty log', () async {
    final file = File('${directory.path}/logs.txt');
    final log = RotatingLogFile(file);
    expect(await log.snapshot(File('${directory.path}/shared.txt')), isNull);
    expect(await file.exists(), isFalse);
  });
}
