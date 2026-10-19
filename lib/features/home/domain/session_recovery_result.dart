enum SessionRecoveryResult {
  restored,
  temporarilyUnavailable,
  loginRequired,
  cancelled;

  bool get isRestored => this == restored;
}
