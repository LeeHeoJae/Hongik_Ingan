import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hongik_ingan/features/update/domain/update_check_result.dart';

class UpdateCheckCoordinator {
  UpdateCheckCoordinator({
    required this.checkUpdate,
    required this.currentResult,
    required this.isBusy,
    required this.isActive,
    required this.applyResult,
  });

  final Future<UpdateCheckResult> Function() checkUpdate;
  final UpdateCheckResult Function() currentResult;
  final bool Function() isBusy;
  final bool Function() isActive;
  final void Function(UpdateCheckResult) applyResult;
  Timer? _timer;
  bool _started = false;

  void schedule({Duration delay = const Duration(seconds: 8)}) {
    if (kIsWeb || _started) return;
    _timer?.cancel();
    _timer = Timer(delay, () => unawaited(fetch()));
  }

  Future<void> fetch({bool userInitiated = false}) async {
    if (kIsWeb || currentResult().status == UpdateCheckStatus.checking) return;
    if (isBusy() && !userInitiated) {
      schedule(delay: const Duration(seconds: 4));
      return;
    }

    _started = true;
    _timer?.cancel();
    applyResult(const UpdateCheckResult.checking());
    try {
      final result = await checkUpdate();
      if (isActive()) applyResult(result);
    } catch (_) {
      if (isActive()) applyResult(const UpdateCheckResult.failed());
    }
  }

  void cancelScheduled() => _timer?.cancel();

  void dispose() => cancelScheduled();
}
