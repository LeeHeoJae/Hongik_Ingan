import 'update_info.dart';

enum UpdateCheckStatus { idle, checking, upToDate, available, failed }

final class UpdateCheckResult {
  const UpdateCheckResult.idle() : status = UpdateCheckStatus.idle, info = null;
  const UpdateCheckResult.checking()
    : status = UpdateCheckStatus.checking,
      info = null;
  const UpdateCheckResult.upToDate()
    : status = UpdateCheckStatus.upToDate,
      info = null;
  const UpdateCheckResult.available(UpdateInfo this.info)
    : status = UpdateCheckStatus.available;
  const UpdateCheckResult.failed()
    : status = UpdateCheckStatus.failed,
      info = null;

  final UpdateCheckStatus status;
  final UpdateInfo? info;
}
