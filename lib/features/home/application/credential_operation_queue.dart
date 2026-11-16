import 'package:hongik_ingan/core/logging/logger.dart';

/// 자격증명 저장소 작업을 한 번에 하나씩 순서대로 실행한다.
class CredentialOperationQueue {
  Future<void> _tail = Future.value();

  /// 작업이 성공하면 true, 예외가 나면 false를 돌려준다.
  Future<bool> run(Future<void> Function() operation) {
    final result = _tail.then((_) async {
      try {
        await operation();
        return true;
      } catch (error, stack) {
        // Storage exceptions may contain sensitive values; log only their type.
        logMsg(
          'Credential persistence failed',
          level: LogLevel.error,
          error: error.runtimeType,
          stackTrace: stack,
        );
        return false;
      }
    });
    _tail = result.then<void>((_) {});
    return result;
  }
}
