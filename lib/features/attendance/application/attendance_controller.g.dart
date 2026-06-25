// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attendance_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AttendanceController)
final attendanceProvider = AttendanceControllerProvider._();

final class AttendanceControllerProvider
    extends $NotifierProvider<AttendanceController, AttendanceState> {
  AttendanceControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'attendanceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$attendanceControllerHash();

  @$internal
  @override
  AttendanceController create() => AttendanceController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AttendanceState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AttendanceState>(value),
    );
  }
}

String _$attendanceControllerHash() =>
    r'15ddc714978d88cd540469d65070f8558fa6d18a';

abstract class _$AttendanceController extends $Notifier<AttendanceState> {
  AttendanceState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AttendanceState, AttendanceState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AttendanceState, AttendanceState>,
              AttendanceState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
