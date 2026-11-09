enum HapticSignal { complete, error, attendanceSuccess, attendanceFailure }

abstract interface class HapticBackend {
  Future<void> play(HapticSignal signal);
  void cancel();
}
