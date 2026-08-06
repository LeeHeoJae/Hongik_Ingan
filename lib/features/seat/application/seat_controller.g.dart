// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'seat_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SeatController)
final seatControllerProvider = SeatControllerProvider._();

final class SeatControllerProvider
    extends $NotifierProvider<SeatController, SeatState> {
  SeatControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'seatControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$seatControllerHash();

  @$internal
  @override
  SeatController create() => SeatController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SeatState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SeatState>(value),
    );
  }
}

String _$seatControllerHash() => r'6333e665220d51fd69d3be4e3b04ed5062656839';

abstract class _$SeatController extends $Notifier<SeatState> {
  SeatState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<SeatState, SeatState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SeatState, SeatState>,
              SeatState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
