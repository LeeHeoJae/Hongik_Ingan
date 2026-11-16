/// 세션 복구 중 자동 재로그인의 시도 횟수와 재시도 시각을 관리한다.
class AutomaticReloginPolicy {
  AutomaticReloginPolicy(this._now);

  static const retryInterval = Duration(seconds: 60);
  static const _maxAttempts = 2;

  final DateTime Function() _now;
  int _attempts = 0;
  DateTime? _retryAt;

  DateTime? get retryAt => _retryAt;

  /// 이미 시도했고 아직 재시도할 수 없는 상태면 true.
  bool get blocksAttempt =>
      _attempts > 0 &&
      (_attempts >= _maxAttempts ||
          _retryAt == null ||
          _now().isBefore(_retryAt!));

  void reset() {
    _attempts = 0;
    _retryAt = null;
  }

  void recordAttempt() {
    _attempts++;
    _retryAt = null;
  }

  /// 일시적 실패 후 한 번 더 시도할 수 있으면 재시도 시각을 정한다.
  void scheduleRetryIfAllowed() {
    if (_attempts < _maxAttempts) _retryAt = _now().add(retryInterval);
  }
}
