// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cafeteria_menu_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(CafeteriaMenuController)
final cafeteriaMenuControllerProvider = CafeteriaMenuControllerProvider._();

final class CafeteriaMenuControllerProvider
    extends $NotifierProvider<CafeteriaMenuController, CafeteriaMenuState> {
  CafeteriaMenuControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cafeteriaMenuControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cafeteriaMenuControllerHash();

  @$internal
  @override
  CafeteriaMenuController create() => CafeteriaMenuController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CafeteriaMenuState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CafeteriaMenuState>(value),
    );
  }
}

String _$cafeteriaMenuControllerHash() =>
    r'95f57773f5738e5f194789984029e1f8e94b44f8';

abstract class _$CafeteriaMenuController extends $Notifier<CafeteriaMenuState> {
  CafeteriaMenuState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<CafeteriaMenuState, CafeteriaMenuState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CafeteriaMenuState, CafeteriaMenuState>,
              CafeteriaMenuState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
