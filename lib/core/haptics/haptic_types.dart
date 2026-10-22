enum HapticSignal { complete, error }

abstract interface class HapticBackend {
  Future<void> play(HapticSignal signal);
  void cancel();
}
